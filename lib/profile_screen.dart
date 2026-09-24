import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryColor = const Color(0xFF4A72EC);
  final Color primaryTextColor = const Color(0xFF1E293B);
  final Color secondaryTextColor = const Color(0xFF64748B);

  String userName = 'Pengguna';
  String userEmail = '-';
  String userRole = 'Operator Kebun';

  int plantCount = 0;
  bool notificationsEnabled = true;
  bool isLoading = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final user = _user;
    if (user == null) return null;

    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        userName = 'Pengguna';
        userEmail = '-';
        userRole = 'Operator Kebun';
        isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getBool('soil_notifications_enabled');

      final doc = await _userDoc!.get();
      final data = doc.data();

      final firestoreName = (data?['name'] as String?)?.trim();
      final firestoreRole = (data?['role'] as String?)?.trim();

      final fallbackName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Pengguna');

      final plantsSnapshot = await _userDoc!.collection('plants').get();

      if (!mounted) return;

      setState(() {
        userName = firestoreName?.isNotEmpty == true
            ? firestoreName!
            : fallbackName;
        userEmail = user.email ?? '-';
        userRole = firestoreRole?.isNotEmpty == true
            ? firestoreRole!
            : 'Operator Kebun';
        plantCount = plantsSnapshot.size;
        notificationsEnabled = notifications ?? true;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      final fallbackName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Pengguna');

      setState(() {
        userName = fallbackName;
        userEmail = user.email ?? '-';
        isLoading = false;
      });
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = _user;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: userName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Profil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: user.email ?? '-'),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Email mengikuti akun Firebase',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama tidak boleh kosong.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            await _userDoc!.set(
                              {
                                'name': name,
                                'email': user.email,
                              },
                              SetOptions(merge: true),
                            );

                            await user.updateDisplayName(name);

                            if (!mounted) return;

                            setState(() {
                              userName = name;
                              userEmail = user.email ?? '-';
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() => saving = false);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal memperbarui profil: $e',
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final user = _user;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email akun tidak tersedia.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link ubah kata sandi dikirim ke $email.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengirim link ubah kata sandi: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soil_notifications_enabled', value);

    if (!mounted) return;

    setState(() {
      notificationsEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Notifikasi peringatan tanah diaktifkan.'
              : 'Notifikasi peringatan tanah dinonaktifkan.',
        ),
      ),
    );
  }

  Future<void> _showPrivacyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Kebijakan Privasi Data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Data akun, tanaman, dan hasil pengukuran disimpan berdasarkan '
            'akun Firebase yang sedang login. Data tersebut digunakan oleh '
            'aplikasi CitriSoil Monitor untuk menampilkan dan mengelola data '
            'tanaman milik pengguna.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Tutup',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(width: 10),
                Text(
                  'Konfirmasi Keluar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari akun ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);

                  try {
                    await FirebaseAuth.instance.signOut();

                    if (!mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                      (route) => false,
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Gagal keluar: ${e.message ?? e.code}',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Keluar',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryTextColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: isLoading
              ? const SizedBox(
                  height: 500,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    // AVATAR & PROFIL
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: primaryColor.withOpacity(0.15),
                            child: Icon(
                              Icons.person_rounded,
                              size: 54,
                              color: primaryColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: _showEditProfileDialog,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4A72EC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userRole,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // RINGKASAN AKUN
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(
                            'Status Akun',
                            'Aktif',
                            Colors.green,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.grey.shade200,
                          ),
                          _buildMiniStat(
                            'Tanaman',
                            '$plantCount',
                            primaryColor,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.grey.shade200,
                          ),
                          _buildMiniStat(
                            'Akses',
                            'SoftAP',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // MENU PENGATURAN
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSettingTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Informasi Profil',
                            onTap: _showEditProfileDialog,
                          ),
                          const Divider(height: 1, indent: 50),
                          _buildSettingTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Ubah Kata Sandi',
                            onTap: _changePassword,
                          ),
                          const Divider(height: 1, indent: 50),
                          _buildNotificationTile(),
                          const Divider(height: 1, indent: 50),
                          _buildSettingTile(
                            icon: Icons.shield_outlined,
                            title: 'Kebijakan Privasi Data',
                            onTap: _showPrivacyDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LOGOUT
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _showLogoutDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Keluar dari Akun',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile() {
    return ListTile(
      leading: Icon(
        notificationsEnabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
        color: primaryColor,
        size: 22,
      ),
      title: Text(
        'Notifikasi Peringatan Tanah',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      trailing: Switch(
        value: notificationsEnabled,
        onChanged: _toggleNotifications,
        activeColor: primaryColor,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: primaryColor,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
