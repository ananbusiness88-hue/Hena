import 'package:app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:app/features/auth/presentation/pages/registration_page.dart';
import 'package:app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records whether the registration was actually sent to the backend.
class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource(this._client)
    : super(_client);

  final SupabaseClient _client;

  bool signUpCalled = false;

  Future<void> dispose() => _client.dispose();

  @override
  Future<bool> phoneExists(String phone) async => false;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    signUpCalled = true;

    throw StateError('The sign up request must not reach the backend.');
  }
}

void main() {
  Future<_FakeAuthRemoteDataSource> pumpRegistration(
    WidgetTester tester,
  ) async {
    // A tall viewport so the whole signup form is laid out at once and the
    // consent row is reachable without scrolling.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeAuthRemoteDataSource(
      SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        // The auto refresh timer would stay pending and fail the test.
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          home: RegistrationPage(phone: '01000000000'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    return fake;
  }

  Future<void> fillTheForm(WidgetTester tester) async {
    // The fields are addressed by their label: the phone field is a
    // TextFormField too, so positional indexes would be misleading.
    Future<void> enter(String label, String value) async {
      final field = find
          .ancestor(
            of: find.text(label),
            matching: find.byType(TextFormField),
          )
          .first;

      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    // The full name must contain at least three parts.
    await enter('الاسم بالكامل', 'أحمد محمد علي');
    await enter('البريد الإلكتروني', 'test@example.com');
    await enter('كلمة المرور', 'Password123');
    await enter('تأكيد كلمة المرور', 'Password123');
    await enter('رقم العمارة', '12');
    await enter('رقم الشقة', '5');
    await enter('تفاصيل العنوان', 'علامة مميزة');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الاندلس').last);
    await tester.pumpAndSettle();

    // The consent check only runs when the rest of the form is valid, so the
    // test makes sure every field passes its own validator.
    final errors = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.validator?.call(field.controller?.text))
        .whereType<String>()
        .toList();

    expect(errors, isEmpty, reason: 'the form must be valid: $errors');
  }

  testWidgets('the privacy policy checkbox is shown on the signup screen',
      (tester) async {
    await pumpRegistration(tester);

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('سياسة الخصوصية'), findsWidgets);
  });

  testWidgets('the privacy policy link opens the privacy policy screen',
      (tester) async {
    await pumpRegistration(tester);

    await tester.tap(find.textContaining('سياسة الخصوصية').first);
    await tester.pumpAndSettle();

    expect(find.text('سياسة الخصوصية لتطبيق "هِنا"'), findsOneWidget);
    expect(
      find.textContaining('نحن في تطبيق "هِنا" نلتزم بحماية خصوصيتك'),
      findsOneWidget,
    );
  });

  Future<void> tapCreateAccount(WidgetTester tester) async {
    final button = find.text('إنشاء الحساب والمتابعة');

    // The form is longer than the test viewport, so the button has to be
    // scrolled into view before it can be tapped.
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('the account cannot be created while the box is unchecked',
      (tester) async {
    final fake = await pumpRegistration(tester);

    await fillTheForm(tester);

    await tapCreateAccount(tester);

    expect(
      fake.signUpCalled,
      isFalse,
      reason: 'the sign up request must not be sent without the consent',
    );
    expect(
      find.textContaining('يجب الموافقة على سياسة الخصوصية'),
      findsOneWidget,
    );
  });

  testWidgets('the account can be created once the box is checked',
      (tester) async {
    final fake = await pumpRegistration(tester);

    await fillTheForm(tester);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tapCreateAccount(tester);

    expect(
      fake.signUpCalled,
      isTrue,
      reason: 'the consent unlocks the registration request',
    );
  });
}
