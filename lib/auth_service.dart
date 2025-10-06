import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> _createUserProfile(UserCredential userCredential) async {
    if (userCredential.additionalUserInfo?.isNewUser ?? false) {
      final user = userCredential.user!;
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName ?? user.phoneNumber ?? 'New User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isPremium': false,
      });
    }
  }

  // --- Google Sign-In Function ---
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      await _createUserProfile(userCredential);
      
      return userCredential.user;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      rethrow;
    }
  }

  // --- Phone OTP Functions ---
  Future<void> sendOtp({
    required String phoneNumber,
    required BuildContext context,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onVerificationFailed,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential = await _firebaseAuth.signInWithCredential(credential);
        await _createUserProfile(userCredential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onVerificationFailed(e.message ?? "Something went wrong");
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<User?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      await _createUserProfile(userCredential);

      return userCredential.user;
    } catch (e) {
      print("Error verifying OTP: $e");
      return null;
    }
  }
  
  // --- Sign-Out Function ---
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
