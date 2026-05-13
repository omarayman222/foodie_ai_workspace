import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true; // Toggles between Login and Register modes
  bool _isLoading = false; // Controls the button's loading spinner
  bool _obscurePassword = true;

  Future<void> _submitAuth() async {
    // 1. Validate the form fields
    if (!_formKey.currentState!.validate()) return;

    // 2. Hide the keyboard & start loading animation
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    Map<String, dynamic> result;

    // 3. Call your Node.js backend
    if (_isLogin) {
      result = await _authService.login(email, password);
    } else {
      // For registration, we pass a map. You can add more fields here later!
      result = await _authService.register({
        'email': email,
        'password': password,
      });
    }

    // 4. Stop loading animation
    setState(() => _isLoading = false);

    // 5. Handle the result
    if (result['success']) {
      if (!mounted) return;
      if (_isLogin) {
        // TODO: Navigate to Dashboard!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Foodie AI! 🍳'), backgroundColor: Colors.green),
        );
      } else {
        // If they registered successfully, automatically switch to login mode
        setState(() => _isLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please log in.'), backgroundColor: Colors.green),
        );
      }
    } else {
      // Show the error from Node.js (e.g., "Email already exists")
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // GestureDetector dismisses the keyboard when tapping outside the text fields
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50], // Very light, clean background
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER (Logo / Title) ---
                  Icon(Icons.restaurant_menu_rounded, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Foodie AI',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    _isLogin ? 'Welcome back! Log in to cook.' : 'Create an account to get started.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // --- FORM CONTAINER ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // EMAIL FIELD
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 16),

                          // PASSWORD FIELD
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                          const SizedBox(height: 24),

                          // SUBMIT BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 56, // Tall, tap-friendly button
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _isLoading ? null : _submitAuth,
                              child: _isLoading
                                  ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                                  : Text(
                                _isLogin ? 'Log In' : 'Sign Up',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- TOGGLE LOGIN / REGISTER ---
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
                    }),
                    child: RichText(
                      text: TextSpan(
                        text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                        children: [
                          TextSpan(
                            text: _isLogin ? "Sign Up" : "Log In",
                            style: GoogleFonts.poppins(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}