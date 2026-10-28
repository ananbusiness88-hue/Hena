import '../../../../core/services/fcm_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverAccountPage extends StatefulWidget {
  const DriverAccountPage({super.key});

  @override
  State<DriverAccountPage> createState() => _DriverAccountPageState();
}

class _DriverAccountPageState extends State<DriverAccountPage> {
  XFile? _selectedImage;
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('التقاط صورة'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    if (!mounted) return;

    setState(() {
      _selectedImage = image;
    });

    await _uploadAvatar();
  }

  Future<void> _uploadAvatar() async {
    final image = _selectedImage;
    final user = _client.auth.currentUser;

    if (image == null || user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      final bytes = await image.readAsBytes();

      final extension = image.path.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';

      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final filePath = '${user.id}/avatar.$extension';

      await _client.storage
          .from('driver-avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await _client
          .from('profiles')
          .update({'avatar_url': filePath})
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _saving = false;
        _profile ??= {};
        _profile!['avatar_url'] = filePath;
        _selectedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
      );
    } catch (e) {
      debugPrint('DRIVER AVATAR UPLOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر رفع الصورة الشخصية: $e')));
    }
  }

  final _client = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _avatarSignedUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await _client.rpc('get_my_profile');

      Map<String, dynamic>? profile;

      if (result is List && result.isNotEmpty && result.first is Map) {
        profile = Map<String, dynamic>.from(result.first as Map);
      } else if (result is Map) {
        profile = Map<String, dynamic>.from(result);
      }

      String? signedUrl;

      final avatarPath = profile?['avatar_url'] as String?;

      if (avatarPath != null && avatarPath.trim().isNotEmpty) {
        signedUrl = await _client.storage
            .from('driver-avatars')
            .createSignedUrl(avatarPath, 3600);
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _avatarSignedUrl = signedUrl;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل بيانات الحساب:\n$error')),
      );
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final nameController = TextEditingController(
      text: profile['full_name'] as String? ?? '',
    );

    final phoneController = TextEditingController(
      text: profile['phone'] as String? ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل بيانات الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                setState(() => _saving = true);

                try {
                  final user = _client.auth.currentUser;
                  if (user == null) {
                    throw StateError('لم يتم العثور على المستخدم الحالي.');
                  }

                  await _client
                      .from('profiles')
                      .update({
                        'full_name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      })
                      .eq('id', user.id);

                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                } catch (error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر حفظ البيانات:\n$error')),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _saving = false);
                  }
                }
              },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();

    if (result == true) {
      await _loadProfile();
    }
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final password = passwordController.text;

                if (password.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.',
                      ),
                    ),
                  );
                  return;
                }

                if (password != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمتا المرور غير متطابقتين.'),
                    ),
                  );
                  return;
                }

                try {
                  await _client.auth.updateUser(
                    UserAttributes(password: password),
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير كلمة المرور بنجاح'),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر تغيير كلمة المرور:\n$error')),
                  );
                }
              },
              child: const Text('تغيير كلمة المرور'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();

    if (shouldChange == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب حذف الحساب'),
        content: const Text(
          'سيتم فتح صفحة طلب حذف الحساب. لن يحذف الحساب بمجرد فتح الصفحة يجب إرسال الطلب من خلالها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uri = Uri.parse(
      'https://ananbusiness88-hue.github.io/Hena/delete-account.html',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح صفحة طلب حذف الحساب'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح صفحة الحذف: $error')),
      );
    }
  }
  Future<void> _signOut() async {
    await FcmService.instance.unregisterCurrentToken();
    await _client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = const Color(0xFF159B68);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF8),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'حسابي',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withValues(alpha: 0.10),
                          border: Border.all(
                            color: green.withValues(alpha: 0.20),
                            width: 2,
                          ),
                        ),
                        child: _selectedImage != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _avatarSignedUrl != null &&
                                  (profile?['avatar_url'] as String)
                                      .trim()
                                      .isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _avatarSignedUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 52,
                                      color: green,
                                    );
                                  },
                                ),
                              )
                            : Icon(Icons.person, size: 52, color: green),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: green,
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _pickImage,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 180,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _uploadAvatar,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                         label: Text(_saving ? 'جار الرفع...' : 'حفظ الصورة'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    profile?['full_name'] as String? ?? '',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'حساب المندوب',
                    style: TextStyle(
                      color: Color(0xFF607D6F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'الحساب نشط',
                          style: TextStyle(
                            color: Color(0xFF13865B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              children: [
                _InfoTile(
                  icon: Icons.person_outline,
                  title: 'الاسم',
                  value: profile?['full_name'] as String? ?? '',
                ),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  title: 'رقم الهاتف',
                  value: profile?['phone'] as String? ?? '',
                ),
                _InfoTile(
                  icon: Icons.email_outlined,
                  title: 'البريد الإلكتروني',
                  value:
                      profile?['email'] as String? ??
                      _client.auth.currentUser?.email ??
                      '',
                ),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  title: 'نوع الحساب',
                  value: 'مندوب توصيل',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ActionCard(
              icon: Icons.edit_outlined,
              title: 'تعديل البيانات',
              subtitle: 'تحديث الاسم ورقم الهاتف',
              onTap: _editProfile,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.lock_outline,
              title: 'تغيير كلمة المرور',
              subtitle: 'تحديث كلمة المرور لتأمين الحساب',
              onTap: _changePassword,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.person_remove_alt_1_outlined,
              title: 'طلب حذف الحساب',
              subtitle: 'إرسال طلب حذف حساب هنا',
              onTap: _requestAccountDeletion,
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: const Icon(
        Icons.arrow_back_ios_new,
        size: 14,
        color: Color(0xFF9AAEA4),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: Color(0xFF789086)),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      trailing: Icon(icon, color: const Color(0xFF159B68)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF159B68).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF159B68),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71857C),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Color(0xFF9AAEA4)),
            ],
          ),
        ),
      ),
    );
  }
}
