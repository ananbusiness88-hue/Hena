import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phone;

  const OtpPage({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_isLoading) {
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      _showMessage('    .');
      return;
    }

    final nameParts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.length < 3) {
      _showMessage('     .');
      return;
    }

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      _showMessage('     .');
      return;
    }

    if (password.length < 6) {
      _showMessage('     6     .');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('    .');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ref.read(authRepositoryProvider).signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: widget.phone,
      );

      final user = response.user;

      if (user == null) {
        throw StateError(
          '   .',
        );
      }

      await ref.read(authRepositoryProvider).updateProfile(
            userId: user.id,
            phone: widget.phone,
            fullName: fullName,
            email: email,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('  '),
            content: Text(
              '   .\n\n'
              '   :\n$email\n\n'
              '      '
              '     .',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(''),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '  :\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' '),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '   ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '    .',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _fullNameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: ' ',
                      hintText: '  ',
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(
                      text: widget.phone,
                    ),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: ' ',
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: ' ',
                      hintText: 'example@email.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: ' ',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      border: const OutlineInputBorder(),
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _createAccount(),
                    decoration: InputDecoration(
                      labelText: '  ',
                      prefixIcon: const Icon(
                        Icons.lock_reset_outlined,
                      ),
                      border: const OutlineInputBorder(),
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
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            ' ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '        .',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
