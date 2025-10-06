import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  const OtpScreen({super.key, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length == 6) {
      setState(() => isLoading = true);
      final user = await _authService.verifyOtp(
        verificationId: widget.verificationId,
        otp: otp,
      );

      // 'mounted' check zaroori hai async calls ke baad state update karne se pehle
      if (mounted) {
        setState(() => isLoading = false);
        if (user != null) {
          // Login safal! Home screen par jaayein.
          context.go('/');
        } else {
          // ✅ FIX: Yeh line theek kar di gayi hai
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid OTP. Please try again.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("An OTP has been sent to your number.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            Pinput(
              controller: _otpController,
              length: 6,
              autofocus: true,
              onCompleted: (pin) => _verifyOtp(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _verifyOtp,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
