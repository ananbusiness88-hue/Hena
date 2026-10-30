import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prevents accidental exit when back is pressed once on a role home page.
///
/// The first back press only shows a hint, a second press within two
/// seconds leaves the application. This is the "account / navigation
/// flow" that every role home page follows, so it is shared by the
/// customer home, the store owner dashboard and the driver home.
class HenaDoubleBackExitGuard extends StatefulWidget {
  const HenaDoubleBackExitGuard({super.key, required this.child});

  final Widget child;

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
