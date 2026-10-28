import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class EmailLoginPage extends ConsumerStatefulWidget {
  final String initialPhone;

  const EmailLoginPage({
    super.key,
    required this.initialPhone,
  });

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  late final TextEditingController _phoneController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const _navy = Color(0xFF102A43);
  static const _blue = Color(0xFF1D72F3);
  static const _cyan = Color(0xFF22C7D8);
  static const _orange = Color(0xFFFF9F43);

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.initialPhone,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeEgyptianPhone(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s-]'), '');

    if (phone.startsWith('+20')) {
      return phone;
    }

    if (phone.startsWith('20') && phone.length == 12) {
      return '+$phone';
    }

    if (phone.startsWith('0') && phone.length == 11) {
      return '+20${phone.substring(1)}';
    }

    return phone;
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+20(10|11|12|15)\d{8}$').hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
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
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  Future<void> _signIn() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final phone = _normalizeEgyptianPhone(_phoneController.text);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (!_isValidPhone(phone)) {
      _showMessage('من فضلك أدخل رقم هاتف مصري صحيح.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('من فضلك أدخل بريدًا إلكترونيًا صحيحًا.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('من فضلك أدخل كلمة المرور.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      // Security: the server compares the phone against the email and
      // returns a single boolean. It never returns personal data, so a
      // wrong phone, a wrong email and an unknown account are
      // indistinguishable and cannot be used to enumerate users.
      final isAccountMatch = await repository.verifyAccountPhoneEmail(
        phone: phone,
        email: email,
      );

      if (!mounted) {
        return;
      }

      if (!isAccountMatch) {
        _showMessage('بيانات تسجيل الدخول غير صحيحة.');
        return;
      }

      await repository.signInWithPhone(
        phone: phone,
        password: password,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      debugPrint('AUTH LOGIN ERROR: ${error.message}');

      if (!mounted) {
        return;
      }

      _showMessage('بيانات تسجيل الدخول غير صحيحة.');
    } catch (error, stackTrace) {
      debugPrint('AUTH LOGIN ERROR: $error');
      debugPrint('AUTH LOGIN STACKTRACE: $stackTrace');

      if (!mounted) {
        return;
      }

      _showMessage('حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFFF7FBFF),
                      Color(0xFFEAF5FC),
                      Color(0xFFF8F4EF),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -150,
              left: -100,
              child: _glow(300, _cyan.withValues(alpha: .18)),
            ),
            Positioned(
              top: 100,
              right: -130,
              child: _glow(320, _blue.withValues(alpha: .13)),
            ),
            Positioned(
              bottom: -170,
              left: -20,
              child: _glow(340, _orange.withValues(alpha: .13)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minHeight = constraints.maxHeight - bottomInset;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      24,
                      22,
                      28 + bottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        minHeight: minHeight > 0 ? minHeight : 0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBrand(),
                          const SizedBox(height: 28),
                          _buildLoginCard(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: .12),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/branding/hena_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 17),
        Text(
          'كل طلباتك هِنا',
          style: TextStyle(
            color: _navy.withValues(alpha: .68),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: .10),
            blurRadius: 35,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_blue, _cyan],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'أدخل بيانات حسابك للمتابعة',
                      style: TextStyle(
                        color: Color(0xFF66788A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _buildLabel('رقم الهاتف'),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: '+20 10XXXXXXXX',
              icon: Icons.phone_iphone_rounded,
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('البريد الإلكتروني'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'example@email.com',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('كلمة المرور (Password)'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
            decoration: _inputDecoration(
              hintText: 'أدخل كلمة المرور',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: _blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'يجب أن تتطابق بيانات الهاتف والبريد الإلكتروني مع بيانات الحساب.',
                  style: TextStyle(
                    color: _navy.withValues(alpha: .55),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_navy, _blue, _cyan],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: .25),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _navy.withValues(alpha: .88),
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _navy.withValues(alpha: .28),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: _blue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F8FC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: _navy.withValues(alpha: .07),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _blue,
          width: 1.6,
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
