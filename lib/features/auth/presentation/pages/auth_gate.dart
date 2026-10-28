import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../core/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../super_admin/dashboard/presentation/pages/super_admin_dashboard_page.dart';
import '../../../store_owner/presentation/pages/store_owner_home_page.dart';
import '../../../driver/presentation/pages/driver_home_page.dart';
import '../../../catalog/presentation/pages/store_categories_page.dart';
import '../providers/auth_providers.dart';
import 'complete_profile_page.dart';
import 'phone_login_page.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _profileUserId;
  Future<Map<String, dynamic>?>? _profileFuture;

  Future<Map<String, dynamic>?> _loadProfile() {
    return ref.read(authRemoteDataSourceProvider).getCurrentProfile();
  }

  Future<Map<String, dynamic>?> _getProfileForSession(String userId) {
    if (_profileUserId != userId || _profileFuture == null) {
      _profileUserId = userId;
      _profileFuture = _loadProfile();

      // A failed profile load must not stay cached, otherwise the user is
      // stuck on the error screen until the session itself changes.
      _profileFuture!.catchError((Object error) {
        if (_profileUserId == userId) {
          _profileUserId = null;
          _profileFuture = null;
        }
        return null;
      });
    }

    return _profileFuture!;
  }

  void _clearCachedProfile() {
    _profileUserId = null;
    _profileFuture = null;
  }

  /// Drops the cached profile and rebuilds, which triggers a fresh load.
  void _retryProfileLoad() {
    _clearCachedProfile();
    setState(() {});
  }

  Widget _buildErrorView(
    Object error,
    String context, {
    VoidCallback? onRetry,
  }) {
    final failure = mapNetworkError(error, context: context);
    debugPrint('AUTH GATE: $context failed -> ${failure.debugMessage}');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                failure.message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry ?? _retryProfileLoad,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _buildErrorView(
        error,
        'session',
        onRetry: () {
          ref.invalidate(authSessionProvider);
          _clearCachedProfile();
          setState(() {});
        },
      ),
      data: (session) {
        debugPrint('AUTH GATE SESSION: ${session?.user.id}');
        debugPrint('AUTH GATE EMAIL: ${session?.user.email}');

        if (session == null) {
          _clearCachedProfile();
          return const PhoneLoginPage();
        }

        if (!kIsWeb) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(FcmService.instance.initializeForCurrentUser());
          });
        }

        final userId = session.user.id;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getProfileForSession(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorView(
                snapshot.error!,
                'profile',
                onRetry: _retryProfileLoad,
              );
            }

            final profile = snapshot.data;

            debugPrint('AUTH GATE PROFILE: $profile');

            if (profile == null) {
              return const PhoneLoginPage();
            }

            final phone = profile['phone'] as String?;
            final fullName = profile['full_name'] as String?;
            final email =
                profile['email'] as String? ?? session.user.email ?? '';
            final role = profile['role'] as String?;

            debugPrint('AUTH GATE ROLE: $role');

            if (phone == null ||
                phone.trim().isEmpty ||
                fullName == null ||
                fullName.trim().isEmpty) {
              return CompleteProfilePage(
                phone: phone ?? '',
                email: email,
                fullName: fullName ?? '',
              );
            }

            if (role == 'admin') {
              debugPrint('AUTH GATE: ADMIN -> SUPER ADMIN DASHBOARD');

              return const HenaDoubleBackExitGuard(child: SuperAdminDashboardPage());
            }

            if (role == 'store_owner') {
              debugPrint('AUTH GATE: STORE OWNER -> STORE OWNER HOME');

              return const HenaDoubleBackExitGuard(child: StoreOwnerHomePage());
            }

            if (role == 'driver') {
              debugPrint('AUTH GATE: DRIVER -> DRIVER HOME');

              return const HenaDoubleBackExitGuard(child: DriverHomePage());
            }

            debugPrint('AUTH GATE: NON-ADMIN -> CUSTOMER HOME');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              if (ref.read(appModeProvider) != AppMode.customer) {
                ref.read(appModeProvider.notifier).state = AppMode.customer;
              }
            });

            return HenaDoubleBackExitGuard(child: StoreCategoriesPage());
          },
        );
      },
    );
  }
}

/// Prevents accidental exit when back is pressed once on a role home page.
class HenaDoubleBackExitGuard extends StatefulWidget {
  final Widget child;

  const HenaDoubleBackExitGuard({
    super.key,
    required this.child,
  });

  @override
  State<HenaDoubleBackExitGuard> createState() =>
      _HenaDoubleBackExitGuardState();
}

class _HenaDoubleBackExitGuardState
    extends State<HenaDoubleBackExitGuard> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.child;
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        final now = DateTime.now();
        final lastPress = _lastBackPress;

        if (lastPress != null &&
            now.difference(lastPress) <= const Duration(seconds: 2)) {
          _lastBackPress = null;
          unawaited(SystemNavigator.pop());
          return;
        }

        _lastBackPress = now;

        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('اضغط رجوع مرة أخرى للخروج'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: widget.child,
    );
  }
}
