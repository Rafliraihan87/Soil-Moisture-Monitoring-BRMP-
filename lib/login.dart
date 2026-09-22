import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final Color primaryTextColor = const Color(0xFF1E293B);
  final Color secondaryTextColor = const Color(0xFF64748B);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGIN / REGISTER
  // =========================================================

  Future<void> _handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty) {
      _showMessage('Email wajib diisi.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Password wajib diisi.');
      return;
    }

    if (!isLogin && password != confirmPassword) {
      _showMessage('Konfirmasi password tidak sama.');
      return;
    }

    if (!isLogin && password.length < 6) {
      _showMessage('Password minimal 6 karakter.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        // =========================
        // LOGIN FIREBASE
        // =========================
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // =========================
        // REGISTER FIREBASE
        // =========================

        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      _showMessage(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      _showMessage('Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  // =========================================================
  // FIREBASE ERROR
  // =========================================================

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';

      case 'user-not-found':
        return 'Akun dengan email tersebut tidak ditemukan.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';

      case 'email-already-in-use':
        return 'Email tersebut sudah terdaftar.';

      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';

      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';

      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';

      default:
        return 'Terjadi kesalahan: $code';
    }
  }

  // =========================================================
  // FORGOT PASSWORD
  // =========================================================

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8,
            sigmaY: 8,
          ),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFF4A72EC),
                  size: 26,
                ),
                SizedBox(width: 8),
                Text(
                  'Reset Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masukkan email yang terdaftar untuk menerima link reset kata sandi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = resetEmailController.text.trim();

                  if (email.isEmpty) {
                    _showMessage('Masukkan email terlebih dahulu.');
                    return;
                  }

                  try {
                    await _auth.sendPasswordResetEmail(
                      email: email,
                    );

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    _showMessage(
                      'Link reset password telah dikirim ke email.',
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    _showMessage(
                      _getFirebaseErrorMessage(e.code),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A72EC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kirim',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // =================================================
            // BACKGROUND
            // =================================================

            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 1.5,
                  sigmaY: 1.5,
                ),
                child: Image.asset(
                  'assets/bg_orange.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      color: const Color(0xFFEAB308),
                    );
                  },
                ),
              ),
            ),

            // =================================================
            // FORM PANEL
            // =================================================

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: screenHeight * (isLogin ? 0.74 : 0.82),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.68),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 16,
                      sigmaY: 16,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          // =================================================
                          // TITLE
                          // =================================================

                          Text(
                            isLogin
                                ? 'Welcome Back!'
                                : 'Create Account',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            isLogin
                                ? 'We missed you'
                                : 'Monitoring kebun jeruk pintar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // =================================================
                          // EMAIL
                          // =================================================

                          _buildInputField(
                            label: 'Email',
                            controller: emailController,
                            hint: 'nama@email.com',
                            prefixIcon:
                                Icons.email_outlined,
                          ),

                          const SizedBox(height: 14),

                          // =================================================
                          // PASSWORD
                          // =================================================

                          _buildInputField(
                            label: 'Password',
                            controller: passwordController,
                            hint: '••••••••',
                            prefixIcon: Icons.key_outlined,
                            isPassword: true,
                            isVisible: isPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                isPasswordVisible =
                                    !isPasswordVisible;
                              });
                            },
                          ),

                          // =================================================
                          // CONFIRM PASSWORD
                          // =================================================

                          if (!isLogin) ...[
                            const SizedBox(height: 14),
                            _buildInputField(
                              label: 'Konfirmasi Password',
                              controller:
                                  confirmPasswordController,
                              hint: '••••••••',
                              prefixIcon:
                                  Icons.lock_outline_rounded,
                              isPassword: true,
                              isVisible:
                                  isConfirmPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  isConfirmPasswordVisible =
                                      !isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ],

                          // =================================================
                          // FORGOT PASSWORD
                          // =================================================

                          if (isLogin) ...[
                            Align(
                              alignment:
                                  Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 20),

                          // =================================================
                          // BUTTON
                          // =================================================

                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4A72EC),
                                  Color(0xFF38BDF8),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A72EC)
                                      .withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(24),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isLogin
                                          ? 'Sign in'
                                          : 'Daftar Sekarang',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // =================================================
                          // TOGGLE LOGIN / REGISTER
                          // =================================================

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin
                                    ? 'Belum punya akun? '
                                    : 'Sudah punya akun? ',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    passwordController.clear();
                                    confirmPasswordController
                                        .clear();
                                  });
                                },
                                child: Text(
                                  isLogin ? 'Daftar' : 'Login',
                                  style: const TextStyle(
                                    color: Color(0xFF4A72EC),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // =================================================
                          // DIVIDER
                          // =================================================

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: secondaryTextColor
                                      .withOpacity(0.25),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'Official App',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        secondaryTextColor,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: secondaryTextColor
                                      .withOpacity(0.25),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // =================================================
                          // LOGO
                          // =================================================

                          Center(
                            child: Image.asset(
                              'assets/logo_kementan.webp',
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const Icon(
                                  Icons.agriculture_rounded,
                                  color: Colors.green,
                                  size: 45,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INPUT FIELD
  // =========================================================

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: isPassword
                ? TextInputType.text
                : TextInputType.emailAddress,
            obscureText:
                isPassword ? !isVisible : false,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color:
                    secondaryTextColor.withOpacity(0.5),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                prefixIcon,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}