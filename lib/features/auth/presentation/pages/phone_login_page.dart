import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'registration_page.dart';

class PhoneLoginPage extends ConsumerStatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  ConsumerState<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends ConsumerState<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const _navy = Color(0xFF102A43);
  static const _blue = Color(0xFF1D72F3);
  static const _cyan = Color(0xFF22C7D8);
  static const _orange = Color(0xFFFF9F43);

  @override
  void dispose() {
    _phoneController.dispose();
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

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final phone = _normalizeEgyptianPhone(_phoneController.text);
    final password = _passwordController.text;

    if (!_isValidPhone(phone)) {
      _showMessage('من فضلك أدخل رقم هاتف مصري صحيح.');
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

      debugPrint('PHONE LOGIN: checking phone = $phone');

      debugPrint('PHONE LOGIN: direct phone/password authentication');

      await repository.signInWithPhone(
        phone: phone,
        password: password,
      );

      if (!mounted) {
        return;
      }

      _showMessage('تم تسجيل الدخول بنجاح.');
    } catch (error, stackTrace) {
      debugPrint('PHONE LOGIN ERROR: $error');
      debugPrint('PHONE LOGIN STACKTRACE: $stackTrace');

      if (!mounted) {
        return;
      }

      _showMessage(
        'رقم الهاتف أو كلمة المرور غير صحيحة.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRegistration() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final phone = _normalizeEgyptianPhone(_phoneController.text);

    if (!_isValidPhone(phone)) {
      _showMessage(
        'اكتب رقم الهاتف أولًا ثم اضغط إنشاء حساب جديد.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistrationPage(
          phone: phone,
        ),
      ),
    );
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
              child: _glow(
                300,
                _cyan.withValues(alpha: .18),
              ),
            ),

            Positioned(
              top: 100,
              right: -130,
              child: _glow(
                320,
                _blue.withValues(alpha: .13),
              ),
            ),

            Positioned(
              bottom: -170,
              left: -20,
              child: _glow(
                340,
                _orange.withValues(alpha: .13),
              ),
            ),

            Positioned(
              bottom: -120,
              right: -100,
              child: _glow(
                280,
                _blue.withValues(alpha: .08),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minHeight =
                      constraints.maxHeight - bottomInset;

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
                        minHeight: minHeight > 0
                            ? minHeight
                            : 0,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          _buildBrand(),
                          const SizedBox(height: 28),
                          _buildLoginCard(),
                          const SizedBox(height: 20),
                          Text(
                            'تسجيل الدخول إلى حسابك في هِنا',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  _navy.withValues(alpha: .58),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: .12),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/branding/hena_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 18),
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
      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        22,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white,
          width: 1.4,
        ),
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
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحبًا بك',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'أدخل رقم الهاتف وكلمة المرور',
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

          const SizedBox(height: 28),

          Text(
            'رقم الهاتف',
            style: TextStyle(
              color: _navy.withValues(alpha: .88),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
            decoration: InputDecoration(
              hintText: '01XXXXXXXXX',
              hintStyle: TextStyle(
                color: _navy.withValues(alpha: .28),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.phone_iphone_rounded,
                color: _blue,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F8FC),
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _navy.withValues(alpha: .07),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: _blue,
                  width: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'كلمة المرور',
            style: TextStyle(
              color: _navy.withValues(alpha: .88),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
            decoration: InputDecoration(
              hintText: 'كلمة المرور',
              hintStyle: TextStyle(
                color: _navy.withValues(alpha: .28),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: _blue,
              ),
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
                  color: _navy.withValues(alpha: .55),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F8FC),
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _navy.withValues(alpha: .07),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: _blue,
                  width: 1.6,
                ),
              ),
            ),
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
                borderRadius:
                    BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: .25),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor:
                      Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
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
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.login_rounded,
                              size: 21,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Row(
            children: [
              Expanded(
                child: Divider(
                  color: Color(0xFFE1E8EE),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'أو',
                  style: TextStyle(
                    color: Color(0xFF7A8997),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Color(0xFFE1E8EE),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed:
                _isLoading ? null : _openRegistration,
            style: OutlinedButton.styleFrom(
              minimumSize:
                  const Size.fromHeight(54),
              foregroundColor: _navy,
              side: const BorderSide(
                color: Color(0xFFD7E2EA),
                width: 1.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _blue.withValues(alpha: .85),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'الحساب الموجود يدخل مباشرةً باستخدام رقم الهاتف وكلمة المرور، بدون OTP.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _navy.withValues(alpha: .58),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
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