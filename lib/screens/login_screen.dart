import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthFlowStatus { login, signup, forgotPassword, emailOtp }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  AuthFlowStatus _currentStatus = AuthFlowStatus.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'store_customer';

  final List<Map<String, String>> _roles = [
    {'value': 'hostel_student', 'label': 'Hostel Student'},
    {'value': 'store_customer', 'label': 'Store Customer'},
    {'value': 'mess_student', 'label': 'Mess Student'},
    {'value': 'staff', 'label': 'Staff'},
    {'value': 'farmer_seller', 'label': 'Mandi Farmer/Seller'},
    {'value': 'delivery_partner', 'label': 'Mandi Delivery Partner'},
  ];

 Future<void> _login() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter credentials')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final res = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    print("LOGIN SUCCESS: ${res.session}"); // 👈 ADD THIS

    if (res.session != null) {
      print("USER LOGGED IN");
    } else {
      print("LOGIN FAILED - NO SESSION");
    }

  } on AuthException catch (e) {
    print("LOGIN ERROR: ${e.message}");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your registered email')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent to your email'), backgroundColor: Colors.indigoAccent));
        setState(() => _currentStatus = AuthFlowStatus.login);
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'role': _selectedRole,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent!'), backgroundColor: Colors.green));
        setState(() => _currentStatus = AuthFlowStatus.login);
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email for OTP')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent to your email'), backgroundColor: Colors.indigoAccent));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the code from your email')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      OtpType otpType = OtpType.signup;
      if (_currentStatus == AuthFlowStatus.forgotPassword) otpType = OtpType.recovery;
      if (_currentStatus == AuthFlowStatus.emailOtp) otpType = OtpType.magiclink;
      
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _passwordController.text.trim(),
        type: otpType, 
      );
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.hostelshop://login-callback',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In Error: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 750;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(top: -100, right: -100, child: FadeIn(delay: const Duration(milliseconds: 500), child: _buildOrb(300, Colors.indigoAccent.withOpacity(isDark ? 0.1 : 0.04)))),
          Positioned(bottom: -150, left: -100, child: FadeIn(delay: const Duration(milliseconds: 800), child: _buildOrb(400, Colors.purpleAccent.withOpacity(isDark ? 0.05 : 0.02)))),
          
          SafeArea(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildGlassCard(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildGlassCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FadeInDown(
              duration: const Duration(seconds: 1),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          _buildHeader(isDark),
          const SizedBox(height: 24),
              if (_currentStatus == AuthFlowStatus.signup) ...[
                _buildTextField(_nameController, 'FULL NAME', Icons.person_outline),
                const SizedBox(height: 20),
                _buildRoleSelector(),
                const SizedBox(height: 20),
              ],
              _buildTextField(_emailController, 'EMAIL ADDRESS', Icons.alternate_email_rounded),
              const SizedBox(height: 20),
              if (_currentStatus == AuthFlowStatus.emailOtp) ...[
                _buildTextField(_passwordController, 'VERIFICATION CODE', Icons.pin_rounded),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _sendOtp, child: Text('RESEND CODE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 28),
              ] else if (_currentStatus != AuthFlowStatus.forgotPassword) ...[
                _buildTextField(_passwordController, 'PASSWORD', Icons.lock_outline_rounded, isPassword: true),
                const SizedBox(height: 12),
                if (_currentStatus == AuthFlowStatus.login)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => setState(() => _currentStatus = AuthFlowStatus.emailOtp), child: Text('LOGIN WITH OTP', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.indigoAccent, fontWeight: FontWeight.w900))),
                      TextButton(onPressed: () => setState(() => _currentStatus = AuthFlowStatus.forgotPassword), child: Text('FORGOT PASSWORD?', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.indigoAccent, fontWeight: FontWeight.w900))),
                    ],
                  ),
                const SizedBox(height: 28),
              ],
              _buildPrimaryButton(),
              const SizedBox(height: 20),
              _buildGoogleButton(),
              const SizedBox(height: 30),
                      _buildToggleAuth(),
              if (_currentStatus == AuthFlowStatus.forgotPassword || _currentStatus == AuthFlowStatus.emailOtp) ...[
                const SizedBox(height: 20),
                TextButton(onPressed: () => setState(() => _currentStatus = AuthFlowStatus.login), child: Text('BACK TO LOGIN', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
              ],
            ],
        ),
      );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Text(
          _currentStatus == AuthFlowStatus.login ? 'Welcome Back' : (_currentStatus == AuthFlowStatus.signup ? 'Create Account' : (_currentStatus == AuthFlowStatus.emailOtp ? 'Verify OTP' : 'Reset Password')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 32, letterSpacing: -1, color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 12),
        Text(
          _currentStatus == AuthFlowStatus.login ? 'Sign in to access your account' : (_currentStatus == AuthFlowStatus.signup ? 'Join our campus community portal' : (_currentStatus == AuthFlowStatus.emailOtp ? 'Enter the verification code sent to your email' : 'Enter your email to reset password')),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 20),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDark ? Colors.white24 : Colors.black26, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) : null,
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROLE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
              icon: const Icon(Icons.unfold_more_rounded, color: Colors.indigoAccent, size: 20),
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
              onChanged: (val) => setState(() => _selectedRole = val!),
              items: _roles.map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Colors.indigoAccent, Color(0xFF818CF8)]),
        boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () {
          if (_currentStatus == AuthFlowStatus.login) _login();
          else if (_currentStatus == AuthFlowStatus.signup) _signup();
          else if (_currentStatus == AuthFlowStatus.forgotPassword) _resetPassword();
          else if (_currentStatus == AuthFlowStatus.emailOtp) _verifyOtp();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : Text(_currentStatus == AuthFlowStatus.login ? 'SIGN IN' : (_currentStatus == AuthFlowStatus.signup ? 'CREATE ACCOUNT' : (_currentStatus == AuthFlowStatus.emailOtp ? 'VERIFY CODE' : 'RESET PASSWORD')), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildGoogleButton() {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return OutlinedButton.icon(
       onPressed: _isLoading ? null : _signInWithGoogle,
       icon: FaIcon(FontAwesomeIcons.google, color: isDark ? Colors.white : Colors.black87, size: 18),
       label: Text('CONTINUE WITH GOOGLE', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, letterSpacing: 1)),
       style: OutlinedButton.styleFrom(
         padding: const EdgeInsets.symmetric(vertical: 20),
         side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
         backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
       ),
     );
  }

  Widget _buildToggleAuth() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_currentStatus == AuthFlowStatus.login ? "New to the campus?" : "Already verified?", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38)),
        TextButton(
          onPressed: () => setState(() => _currentStatus = _currentStatus == AuthFlowStatus.login ? AuthFlowStatus.signup : AuthFlowStatus.login),
          child: Text(_currentStatus == AuthFlowStatus.login ? "Sign Up" : "Sign In", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

