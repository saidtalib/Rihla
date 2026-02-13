import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Manages authentication and user profile sync.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────
  //  Google Sign-In
  // ─────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[AuthService] Google sign-in error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  //  Apple Sign-In
  // ─────────────────────────────────────────────
  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await _auth.signInWithCredential(oauthCredential);

      // Apple only provides the name on first sign-in
      if (appleCredential.givenName != null) {
        final name =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (name.isNotEmpty) {
          await userCredential.user?.updateDisplayName(name);
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('[AuthService] Apple sign-in error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  //  Email / Password
  // ─────────────────────────────────────────────
  Future<UserCredential> signUpWithEmail(
      String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Send verification email
    if (cred.user != null && !cred.user!.emailVerified) {
      await cred.user!.sendEmailVerification();
    }
    return cred;
  }

  Future<UserCredential> signInWithEmail(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // ─────────────────────────────────────────────
  //  Sign Out
  // ─────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  //  Delete Account
  // ─────────────────────────────────────────────
  /// Permanently deletes the user's account from Firebase Auth
  /// and removes their document from the `users` collection.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Remove Firestore user document
    try {
      await _db.collection('users').doc(user.uid).delete();
    } catch (e) {
      debugPrint('[AuthService] Failed to delete user doc: $e');
    }

    // Delete the Firebase Auth account
    await user.delete();
  }

  // ─────────────────────────────────────────────
  //  Profile Sync to Firestore
  // ─────────────────────────────────────────────
  Future<void> syncUserToFirestore({
    String? displayName,
    String? photoUrl,
    String? username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'display_name': displayName ?? user.displayName ?? '',
      'photo_url': photoUrl ?? user.photoURL ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (username != null) {
      data['username'] = username;
    }

    await _db.collection('users').doc(user.uid).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// Fetch the current user's username from Firestore.
  Future<String?> getUsername() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return doc.data()?['username'] as String?;
  }

  /// Update the Firebase Auth profile + Firestore user doc.
  Future<void> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.updateDisplayName(displayName);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    await user.reload();

    await syncUserToFirestore(
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  /// Check if the user profile is complete (has display name).
  bool get isProfileComplete {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.displayName != null && user.displayName!.trim().isNotEmpty;
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
