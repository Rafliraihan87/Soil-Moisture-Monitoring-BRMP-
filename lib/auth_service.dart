import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REGISTER
  Future<User?> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getMessage(e.code));
    }
  }

  // LOGIN
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getMessage(e.code));
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  String _getMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'email-already-in-use':
        return 'Email sudah digunakan.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      default:
        return 'Terjadi kesalahan: $code';
    }
  }
}