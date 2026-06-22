import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class EmailConfigScreen extends StatefulWidget {
  const EmailConfigScreen({super.key});

  @override
  State<EmailConfigScreen> createState() => _EmailConfigScreenState();
}

class _EmailConfigScreenState extends State<EmailConfigScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  bool _saving   = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _authService.getEmailConfig();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        _emailCtrl.text = data['emailUser'] ?? '';
        _configured = data['configured'] == true;
      }
    });
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter a valid email address', error: true);
      return;
    }
    if (pass.isEmpty) {
      _snack('Enter your Gmail App Password', error: true);
      return;
    }
    setState(() => _saving = true);
    final result = await _authService.saveEmailConfig(email, pass);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result['success'] == true) _configured = true;
    });
    _snack(result['success'] ? 'Email sender configured!' : result['message'],
        error: result['success'] != true);
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

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
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
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Sender Email Setup',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _configured
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _configured
                              ? const Color(0xFF28A860)
                              : const Color(0xFFFF9500),
                          width: 1.5,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _configured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _configured ? const Color(0xFF28A860) : const Color(0xFFFF9500),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _configured
                                ? 'Email sender is configured. OTPs will be sent from ${_emailCtrl.text}.'
                                : 'No sender email set yet. OTP emails won\'t work until you configure this.',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _configured ? const Color(0xFF1B5E20) : const Color(0xFF7F4400),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    Text('Gmail Address',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _deco('e.g. yourname@gmail.com', Icons.email_outlined),
                    ),
                    const SizedBox(height: 20),

                    Text('Gmail App Password',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _deco('16-character app password', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey[400], size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Help text
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text('How to get an App Password',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue[800])),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            '1. Go to Google Account → Security\n'
                            '2. Enable 2-Step Verification\n'
                            '3. Search "App Passwords" → create one for Mail\n'
                            '4. Paste the 16-character code above',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: Colors.blue[900], height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _saving
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight),
                          color: _saving ? Colors.grey[300] : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _saving
                              ? null
                              : [BoxShadow(
                                  color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                                  blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text('Save Configuration',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
