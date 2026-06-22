import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _pageController = PageController();

  // Step 1 — email
  final _emailCtrl = TextEditingController();

  // Step 2 — OTP (6 boxes)
  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  // Step 3 — new password
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String _email = '';

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pageController.dispose();
    _emailCtrl.dispose();
    for (final c in _otpCtrl) { c.dispose(); }
    for (final f in _otpFocus) { f.dispose(); }
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 300);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String get _cooldownLabel {
    final m = _resendCooldown ~/ 60;
    final s = (_resendCooldown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _otpValue => _otpCtrl.map((c) => c.text).join();

  void _goToPage(int page) {
    _anim.reset();
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    _anim.forward();
  }

  // ── Step 1: send OTP ────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter a valid email address', error: true);
      return;
    }
    setState(() => _loading = true);
    final result = await _authService.requestOtp(email);
    setState(() => _loading = false);
    if (result['success']) {
      _email = email;
      _startCooldown();
      _goToPage(1);
    } else {
      _snack(result['message'], error: true);
    }
  }

  // ── Step 2: verify OTP ──────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpValue.length < 6) {
      _snack('Enter the full 6-digit code', error: true);
      return;
    }
    setState(() => _loading = true);
    final result = await _authService.checkOtp(_email, _otpValue);
    setState(() => _loading = false);
    if (result['success']) {
      _goToPage(2);
    } else {
      _snack(result['message'], error: true);
      if (result['message'].toLowerCase().contains('expired') ||
          result['message'].toLowerCase().contains('no otp')) {
        _goToPage(0);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _loading = true);
    final result = await _authService.requestOtp(_email);
    setState(() => _loading = false);
    _snack(result['success'] ? 'New code sent to $_email' : result['message'],
        error: !result['success']);
    if (result['success']) {
      _startCooldown();
      for (final c in _otpCtrl) { c.clear(); }
      _otpFocus[0].requestFocus();
    }
  }

  // ── Step 3: reset password ───────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.length < 6) {
      _snack('Password must be at least 6 characters', error: true);
      return;
    }
    if (pass != confirm) {
      _snack('Passwords do not match', error: true);
      return;
    }
    setState(() => _loading = true);
    final result = await _authService.resetPassword(_email, _otpValue, pass);
    setState(() => _loading = false);
    if (result['success']) {
      if (!mounted) return;
      _snack('Password updated! Please log in.');
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } else {
      _snack(result['message'], error: true);
      // If OTP expired, go back to step 1
      if (result['message'].toLowerCase().contains('expired') ||
          result['message'].toLowerCase().contains('no otp')) {
        _goToPage(0);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF28A860),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Shared field decoration ───────────────────────────────────────────────
  InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
      );

  // ── Orange gradient button ────────────────────────────────────────────────
  Widget _btn(String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onTap != null
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight)
                : null,
            color: onTap == null ? Colors.grey[300] : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: onTap != null
                ? [BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6))]
                : null,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: onTap,
            child: _loading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      );

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _stepDots(int current) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == current
                ? const Color(0xFFFF6B00)
                : const Color(0xFFFF6B00).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        )),
      );

  // ── Shared card wrapper ───────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 20))
          ],
        ),
        child: child,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // STEPS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _step1() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Forgot Password?',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87)),
          Text('Enter your email and we\'ll send you a reset code.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: _fieldDeco('Email Address', Icons.email_outlined),
          ),
          const SizedBox(height: 22),
          _btn('Send Reset Code', _loading ? null : _sendOtp),
        ]),
      );

  Widget _step2() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Check your email',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87)),
          Text('Enter the 6-digit code sent to $_email',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 28),

          // 6 OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _OtpBox(
              controller: _otpCtrl[i],
              focusNode: _otpFocus[i],
              onChanged: (val) {
                if (val.isNotEmpty && i < 5) {
                  _otpFocus[i + 1].requestFocus();
                } else if (val.isEmpty && i > 0) {
                  _otpFocus[i - 1].requestFocus();
                }
              },
              onBackspace: () {
                if (_otpCtrl[i].text.isEmpty && i > 0) {
                  _otpFocus[i - 1].requestFocus();
                  _otpCtrl[i - 1].clear();
                }
              },
            )),
          ),

          const SizedBox(height: 22),
          _btn('Verify Code', _loading ? null : _verifyOtp),
          const SizedBox(height: 14),

          // Resend link (disabled for 5 min after sending)
          Center(
            child: _resendCooldown > 0
                ? Text(
                    'Resend in $_cooldownLabel',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                  )
                : GestureDetector(
                    onTap: _loading ? null : _resendOtp,
                    child: RichText(
                      text: TextSpan(
                        text: "Didn't receive it? ",
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Resend',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFFFF6B00),
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ]),
      );

  Widget _step3() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Password',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87)),
          Text('Choose a strong password for your account.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          // New password
          TextField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: _fieldDeco('New Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[400], size: 20),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Confirm password
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: _fieldDeco('Confirm Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[400], size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _btn('Reset Password', _loading ? null : _resetPassword),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(children: [
          // Background image
          SizedBox.expand(
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
          // Dark overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Color(0xCC000000), Color(0xF5000000)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              // Header
              const SizedBox(height: 12),
              const Text('🔑', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFD580)]).createShader(b),
                child: Text('Reset Password',
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _fade,
                child: _stepDots(
                  _pageController.hasClients
                      ? (_pageController.page?.round() ?? 0)
                      : 0,
                ),
              ),
              const Spacer(),
              // Page view
              SizedBox(
                height: 380,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_step1(), _step2(), _step3()],
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Single OTP digit box ───────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 54,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1a1a1a)),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 2)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5)),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
