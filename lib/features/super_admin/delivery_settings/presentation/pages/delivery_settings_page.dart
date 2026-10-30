import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../delivery/domain/entities/delivery_settings.dart';
import '../../../../delivery/presentation/providers/delivery_area_providers.dart';
import '../../../../delivery/presentation/providers/delivery_settings_providers.dart';

class DeliverySettingsPage extends ConsumerStatefulWidget {
  const DeliverySettingsPage({super.key});

  @override
  ConsumerState<DeliverySettingsPage> createState() =>
      _DeliverySettingsPageState();
}

class _DeliverySettingsPageState
    extends ConsumerState<DeliverySettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _baseFeeController = TextEditingController();
  final _includedStoresController = TextEditingController();
  final _extraStoreFeeController = TextEditingController();
  final _defaultAreaFeeController = TextEditingController();

  DeliverySettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSettings);
  }

  @override
  void dispose() {
    _baseFeeController.dispose();
    _includedStoresController.dispose();
    _extraStoreFeeController.dispose();
    _defaultAreaFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final settings =
          await ref.read(deliverySettingsProvider.future);

      if (!mounted) {
        return;
      }

      _settings = settings;
      _baseFeeController.text =
          settings.baseFee.toStringAsFixed(2);
      _includedStoresController.text =
          settings.includedStores.toString();
      _extraStoreFeeController.text =
          settings.extraStoreFee.toStringAsFixed(2);

      if (settings.defaultAreaFee != null &&
          _defaultAreaFeeController.text.isEmpty) {
        _defaultAreaFeeController.text =
            settings.defaultAreaFee!.toStringAsFixed(2);
      }

      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644: $error';
      });
    }
  }

  double? _parseDouble(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  DeliverySettings? _settingsFromForm() {
    final baseFee = _parseDouble(_baseFeeController.text);
    final includedStores =
        int.tryParse(_includedStoresController.text.trim());
    final extraStoreFee =
        _parseDouble(_extraStoreFeeController.text);

    if (baseFee == null ||
        includedStores == null ||
        extraStoreFee == null ||
        includedStores < 1 ||
        baseFee < 0 ||
        extraStoreFee < 0) {
      return null;
    }

    return DeliverySettings(
      baseFee: baseFee,
      includedStores: includedStores,
      extraStoreFee: extraStoreFee,
      updatedAt: _settings?.updatedAt,
    );
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseFee = _parseDouble(_baseFeeController.text);
    final includedStores =
        int.tryParse(_includedStoresController.text.trim());
    final extraStoreFee =
        _parseDouble(_extraStoreFeeController.text);

    if (baseFee == null ||
        includedStores == null ||
        extraStoreFee == null) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final repository =
          ref.read(deliverySettingsRepositoryProvider);

      final updated = await repository.updateSettings(
        baseFee: baseFee,
        includedStores: includedStores,
        extraStoreFee: extraStoreFee,
      );

      final defaultAreaFee = _parseDouble(
        _defaultAreaFeeController.text,
      );

      // The fallback fee of the areas that are not listed is stored
      // in its own column, so it is saved with its own function. The
      // field is optional, an empty value leaves the stored fee
      // untouched.
      if (defaultAreaFee != null && defaultAreaFee >= 0) {
        await ref
            .read(deliveryAreaActionsProvider)
            .updateDefaultAreaFee(defaultAreaFee);
      }

      if (!mounted) {
        return;
      }

      _settings = updated;
      ref.invalidate(deliverySettingsProvider);

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u0645 \u062d\u0641\u0638 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644 \u0628\u0646\u062c\u0627\u062d',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage =
            '\u062a\u0639\u0630\u0631 \u062d\u0641\u0638 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644: $error';
      });
    }
  }

  String _feeText(double fee) {
    return '${fee.toStringAsFixed(2)} \u062c.\u0645';
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (_) => _refreshPreview(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _previewCard() {
    final formSettings = _settingsFromForm();
    final preview =
        formSettings ?? _settings;

    if (preview == null) {
      return const SizedBox.shrink();
    }

    const storeCounts = <int>[1, 2, 3, 4, 5, 6];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '\u0645\u0639\u0627\u064a\u0646\u0629 \u0631\u0633\u0648\u0645 \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...storeCounts.map(
              (count) {
                final fee = preview.calculateFee(count);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count \u0645\u062d\u0644',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _feeText(fee),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 820),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '\u0627\u0644\u062a\u062d\u0643\u0645 \u0641\u064a \u0631\u0633\u0648\u0645 \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
                                    style: theme
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\u0627\u0644\u0642\u064a\u0645 \u0627\u0644\u062c\u062f\u064a\u062f\u0629 \u062a\u0637\u0628\u0642 \u0645\u0646 \u0642\u0627\u0639\u062f\u0629 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a \u0639\u0644\u0649 \u0627\u0644\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u062c\u062f\u064a\u062f\u0629\u060c \u0648\u0644\u0627 \u062a\u063a\u064a\u0631 \u0627\u0644\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u0642\u062f\u064a\u0645\u0629 \u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0629.',
                                    style:
                                        theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _field(
                                    label:
                                        '\u0627\u0644\u0631\u0633\u0648\u0645 \u0627\u0644\u0623\u0633\u0627\u0633\u064a\u0629',
                                    hint: '25.00',
                                    controller:
                                        _baseFeeController,
                                    icon:
                                        Icons.payments_outlined,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: (value) {
                                      final number =
                                          _parseDouble(
                                        value ?? '',
                                      );

                                      if (number == null ||
                                          number < 0) {
                                        return '\u0623\u062f\u062e\u0644 \u0642\u064a\u0645\u0629 \u0635\u062d\u064a\u062d\u0629';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _field(
                                    label:
                                        '\u0639\u062f\u062f \u0627\u0644\u0645\u062d\u0644\u0627\u062a \u0627\u0644\u0645\u0634\u0645\u0648\u0644\u0629',
                                    hint: '3',
                                    controller:
                                        _includedStoresController,
                                    icon:
                                        Icons.storefront_outlined,
                                    keyboardType:
                                        TextInputType.number,
                                    validator: (value) {
                                      final number =
                                          int.tryParse(
                                        (value ?? '').trim(),
                                      );

                                      if (number == null ||
                                          number < 1) {
                                        return '\u0627\u0644\u0639\u062f\u062f \u064a\u062c\u0628 \u0623\u0646 \u064a\u0643\u0648\u0646 1 \u0623\u0648 \u0623\u0643\u062b\u0631';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _field(
                                    label:
                                        '\u0631\u0633\u0648\u0645 \u0643\u0644 \u0645\u062d\u0644 \u0625\u0636\u0627\u0641\u064a',
                                    hint: '5.00',
                                    controller:
                                        _extraStoreFeeController,
                                    icon:
                                        Icons.add_business_outlined,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: (value) {
                                      final number =
                                          _parseDouble(
                                        value ?? '',
                                      );

                                      if (number == null ||
                                          number < 0) {
                                        return '\u0623\u062f\u062e\u0644 \u0642\u064a\u0645\u0629 \u0635\u062d\u064a\u062d\u0629';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _field(
                                    label:
                                        '\u0631\u0633\u0648\u0645 \u0627\u0644\u062a\u0648\u0635\u064a\u0644 \u0627\u0644\u0627\u0641\u062a\u0631\u0627\u0639\u064a\u0629 \u0644\u0644\u0645\u0646\u0627\u0637\u0642 \u063a\u064a\u0631 \u0627\u0644\u0645\u062f\u0631\u062c\u0629',
                                    hint: '5.00',
                                    controller:
                                        _defaultAreaFeeController,
                                    icon:
                                        Icons.map_outlined,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: (value) {
                                      final text =
                                          (value ?? '').trim();

                                      if (text.isEmpty) {
                                        return null;
                                      }

                                      final number =
                                          _parseDouble(text);

                                      if (number == null ||
                                          number < 0) {
                                        return '\u0623\u062f\u062e\u0644 \u0642\u064a\u0645\u0629 \u0635\u062d\u064a\u062d\u0629';
                                      }

                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _previewCard(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(16),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: theme
                                        .colorScheme
                                        .error,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                _saving ? null : _saveSettings,
                            icon: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_outlined,
                                  ),
                            label: Text(
                              _saving
                                  ? '\u062c\u0627\u0631\u064a \u0627\u0644\u062d\u0641\u0638...'
                                  : '\u062d\u0641\u0638 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(54),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed:
                                _saving ? null : _loadSettings,
                            icon: const Icon(
                              Icons.refresh_outlined,
                            ),
                            label: const Text(
                              '\u0625\u0639\u0627\u062f\u0629 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
                            ),
                          ),
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