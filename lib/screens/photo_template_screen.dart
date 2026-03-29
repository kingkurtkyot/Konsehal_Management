// lib/screens/photo_template_screen.dart
// Carbon copy of the provided Konsehal Matthew Lagaya template + Gallery

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';
import '../widgets/help_legend_dialog.dart';
import '../services/storage_service.dart';

class PhotoTemplateScreen extends StatefulWidget {
  const PhotoTemplateScreen({super.key});

  @override
  State<PhotoTemplateScreen> createState() => _PhotoTemplateScreenState();
}

class _PhotoTemplateScreenState extends State<PhotoTemplateScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedPhoto;
  bool _isSaving = false;
  bool _isSharing = false;
  final GlobalKey _previewKey = GlobalKey();
  late TabController _tabController;

  // Gallery
  List<String> _galleryPaths = [];
  bool _isLoadingGallery = false;

  // Template options
  bool _showHashtag = true;
  bool _showEmail = true;
  bool _showFacebook = true;
  double _photoOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGallery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    setState(() => _isLoadingGallery = true);
    final paths = await StorageService.loadGalleryPaths();
    // Filter out paths that no longer exist
    final validPaths = <String>[];
    for (final p in paths) {
      if (await File(p).exists()) {
        validPaths.add(p);
      }
    }
    if (!mounted) return;
    setState(() {
      _galleryPaths = validPaths;
      _isLoadingGallery = false;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 95);
    if (picked != null) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  void _showPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              Text('Select Photo',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF1B5E20),
                      onTap: () {
                        Navigator.pop(context);
                        _pickPhoto(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: const Color(0xFF6C3483),
                      onTap: () {
                        Navigator.pop(context);
                        _pickPhoto(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<List<int>?> _capturePreview() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _capturePreview();
      if (bytes == null) throw Exception('Could not capture image');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'lagaya_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Gal.putImage(file.path);

      // Also save to app gallery
      final appDir = await getApplicationDocumentsDirectory();
      final galleryDir = Directory('${appDir.path}/konsi_gallery');
      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }
      final galleryFile = File('${galleryDir.path}/$fileName');
      await galleryFile.writeAsBytes(bytes);
      await StorageService.addGalleryPath(galleryFile.path);
      await _loadGallery();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Saved to gallery & app history!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _capturePreview();
      if (bytes == null) throw Exception('Could not capture image');

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/lagaya_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#SerbisyongTapatparasaLahat',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _shareFromGallery(String path) async {
    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: '#SerbisyongTapatparasaLahat',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteFromGallery(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Image', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text('Remove this image from gallery?'),
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
      await StorageService.removeGalleryPath(path);
      try { await File(path).delete(); } catch (_) {}
      await _loadGallery();
    }
  }

  void _showPhotoHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HelpLegendDialog(
        title: 'Photo Template',
        items: [
          LegendItem(
            icon: Icons.add_photo_alternate,
            label: 'Template Overlay',
            description: 'Upload any photo and the app will automatically apply the Konsehal Matthew Lagaya official branding and contact details.',
            color: const Color(0xFF1B5E20),
          ),
          LegendItem(
            icon: Icons.tune,
            label: 'Customization',
            description: 'Toggle visibility of social media handles and adjust photo brightness for maximum readability.',
            color: Colors.blue.shade700,
          ),
          LegendItem(
            icon: Icons.save_alt,
            label: 'Dual Save',
            description: 'Images are saved both to your phone gallery and the internal app gallery for easy access.',
            color: Colors.green.shade700,
          ),
          LegendItem(
            icon: Icons.photo_library,
            label: 'Local Gallery',
            description: 'Browse and manage all previously created photo templates within the "Gallery" tab.',
            color: Colors.purple.shade700,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Photo Template'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: AppSettingsService.showHelpLegends,
            builder: (context, showHelp, _) {
              if (!showHelp) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showPhotoHelp(context),
                tooltip: 'Show Help',
              );
            },
          ),
          if (_selectedPhoto != null) ...[
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_alt, color: Colors.white),
              onPressed: _isSaving ? null : _saveToGallery,
              tooltip: 'Save to Gallery',
            ),
            IconButton(
              icon: _isSharing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.share, color: Colors.white),
              onPressed: _isSharing ? null : _shareImage,
              tooltip: 'Share',
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Create', icon: Icon(Icons.add_photo_alternate, size: 20)),
            Tab(text: 'Gallery', icon: Icon(Icons.photo_library, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildGalleryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPhoto == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1B5E20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload a photo and it will be combined with the Konsehal Lagaya template overlay automatically.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── PREVIEW AREA ──
          Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              child: AspectRatio(
                aspectRatio: 1.25,
                child: RepaintBoundary(
                  key: _previewKey,
                  child: _buildTemplatePreview(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── ACTION BUTTONS ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showPickerDialog,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_selectedPhoto == null ? 'Choose Photo' : 'Change Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_selectedPhoto != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _shareImage,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C3483),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_selectedPhoto != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveToGallery,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_isSaving ? 'Saving...' : 'Save to Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── CUSTOMIZATION OPTIONS ──
            Text('Template Options', style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1B5E20))),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  _optionSwitch('Show Hashtag', _showHashtag, (v) => setState(() => _showHashtag = v)),
                  const Divider(height: 1, indent: 16),
                  _optionSwitch('Show Email', _showEmail, (v) => setState(() => _showEmail = v)),
                  const Divider(height: 1, indent: 16),
                  _optionSwitch('Show Facebook', _showFacebook, (v) => setState(() => _showFacebook = v)),
                  const Divider(height: 1, indent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Photo Brightness', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Slider(
                          value: _photoOpacity,
                          min: 0.4,
                          max: 1.0,
                          divisions: 12,
                          label: '${(_photoOpacity * 100).round()}%',
                          activeColor: const Color(0xFF1B5E20),
                          onChanged: (v) => setState(() => _photoOpacity = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGalleryTab() {
    if (_isLoadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_galleryPaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No saved images yet', style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Create and save a template to see it here', style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _galleryPaths.length,
      itemBuilder: (context, index) {
        final path = _galleryPaths[index];
        return GestureDetector(
          onTap: () => _showGalleryImageActions(path),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path), fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _galleryAction(Icons.share, 'Share', () => _shareFromGallery(path)),
                          _galleryAction(Icons.delete_outline, 'Delete', () => _deleteFromGallery(path)),
                        ],
                      ),
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

  Widget _galleryAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  void _showGalleryImageActions(String path) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Full preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), height: 200, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareFromGallery(path);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteFromGallery(path);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TEMPLATE PREVIEW — Carbon copy of the provided image ──

  Widget _buildTemplatePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: User photo or white-to-grey gradient (matching template)
        if (_selectedPhoto != null)
          Opacity(
            opacity: _photoOpacity,
            child: Image.file(_selectedPhoto!, fit: BoxFit.cover),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Color(0xFFE8E8E8),
                  Color(0xFFD0D0D0),
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Tap "Choose Photo" to preview',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ),

        // Template overlay — exact carbon copy
        _buildTemplateOverlay(),
      ],
    );
  }

  Widget _buildTemplateOverlay() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Scale factors based on container width
          // Reference width ~1000px for full export; preview ~350px on phone
          final scale = w / 1000.0;
          final nameSmallFont = (14 * scale).clamp(6.0, 14.0);
          final nameLargeFont = (52 * scale).clamp(18.0, 52.0);
          final sealSize = (70 * scale).clamp(28.0, 70.0);
          final hashtagFont = (16 * scale).clamp(7.0, 16.0);
          final contactFont = (14 * scale).clamp(6.0, 14.0);
          final contactIconSize = (18 * scale).clamp(8.0, 18.0);
          final barPadH = (24 * scale).clamp(10.0, 24.0);
          final barPadBottom = (18 * scale).clamp(8.0, 18.0);
          final gradientHeight = (140 * scale).clamp(60.0, 140.0);

          return Column(
            children: [
              const Expanded(child: SizedBox()),

              // ── FOOTER BAR — Dark gradient, white text ──
              Container(
                height: gradientHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.50),
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.12, 0.35, 0.65, 1.0],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(barPadH, 0, barPadH, barPadBottom),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ── ROW 1: Name + Seal ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // KONSEHAL MATTHEW / LAGAYA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('KONSEHAL MATTHEW',
                                  style: GoogleFonts.poppins(
                                    fontSize: nameSmallFont,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1B5E20),
                                    letterSpacing: 2.0,
                                    height: 1.3,
                                  )),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text('LAGAYA',
                                    style: GoogleFonts.poppins(
                                      fontSize: nameLargeFont,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B5E20),
                                      height: 0.9,
                                      letterSpacing: 3,
                                    )),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 6 * scale),

                        // Seal
                        Container(
                          width: sealSize,
                          height: sealSize,
                          margin: EdgeInsets.only(bottom: 2 * scale),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1B5E20).withValues(alpha: 0.7),
                              width: (2 * scale).clamp(1.0, 2.0),
                            ),
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/seal.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text('🇵🇭', style: TextStyle(fontSize: sealSize * 0.55)),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 8 * scale),

                        // Contact info (right of seal)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_showEmail)
                                _contactItem(Icons.mail_outline, 'matthewlagaya@gmail.com',
                                    contactIconSize, contactFont),
                              SizedBox(height: 3 * scale),
                              if (_showFacebook)
                                _contactItem(Icons.facebook, 'Matthew Lagaya',
                                    contactIconSize, contactFont),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4 * scale),

                    // ── ROW 2: Hashtag (centered) ──
                    if (_showHashtag)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('#SerbisyongTapatparasaLahat',
                            style: GoogleFonts.poppins(
                              fontSize: hashtagFont,
                              color: const Color(0xFF1B5E20),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contactItem(IconData icon, String text, double iconSize, double fontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: const Color(0xFF1B5E20).withValues(alpha: 0.9)),
        SizedBox(width: iconSize * 0.35),
        Flexible(
          child: Text(text,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: const Color(0xFF1B5E20),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ),
      ],
    );
  }

  Widget _optionSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF1B5E20),
      activeTrackColor: const Color(0xFF1B5E20).withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
