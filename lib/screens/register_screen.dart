import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Ipasok ang email at password.', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackbar('Hindi magkatugma ang password.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackbar('Password must be at least 6 characters.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService().signUp(email, password);
      
      // Since the user wants "start immediately", we attempt to sign in right after signup
      // Note: If email confirmation is enabled in Supabase Dashboard, this might still fail 
      // until confirmed, but we proceed with the UI flow.
      await SupabaseService().signIn(email, password);

      if (mounted) {
        _showSnackbar('Account created successfully!', isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackbar('Sign Up Failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF1B5E20);

    return Scaffold(
      appBar: AppBar(
        title: Text('NEW ACCOUNT', style: GoogleFonts.oswald(letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Konsehal!',
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : primaryColor,
                ),
              ),
              Text(
                'Join the Konsehal Management system.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Email Input
              _buildLabel('Email Address'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  hint: 'boss@konsi.ph',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
              const SizedBox(height: 20),

              // Password Input
              _buildLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _buildInputDecoration(
                  hint: 'Min. 6 characters',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: primaryColor,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Password
              _buildLabel('Confirm Password'),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: _buildInputDecoration(
                  hint: 'Repeat password',
                  icon: Icons.lock_clock_outlined,
                ),
              ),
              const SizedBox(height: 40),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'REGISTER & ASCEND',
                          style: GoogleFonts.oswald(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Already have an account? Log In',
                    style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.oswald(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF1B5E20)),
      suffixIcon: suffixIcon,
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF1F8E9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
      ),
    );
  }
}
