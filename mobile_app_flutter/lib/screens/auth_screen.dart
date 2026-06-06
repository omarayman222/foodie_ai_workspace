import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    Map<String, dynamic> result;

    if (_isLogin) {
      result = await _authService.login(email, password);
    } else {
      result = await _authService.register({'email': email, 'password': password});
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      if (_isLogin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        setState(() => _isLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created! Please log in.',
                style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'], style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            // --- BACKGROUND FOOD IMAGE ---
            SizedBox(
              height: size.height,
              width: size.width,
              child: Image.network(
                'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1080&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF3366)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // --- DARK GRADIENT OVERLAY ---
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0xCC000000),
                    Color(0xF5000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // --- CONTENT ---
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    // Top branding
                    const Spacer(flex: 2),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFD580)],
                      ).createShader(bounds),
                      child: Text(
                        'Foodie AI',
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Text(
                      'Your AI-Powered Kitchen Companion',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(flex: 3),

                    // --- FORM CARD ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLogin ? 'Welcome back 👋' : 'Create account',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _isLogin ? 'Log in to discover recipes' : 'Join thousands of home chefs',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 24),

                            // EMAIL
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400], size: 20),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                              ),
                              validator: (v) => v!.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 14),

                            // PASSWORD
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.redAccent),
                                ),
                              ),
                              validator: (v) => v!.length < 6 ? 'At least 6 characters' : null,
                            ),
                            const SizedBox(height: 22),

                            // SUBMIT BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: _isLoading
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                  color: _isLoading ? Colors.grey[300] : null,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _isLoading
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _isLoading ? null : _submitAuth,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Text(
                                          _isLogin ? 'Log In' : 'Create Account',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // TOGGLE
                    TextButton(
                      onPressed: () => setState(() {
                        _isLogin = !_isLogin;
                        _formKey.currentState?.reset();
                      }),
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                          style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Sign Up' : 'Log In',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFD580),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
