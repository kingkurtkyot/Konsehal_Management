import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../services/settings_service.dart';
import '../widgets/help_legend_dialog.dart';
import '../models/solicitation.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/solicitation_card.dart';
import '../widgets/image_picker_bottom_sheet.dart';

class SolicitationScreen extends StatefulWidget {
  const SolicitationScreen({super.key});

  @override
  State<SolicitationScreen> createState() => _SolicitationScreenState();
}

class _SolicitationScreenState extends State<SolicitationScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<Solicitation> _solicitations = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  late TabController _tabController;

  // Multi-select
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSolicitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSolicitations() async {
    setState(() => _isLoading = true);
    final items = await StorageService.loadSolicitations();
    if (!mounted) return;
    setState(() {
      _solicitations = items;
      _isLoading = false;
    });
  }

  // --- SORTING ---

  List<Solicitation> get _pending {
    final list = _solicitations.where((s) => s.status == SolicitationStatus.pending).toList();
    // Sort by nearest target date first
    list.sort((a, b) {
      final dateA = a.parsedTargetDate;
      final dateB = b.parsedTargetDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });
    return list;
  }

  List<Solicitation> get _completed {
    final list = _solicitations.where((s) => s.status == SolicitationStatus.completed).toList();
    // Sort by most recently completed first
    list.sort((a, b) {
      final dateA = a.parsedTargetDate;
      final dateB = b.parsedTargetDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return list;
  }

  // --- SELECTION ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _startSelection(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} Item(s)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete the selected solicitations?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final id in _selectedIds) {
        await NotificationService.cancelSolicitationNotification(id);
      }
      await StorageService.deleteSolicitations(_selectedIds.toList());
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadSolicitations();
      if (mounted) _showSnackbar('Solicitations deleted.');
    }
  }

  // --- ACTIONS ---

  Future<void> _pickAndProcessImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Solicitations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton(
                      icon: Icons.add_photo_alternate,
                      label: 'Single Image',
                      onTap: () => Navigator.pop(context, 'single'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _choiceButton(
                      icon: Icons.collections,
                      label: 'Multiple Images',
                      onTap: () => Navigator.pop(context, 'multiple'),
                    ),
                  ),
                ],  
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _choiceButton(
                  icon: Icons.auto_awesome,
                  label: 'AI Text Entry',
                  onTap: () => Navigator.pop(context, 'ai_text'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _choiceButton(
                  icon: Icons.edit_note,
                  label: 'Manual Entry (Fill Fields)',
                  onTap: () => Navigator.pop(context, 'manual'),
                ),
              ),
            ],
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'manual') {
      _showManualEntryDialog();
      return;
    }

    if (choice == 'ai_text') {
      _showAITextEntryDialog();
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const ImagePickerBottomSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    List<XFile> pickedFiles = [];
    
    if (choice == 'multiple') {
      pickedFiles = await picker.pickMultiImage(imageQuality: 85);
    } else {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) pickedFiles = [picked];
    }

    if (pickedFiles.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      List<Solicitation> allNewItems = [];
      for (final pickedFile in pickedFiles) {
        final imageFile = File(pickedFile.path);
        final newItems = await GeminiService.extractSolicitationsFromImage(imageFile);
        allNewItems.addAll(newItems);
      }

      if (allNewItems.isEmpty) {
        if (mounted) _showSnackbar('No solicitations found in the image(s).', isError: true);
        return;
      }

      await StorageService.addSolicitations(allNewItems);

      for (final item in allNewItems) {
        if (item.status == SolicitationStatus.pending) {
          await NotificationService.scheduleSolicitationNotification(item);
        }
      }

      await _loadSolicitations();
      if (mounted) _showSnackbar('${allNewItems.length} solicitation(s) added!');

      final hasPending = allNewItems.any((s) => s.status == SolicitationStatus.pending);
      _tabController.animateTo(hasPending ? 0 : 1);
    } catch (e) {
      if (mounted) _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAITextEntryDialog() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text('AI Text Entry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste or type solicitation info below. AI will automatically extract and organize the details.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g., Juan Dela Cruz is requesting ₱2000 for basketball league uniforms, contact 09171234567, deadline April 15 2026...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 8,
                minLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (textCtrl.text.trim().isEmpty) {
                _showSnackbar('Please enter some text', isError: true);
                return;
              }
              Navigator.pop(ctx);
              await _processAIText(textCtrl.text);
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Process with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processAIText(String text) async {
    setState(() => _isProcessing = true);
    try {
      final newItems = await GeminiService.extractSolicitationsFromText(text);
      if (newItems.isEmpty) {
        if (mounted) _showSnackbar('Could not extract solicitations from the text.', isError: true);
        return;
      }

      await StorageService.addSolicitations(newItems);
      for (final item in newItems) {
        if (item.status == SolicitationStatus.pending) {
          await NotificationService.scheduleSolicitationNotification(item);
        }
      }
      await _loadSolicitations();
      if (mounted) _showSnackbar('${newItems.length} solicitation(s) added!');
    } catch (e) {
      if (mounted) _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showManualEntryDialog() {
    final orgCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final amountReqCtrl = TextEditingController();
    final targetDateCtrl = TextEditingController();
    final contactPersonCtrl = TextEditingController();
    final contactNumberCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Solicitation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(labelText: 'Organization/Person'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountReqCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount Requested (optional)',
                  hintText: 'e.g., ₱5,000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetDateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Target Date (optional)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) {
                    targetDateCtrl.text = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactPersonCtrl,
                decoration: const InputDecoration(labelText: 'Contact Person (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactNumberCtrl,
                decoration: const InputDecoration(labelText: 'Contact Number (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (orgCtrl.text.isEmpty || purposeCtrl.text.isEmpty) {
                _showSnackbar('Please fill organization and purpose', isError: true);
                return;
              }
              final item = Solicitation(
                id: 'sol_${DateTime.now().millisecondsSinceEpoch}',
                organizationOrPerson: orgCtrl.text,
                purpose: purposeCtrl.text,
                targetDate: targetDateCtrl.text,
                contactPerson: contactPersonCtrl.text,
                contactNumber: contactNumberCtrl.text,
                status: SolicitationStatus.pending,
                amountRequested: amountReqCtrl.text.isEmpty ? null : amountReqCtrl.text,
                amountGiven: null,
                additionalNotes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
              );
              Navigator.pop(ctx);
              await StorageService.addSolicitations([item]);
              if (item.status == SolicitationStatus.pending && item.targetDate.isNotEmpty) {
                await NotificationService.scheduleSolicitationNotification(item);
              }
              await _loadSolicitations();
              if (mounted) _showSnackbar('Solicitation added!');
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1B5E20), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _markAsCompleted(Solicitation item) async {
    String? amount;

    amount = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Mark as Completed', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.amountRequested != null) ...[
                Text('Requested: ${item.amountRequested}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20))),
                const SizedBox(height: 12),
              ],
              const Text('Enter amount given (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., ₱500',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (amount != null) {
      final updated = item.copyWith(
        status: SolicitationStatus.completed,
        amountGiven: amount.isEmpty ? null : amount,
        completedDate: '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().year}',
      );
      await StorageService.updateSolicitation(updated);
      await NotificationService.cancelSolicitationNotification(item.id);
      await _loadSolicitations();
      if (mounted) _showSnackbar('Marked as completed!');
    }
  }

  Future<void> _exportSolicitationAsImage(Solicitation solicitation) async {
    try {
      setState(() => _isProcessing = true);
      
      final bytes = await _renderSolicitationToImage(solicitation);
      if (bytes == null) {
        _showSnackbar('Error capturing image', isError: true);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'solicitation_${solicitation.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Solicitation: ${solicitation.organizationOrPerson}',
      );
      
      if (mounted) _showSnackbar('Solicitation exported as image!');
    } catch (e) {
      if (mounted) _showSnackbar('Error exporting: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<List<int>?> _renderSolicitationToImage(Solicitation sol) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    
    
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -2000,
        child: RepaintBoundary(
          key: key,
          child: Material(
            color: Colors.white,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.request_page, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Text('SOLICITATION', style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1,
                        )),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sol.status == SolicitationStatus.pending ? 'PENDING' : 'COMPLETED',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(sol.organizationOrPerson, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1C2833))),
                  const SizedBox(height: 8),
                  Text(sol.purpose, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  _exportInfoRow(Icons.calendar_today, 'Target Date', sol.targetDate.isNotEmpty ? sol.targetDate : 'Not specified'),
                  if (sol.contactPerson.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _exportInfoRow(Icons.person, 'Contact', sol.contactPerson),
                  ],
                  if (sol.contactNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _exportInfoRow(Icons.phone, 'Number', sol.contactNumber),
                  ],
                  if (sol.amountGiven != null) ...[
                    const SizedBox(height: 6),
                    _exportInfoRow(Icons.payments, 'Amount Given', sol.amountGiven!),
                  ],
                  if (sol.additionalNotes != null && sol.additionalNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _exportInfoRow(Icons.notes, 'Notes', sol.additionalNotes!),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: [
                        Text('Konsehal Matthew Lagaya', style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600,
                        )),
                        const Spacer(),
                        Text('#SerbisyongTapatparasaLahat', style: GoogleFonts.poppins(
                          fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Widget _exportInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2C3E50), fontWeight: FontWeight.w600))),
      ],
    );
  }

  void _showSolicitationHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HelpLegendDialog(
        title: 'Solicitation Tracker',
        items: [
          LegendItem(
            icon: Icons.add_photo_alternate,
            label: 'AI Scanner',
            description: 'Upload an image of a solicitation letter or list. AI will instantly extract the organization, purpose, and contact info.',
            color: const Color(0xFF1B5E20),
          ),
          LegendItem(
            icon: Icons.pending_actions,
            label: 'Pending Requests',
            description: 'Requests currently under review or awaiting funding. Keep track of what needs attention.',
            color: Colors.orange.shade700,
          ),
          LegendItem(
            icon: Icons.check_circle,
            label: 'Completed Service',
            description: 'Once fulfilled, items move here. You can log the specific amount given for transparency.',
            color: Colors.green.shade700,
          ),
          LegendItem(
            icon: Icons.download_rounded,
            label: 'Export Card',
            description: 'Generate a high-quality summary card of any solicitation to share with your team or the applicant.',
            color: Colors.blue.shade700,
          ),
          LegendItem(
            icon: Icons.touch_app_rounded,
            label: 'Batch Management',
            description: 'Long-press any entry to select multiple items for bulk deletion or status updates.',
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Solicitation Tracker'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  final allIds = _solicitations.map((s) => s.id).toSet();
                  if (_selectedIds.length == allIds.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(allIds);
                  }
                });
              },
              tooltip: 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteSelected,
              tooltip: 'Delete Selected',
            ),
          ] else ...[
            ValueListenableBuilder<bool>(
              valueListenable: AppSettingsService.showHelpLegends,
              builder: (context, showHelp, _) {
                if (!showHelp) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showSolicitationHelp(context),
                  tooltip: 'Show Help',
                );
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pending_actions),
                  const SizedBox(width: 6),
                  Text('Pending (${_pending.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 6),
                  Text('Completed (${_completed.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(),
              _buildCompletedList(),
            ],
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _pickAndProcessImage,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Add Entry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildPendingList() {
    final items = _pending;
    if (_isLoading) return _buildShimmer();

    if (items.isEmpty) {
      return _buildEmptyState(SolicitationStatus.pending);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SolicitationCard(
            solicitation: item,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedIds.contains(item.id),
            onToggleSelect: () => _toggleSelect(item.id),
            onLongPress: () => _startSelection(item.id),
            onMarkCompleted: () => _markAsCompleted(item),
            onExport: () => _exportSolicitationAsImage(item),
          ),
        );
      },
    );
  }

  Widget _buildCompletedList() {
    final items = _completed;
    if (_isLoading) return _buildShimmer();

    if (items.isEmpty) {
      return _buildEmptyState(SolicitationStatus.completed);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final isSelected = _selectedIds.contains(item.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: GestureDetector(
              onLongPress: () => _startSelection(item.id),
              child: ExpansionTile(
                leading: Icon(
                  Icons.check_circle,
                  color: isSelected ? const Color(0xFF1B5E20) : Colors.green.shade600,
                ),
                title: Text(
                  item.organizationOrPerson,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Given: ${item.amountGiven ?? "₱0"}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        _detailRow(Icons.notes, 'Purpose', item.purpose),
                        if (item.amountRequested != null)
                          _detailRow(Icons.payments, 'Requested', item.amountRequested!),
                        if (item.contactPerson.isNotEmpty)
                          _detailRow(Icons.person, 'Contact', item.contactPerson),
                        if (item.contactNumber.isNotEmpty)
                          _detailRow(Icons.phone, 'Number', item.contactNumber),
                        if (item.completedDate != null)
                          _detailRow(Icons.calendar_today, 'Completed', item.completedDate!),
                        if (item.additionalNotes != null)
                          _detailRow(Icons.description, 'Notes', item.additionalNotes!),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Export Card'),
                              onPressed: () => _exportSolicitationAsImage(item),
                            ),
                            if (_isSelectionMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelect(item.id),
                                activeColor: const Color(0xFF1B5E20),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(SolicitationStatus type) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == SolicitationStatus.pending ? Icons.pending_actions : Icons.check_circle,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            type == SolicitationStatus.pending ? 'No pending solicitations' : 'No completed solicitations',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add solicitations using the button below',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing...',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Extracting solicitations with AI',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
