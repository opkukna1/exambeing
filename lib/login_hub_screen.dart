import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';

class LoginHubScreen extends StatefulWidget {
  const LoginHubScreen({super.key});

  @override
  State<LoginHubScreen> createState() => _LoginHubScreenState();
}

class _LoginHubScreenState extends State<LoginHubScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false;
  bool _isLoadingPhone = false;

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

              // Google Sign-In Button
              _isLoadingGoogle
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.g_mobiledata), // Placeholder for Google Icon
                      label: const Text('Sign in with Google'),
                      onPressed: _signInWithGoogle,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
