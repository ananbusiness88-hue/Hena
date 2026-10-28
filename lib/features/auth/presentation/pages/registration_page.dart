import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../legal/presentation/pages/privacy_policy_page.dart';
import '../../../../core/network/app_exception.dart';
import '../providers/auth_providers.dart';

class RegistrationPage extends ConsumerStatefulWidget {
  final String phone;

  const RegistrationPage({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _buildingController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _addressDetailsController = TextEditingController();

  static const _areas = <String>[
    'الاندلس',
    'عمارات 266',
    'عمارات النصر',
    'ابني بيتك 5',
    'دار مصر',
    'سكن مصر',
  ];

  String? _selectedArea;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// The account cannot be created until the privacy policy is accepted.
  bool _acceptedPrivacyPolicy = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _buildingController.dispose();
    _apartmentController.dispose();
    _addressDetailsController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedPrivacyPolicy) {
      _showMessage('يجب الموافقة على سياسة الخصوصية لإنشاء الحساب.');
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final phone = widget.phone.trim();
    final area = _selectedArea?.trim() ?? '';
    final buildingNumber = _buildingController.text.trim();
    final apartmentNumber = _apartmentController.text.trim();
    final addressDetails = _addressDetailsController.text.trim();

    final nameParts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.length < 3) {
      _showMessage(
        'من فضلك اكتب الاسم بالكامل (ثلاثة أسماء على الأقل).',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      final phoneAlreadyRegistered = await repository.phoneExists(phone);

      if (phoneAlreadyRegistered) {
        if (!mounted) {
          return;
        }

        _showMessage('رقم الهاتف مسجل بالفعل. استخدم تسجيل الدخول.');
        return;
      }

      final response = await repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      final user = response.user;

      if (user == null) {
        throw Exception(
          'تعذر إنشاء جلسة المستخدم بعد إنشاء الحساب.',
        );
      }

      await repository.createDefaultAddress(
        userId: user.id,
        recipientName: fullName,
        phone: phone,
        governorate: '',
        city: '',
        area: area,
        buildingNumber: buildingNumber,
        apartmentNumber: apartmentNumber,
        addressDetails: addressDetails,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      // The raw error is never shown to the customer: it used to expose
      // internal details such as the Supabase host and the failing RPC.
      final failure = mapNetworkError(error, context: 'signUp');
      debugPrint(
        'REGISTRATION: account creation failed -> ${failure.debugMessage}',
      );

      _showMessage(failure.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.94),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFD8E9E0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFD8E9E0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF087A4B),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
    );
  }

  /// The mandatory privacy policy consent with a link to the full policy.
  Widget _buildPrivacyPolicyConsent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _acceptedPrivacyPolicy
              ? const Color(0xFF087A4B)
              : const Color(0xFFD8E9E0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Checkbox(
              value: _acceptedPrivacyPolicy,
              onChanged: (value) {
                setState(() {
                  _acceptedPrivacyPolicy = value ?? false;
                });
              },
              activeColor: const Color(0xFF087A4B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                );
              },
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'أوافق على ',
                      style: TextStyle(
                        color: Color(0xFF162A21),
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'سياسة الخصوصية',
                      style: TextStyle(
                        color: Color(0xFF087A4B),
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF087A4B),
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' لتطبيق "هِنا".',
                      style: TextStyle(
                        color: Color(0xFF162A21),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            color: Color(0xFF123F2F),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF123F2F),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Color(0xFFE4F4E9),
                              Color(0xFFF7FBF8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFD3EADC),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 82,
                              child: Image.asset(
                                'assets/branding/hena_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'أهلًا بك في هِنا',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF123F2F),
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'كل طلباتك هِنا',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF63766A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFD8E9E0),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'بيانات الحساب',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF162A21),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'أدخل بياناتك لإنشاء حسابك في هِنا.',
                              style: TextStyle(
                                color: Color(0xFF718078),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _fullNameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'الاسم بالكامل',
                                icon: Icons.person_outline_rounded,
                                hint: 'مثال: أحمد محمد علي',
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'اكتب الاسم بالكامل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              initialValue: widget.phone,
                              readOnly: true,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              decoration: _inputDecoration(
                                label: 'رقم الهاتف',
                                icon: Icons.phone_android_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              textDirection: TextDirection.ltr,
                              decoration: _inputDecoration(
                                label: 'البريد الإلكتروني',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';

                                if (email.isEmpty) {
                                  return 'اكتب البريد الإلكتروني';
                                }

                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)) {
                                  return 'البريد الإلكتروني غير صحيح';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'تأكيد كلمة المرور',
                                icon: Icons.lock_reset_outlined,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'كلمتا المرور غير متطابقتين';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'عنوان التوصيل',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF162A21),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'سيتم حفظ عنوان التوصيل مع إنشاء الحساب.',
                              style: TextStyle(
                                color: Color(0xFF718078),
                              ),
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedArea,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                label: 'المنطقة',
                                icon: Icons.location_on_outlined,
                              ),
                              items: _areas
                                  .map(
                                    (area) => DropdownMenuItem<String>(
                                      value: area,
                                      child: Text(
                                        area,
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedArea = value;
                                });
                              },
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'اختر المنطقة';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _buildingController,
                                    keyboardType: TextInputType.number,
                                    textInputAction:
                                        TextInputAction.next,
                                    decoration: _inputDecoration(
                                      label: 'رقم العمارة',
                                      icon: Icons.apartment_rounded,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'مطلوب';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _apartmentController,
                                    keyboardType: TextInputType.number,
                                    textInputAction:
                                        TextInputAction.next,
                                    decoration: _inputDecoration(
                                      label: 'رقم الشقة',
                                      icon: Icons.home_outlined,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'مطلوب';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _addressDetailsController,
                              minLines: 2,
                              maxLines: 4,
                              textInputAction: TextInputAction.done,
                              decoration: _inputDecoration(
                                label: 'تفاصيل العنوان',
                                icon: Icons.notes_rounded,
                                hint: 'علامة مميزة أو تفاصيل إضافية',
                              ),
                            ),
                            const SizedBox(height: 22),
                            _buildPrivacyPolicyConsent(),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed:
                                  _isLoading ? null : _register,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF087A4B),
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                        ),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'إنشاء الحساب والمتابعة',
                                            textAlign: TextAlign.center,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 19,
                                  color: Color(0xFF0B7A4B),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'بعد إنشاء الحساب ستنتقل مباشرةً إلى المتابعة داخل هِنا.',
                                    style: TextStyle(
                                      color: Color(0xFF63766A),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
