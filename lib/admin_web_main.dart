import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase/supabase_config.dart';
import 'features/auth/presentation/pages/phone_login_page.dart';
import 'features/super_admin/dashboard/presentation/pages/super_admin_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env.production');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );

  runApp(const ProviderScope(child: HenaAdminWebApp()));
}

class HenaAdminWebApp extends StatelessWidget {
  const HenaAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hena Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansArabic'),
      home: const AdminOnlyGate(),
    );
  }
}

class AdminOnlyGate extends StatefulWidget {
  const AdminOnlyGate({super.key});

  @override
  State<AdminOnlyGate> createState() => _AdminOnlyGateState();
}

class _AdminOnlyGateState extends State<AdminOnlyGate> {
  final SupabaseClient _client = Supabase.instance.client;

  Session? _session;
  Future<Map<String, dynamic>?>? _profileFuture;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _session = _client.auth.currentSession;

    _authSubscription = _client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;

      final nextSession = event.session;
      final oldUserId = _session?.user.id;
      final nextUserId = nextSession?.user.id;

      if (oldUserId == nextUserId &&
          (_session != null) == (nextSession != null)) {
        return;
      }

      setState(() {
        _session = nextSession;
        _profileFuture = null;
      });
    });
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final result = await _client.rpc('get_my_profile');

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }

    return null;
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();

    if (!mounted) return;

    setState(() {
      _session = null;
      _profileFuture = null;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const PhoneLoginPage();
    }

    _profileFuture ??= _loadProfile();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _messagePage(
            title: 'تعذر التحقق من صلاحيات الحساب',
            message: 'تحقق من الاتصال ثم أعد المحاولة.',
            actionLabel: 'إعادة المحاولة',
            onAction: () {
              setState(() => _profileFuture = null);
            },
          );
        }

        final profile = snapshot.data;
        final isAdmin = profile?['role'] == 'admin';
        final isActive = profile?['is_active'] != false;

        if (isAdmin && isActive) {
          return const SuperAdminDashboardPage();
        }

        return _messagePage(
          title: 'غير مسموح بالدخول',
          message: 'هذه اللوحة مخصصة لحسابات الإدارة النشطة فقط.',
          actionLabel: 'تسجيل الخروج',
          onAction: _signOut,
        );
      },
    );
  }

  Widget _messagePage({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
