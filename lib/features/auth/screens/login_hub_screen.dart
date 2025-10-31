import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // <-- Ise hata diya hai
import '../../../services/auth_service.dart';

class LoginHubScreen extends StatefulWidget {
  const LoginHubScreen({super.key});

  @override
  State<LoginHubScreen> createState() => _LoginHubScreenState();
}

class _LoginHubScreenState extends State<LoginHubScreen> {
  // --- Phone Controller (Commented Out) ---
  // final TextEditingController _phoneController = TextEditingController();
  
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false;
  
  // --- isLoadingPhone (Commented Out) ---
  // bool _isLoadingPhone = false;

  void _signInWithGoogle() async {
    setState(() => _isLoadingGoogle = true);
    try {
      await _authService.signInWithGoogle();
      // The router's redirect logic will handle navigation automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed: ${e.toString()}")),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoadingGoogle = false);
    }
  }

  // --- Phone Sign-In Logic (Commented Out) ---
  /*
  void _sendOtp() {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.length == 10) {
      setState(() => _isLoadingPhone = true);
      _authService.sendOtp(
        phoneNumber: "+91$phoneNumber",
        context: context,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() => _isLoadingPhone = false);
            context.push('/otp', extra: verificationId);
          }
        },
        onVerificationFailed: (error) {
           if (mounted) {
            setState(() => _isLoadingPhone = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          }
        }
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 10-digit number")),
      );
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo.png', height: 80),
              const SizedBox(height: 40),
              Text('Welcome!', style: Theme.of(context).textTheme.headlineLarge),
              Text('Sign in to continue', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 40),

              // --- Attractive Google Sign-In Button (No new package) ---
              _isLoadingGoogle
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      // Built-in 'G' icon (styled)
                      icon: Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Colors.blue[700], // Google ka 'G' jaisa
                        ),
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          color: Colors.black87, // Dark text
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _signInWithGoogle,
                      // Nayi Styling
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // Safed background
                        foregroundColor: Colors.black, // Ripple effect ka color
                        elevation: 2, // Halki si shadow
                        padding: const EdgeInsets.symmetric(vertical: 16), // Button uncha
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0), // Gol corners
                          side: BorderSide(color: Colors.grey.shade300), // Halki border
                        ),
                      ),
                    ),
              
              // --- Phone Login UI (Commented Out) ---
              
              /*
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('OR')),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // Phone Number Input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "10-digit Mobile Number",
                  prefixText: "+91 ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Send OTP Button
              _isLoadingPhone
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _sendOtp,
                      child: const Text("Continue with Phone"),
                    ),
              */
            ],
          ),
        ),
      ),
    );
  }
}
