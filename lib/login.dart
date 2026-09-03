import 'dart:ui';
import 'package:flutter/material.dart';
import 'dashboard.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthScreen(),
  ));
}

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

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final Color primaryTextColor = const Color(0xFF1E293B);
  final Color secondaryTextColor = const Color(0xFF64748B);

  // Dialog Lupa Password
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF4A72EC), size: 26),
                SizedBox(width: 8),
                Text(
                  'Reset Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masukkan email atau username yang terdaftar untuk menerima link reset kata sandi.',
                  style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: resetEmailController,
                    style: TextStyle(color: primaryTextColor, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Email atau Username',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Instruksi reset password telah dikirim ke email!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A72EC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

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
            // 1. Background Jeruk (Full Screen)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Image.asset(
                  'assets/bg_orange.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFEAB308),
                  ),
                ),
              ),
            ),

            // 2. Curved Sheet / Form Panel
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
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title & Subtitle
                          Text(
                            isLogin ? 'Welcome Back!' : 'Create Account',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLogin ? 'We missed you' : 'Monitoring kebun jeruk pintar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Username Field
                          _buildInputField(
                            label: 'Username',
                            controller: usernameController,
                            hint: 'Username',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 14),

                          // Password Field
                          _buildInputField(
                            label: 'Password',
                            controller: passwordController,
                            hint: '••••••••',
                            prefixIcon: Icons.key_outlined,
                            isPassword: true,
                            isVisible: isPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),

                          // Confirm Password Field (Hanya saat Register)
                          if (!isLogin) ...[
                            const SizedBox(height: 14),
                            _buildInputField(
                              label: 'Konfirmasi Password',
                              controller: confirmPasswordController,
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              isVisible: isConfirmPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ],

                          // Forgot Password Link (Hanya muncul saat mode Login)
                          if (isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 20),

                          // Gradient Action Button (Sign in / Daftar) dengan Loading
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A72EC), Color(0xFF38BDF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A72EC).withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setState(() => isLoading = true);

                                      // Simulasi loading autentikasi dan sinkronisasi data
                                      await Future.delayed(const Duration(milliseconds: 1800));

                                      if (!mounted) return;
                                      setState(() => isLoading = false);

                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const DashboardScreen(),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isLogin ? 'Sign in' : 'Daftar Sekarang',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Toggle Antara Login & Daftar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => isLogin = !isLogin),
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

                          // Divider Pemisah
                          Row(
                            children: [
                              Expanded(child: Divider(color: secondaryTextColor.withOpacity(0.25))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'Official App',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: secondaryTextColor.withOpacity(0.25))),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Logo Instansi
                          Center(
                            child: Image.asset(
                              'assets/logo_kementan.webp',
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.agriculture_rounded,
                                color: Colors.green,
                                size: 45,
                              ),
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

  // Helper: Input Field
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
            obscureText: isPassword ? !isVisible : false,
            style: TextStyle(color: primaryTextColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: secondaryTextColor.withOpacity(0.5),
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
                        isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}