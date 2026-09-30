import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  String? profileImageData;

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
      final firestoreImage = (data?['imageData'] as String?)?.trim();

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
        profileImageData = firestoreImage?.isNotEmpty == true ? firestoreImage : null;
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
    final emailCtrl = TextEditingController(text: user.email ?? userEmail);
    final oldPasswordCtrl = TextEditingController();
    String? editedImageData = profileImageData;
    bool removeImage = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            final emailChanged = emailCtrl.text.trim().toLowerCase() !=
                (user.email ?? '').trim().toLowerCase();

            ImageProvider? imageProvider;
            if (!removeImage && editedImageData != null && editedImageData!.isNotEmpty) {
              try {
                imageProvider = MemoryImage(base64Decode(editedImageData!));
              } catch (_) {}
            }

            Future<void> pickPhoto() async {
              final action = await showModalBottomSheet<String>(
                context: builderContext,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetContext) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_outlined),
                        title: const Text('Ambil dari Kamera'),
                        onTap: () => Navigator.pop(sheetContext, 'camera'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Pilih dari Galeri'),
                        onTap: () => Navigator.pop(sheetContext, 'gallery'),
                      ),
                      if (editedImageData != null || profileImageData != null)
                        ListTile(
                          leading: const Icon(Icons.delete_outline, color: Colors.red),
                          title: const Text('Hapus Foto Profil'),
                          onTap: () => Navigator.pop(sheetContext, 'delete'),
                        ),
                    ],
                  ),
                ),
              );

              if (action == null) return;
              if (action == 'delete') {
                setDialogState(() {
                  editedImageData = null;
                  removeImage = true;
                });
                return;
              }

              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 65,
              );
              if (file == null) return;

              final bytes = await file.readAsBytes();
              setDialogState(() {
                editedImageData = base64Encode(bytes);
                removeImage = false;
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Edit Profil',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: saving ? null : pickPhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: primaryColor.withOpacity(0.15),
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? Icon(Icons.person_rounded, size: 50, color: primaryColor)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A72EC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Ketuk foto untuk mengganti', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                    const SizedBox(height: 16),
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
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (emailChanged) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: oldPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password Saat Ini',
                          helperText: 'Diperlukan untuk mengonfirmasi perubahan email.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text('Batal', style: TextStyle(color: secondaryTextColor)),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(content: Text('Nama tidak boleh kosong.')),
                      );
                      return;
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(content: Text('Format email tidak valid.')),
                      );
                      return;
                    }
                    if (emailChanged && oldPasswordCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(content: Text('Masukkan password saat ini untuk mengubah email.')),
                      );
                      return;
                    }

                    setDialogState(() => saving = true);
                    try {
                      if (emailChanged) {
                        final credential = EmailAuthProvider.credential(
                          email: user.email ?? '',
                          password: oldPasswordCtrl.text,
                        );
                        await user.reauthenticateWithCredential(credential);
                        await user.verifyBeforeUpdateEmail(email);
                      }

                      await _userDoc!.set({
                        'name': name,
                        'email': email,
                        'imageData': removeImage ? null : editedImageData,
                      }, SetOptions(merge: true));
                      await user.updateDisplayName(name);

                      if (!mounted) return;
                      setState(() {
                        userName = name;
                        userEmail = email;
                        profileImageData = removeImage ? null : editedImageData;
                      });
                      
                      if (dialogContext.mounted) Navigator.pop(dialogContext, true);

                      // POP-UP DIALOG TAMPIL JIKA EMAIL DIUBAH
                      if (emailChanged && mounted) {
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (popContext) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Row(
                                children: [
                                  Icon(Icons.mark_email_unread_rounded, color: Color(0xFF4A72EC), size: 28),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Verifikasi Email Baru',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Link verifikasi telah dikirimkan ke alamat email baru Anda:',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A72EC).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A72EC),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Silakan buka kotak masuk email tersebut dan klik link konfirmasi agar email di akun Anda resmi diperbarui.',
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(popContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A72EC),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Saya Mengerti',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      if (!builderContext.mounted) return;
                      setDialogState(() => saving = false);
                      final message = switch (e.code) {
                        'wrong-password' || 'invalid-credential' => 'Password saat ini salah.',
                        'email-already-in-use' => 'Email tersebut sudah digunakan.',
                        'invalid-email' => 'Format email tidak valid.',
                        'requires-recent-login' => 'Silakan login ulang sebelum mengubah email.',
                        _ => 'Gagal memperbarui profil: ${e.message ?? e.code}',
                      };
                      ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text(message)));
                    } catch (e) {
                      if (!builderContext.mounted) return;
                      setDialogState(() => saving = false);
                      ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text('Gagal memperbarui profil: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    oldPasswordCtrl.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profil berhasil diperbarui.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _changePassword() async {
    final user = _user;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun tidak menggunakan email/password.')));
      return;
    }

    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        bool oldObscure = true;
        bool newObscure = true;
        bool confirmObscure = true;

        return StatefulBuilder(builder: (builderContext, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Ubah Kata Sandi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: oldCtrl,
                  obscureText: oldObscure,
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => oldObscure = !oldObscure),
                      icon: Icon(oldObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: newObscure,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    helperText: 'Minimal 6 karakter.',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => newObscure = !newObscure),
                      icon: Icon(newObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: confirmObscure,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => confirmObscure = !confirmObscure),
                      icon: Icon(confirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: saving ? null : () async {
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Link reset password dikirim ke $email.'),
                          backgroundColor: Colors.green,
                        ));
                      } on FirebaseAuthException catch (e) {
                        if (!builderContext.mounted) return;
                        ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text('Gagal mengirim email reset: ${e.message ?? e.code}')));
                      }
                    },
                    child: const Text('Lupa password?'),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text('Batal', style: TextStyle(color: secondaryTextColor)),
              ),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  final oldPassword = oldCtrl.text;
                  final newPassword = newCtrl.text;
                  if (oldPassword.isEmpty) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(const SnackBar(content: Text('Masukkan password saat ini.')));
                    return;
                  }
                  if (newPassword.length < 6) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(const SnackBar(content: Text('Password baru minimal 6 karakter.')));
                    return;
                  }
                  if (newPassword != confirmCtrl.text) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(const SnackBar(content: Text('Konfirmasi password baru tidak cocok.')));
                    return;
                  }

                  setDialogState(() => saving = true);
                  try {
                    final credential = EmailAuthProvider.credential(email: email, password: oldPassword);
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(newPassword);
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } on FirebaseAuthException catch (e) {
                    if (!builderContext.mounted) return;
                    setDialogState(() => saving = false);
                    final message = switch (e.code) {
                      'wrong-password' || 'invalid-credential' => 'Password saat ini salah.',
                      'weak-password' => 'Password baru terlalu lemah. Gunakan minimal 6 karakter.',
                      'requires-recent-login' => 'Silakan login ulang sebelum mengubah password.',
                      _ => 'Gagal mengubah password: ${e.message ?? e.code}',
                    };
                    ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text(message)));
                  } catch (e) {
                    if (!builderContext.mounted) return;
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(builderContext).showSnackBar(SnackBar(content: Text('Gagal mengubah password: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );

    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password berhasil diubah.'),
        backgroundColor: Colors.green,
      ));
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
            'akun yang sedang login. Data tersebut digunakan oleh '
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
                            backgroundImage: profileImageData != null && profileImageData!.isNotEmpty
                                ? MemoryImage(base64Decode(profileImageData!))
                                : null,
                            child: profileImageData == null || profileImageData!.isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 54,
                                    color: primaryColor,
                                  )
                                : null,
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