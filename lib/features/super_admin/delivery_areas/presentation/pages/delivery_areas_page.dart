import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../delivery/domain/entities/delivery_area.dart';
import '../../../../delivery/domain/entities/delivery_settings.dart';
import '../../../../delivery/presentation/providers/delivery_area_providers.dart';
import '../../../../delivery/presentation/providers/delivery_settings_providers.dart';

/// Super admin screen that manages the delivery areas catalog.
///
/// The admin can add an area, edit it, activate or deactivate it and
/// set the fallback fee that is charged for an address that does not
/// match any area of the catalog.
class DeliveryAreasPage extends ConsumerStatefulWidget {
  const DeliveryAreasPage({super.key});

  @override
  ConsumerState<DeliveryAreasPage> createState() =>
      _DeliveryAreasPageState();
}

class _DeliveryAreasPageState extends ConsumerState<DeliveryAreasPage> {
  final _defaultFeeFormKey = GlobalKey<FormState>();
  final _defaultFeeController = TextEditingController();

  bool _savingDefaultFee = false;

  @override
  void dispose() {
    _defaultFeeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double? _parseDouble(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  String _feeText(double fee) {
    return '${fee.toStringAsFixed(2)} \u062C.\u0645';
  }

  /// Copies the fee that is stored in the backend into the field of
  /// the fallback fee, once it is loaded.
  void _syncDefaultFee(double? fee) {
    if (fee == null) {
      return;
    }

    if (_defaultFeeController.text.isNotEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _defaultFeeController.text.isNotEmpty) {
        return;
      }

      _defaultFeeController.text = fee.toStringAsFixed(2);
    });
  }

  Future<void> _saveDefaultAreaFee() async {
    if (!_defaultFeeFormKey.currentState!.validate()) {
      return;
    }

    final fee = _parseDouble(_defaultFeeController.text);

    if (fee == null) {
      return;
    }

    setState(() {
      _savingDefaultFee = true;
    });

    try {
      final saved = await ref
          .read(deliveryAreaActionsProvider)
          .updateDefaultAreaFee(fee);

      if (!mounted) {
        return;
      }

      _defaultFeeController.text = saved.toStringAsFixed(2);

      setState(() {
        _savingDefaultFee = false;
      });

      _showMessage(
        '\u062A\u0645 \u062D\u0641\u0638 \u0627\u0644\u0631\u0633\u0648\u0645 \u0627\u0644\u0627\u0641\u062A\u0631\u0627\u0639\u064A\u0629 \u0628\u0646\u062C\u0627\u062D',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingDefaultFee = false;
      });

      _showMessage(
        '\u062A\u0639\u0630\u0631 \u062D\u0641\u0638 \u0627\u0644\u0631\u0633\u0648\u0645 \u0627\u0644\u0627\u0641\u062A\u0631\u0627\u0639\u064A\u0629: $error',
      );
    }
  }

  Future<void> _toggleActive(
    DeliveryArea area,
    bool isActive,
  ) async {
    try {
      await ref.read(deliveryAreaActionsProvider).setActive(
            id: area.id,
            isActive: isActive,
          );

      if (!mounted) {
        return;
      }

      _showMessage(
        '\u062A\u0645 \u062A\u062D\u062F\u064A\u062B \u062D\u0627\u0644\u0629 \u0627\u0644\u0645\u0646\u0637\u0642\u0629',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '\u062A\u0639\u0630\u0631 \u062A\u062D\u062F\u064A\u062B \u062D\u0627\u0644\u0629 \u0627\u0644\u0645\u0646\u0637\u0642\u0629: $error',
      );
    }
  }

  Future<void> _openAreaForm({DeliveryArea? area}) async {
    final result = await showDialog<_AreaFormResult>(
      context: context,
      builder: (_) => _AreaFormDialog(area: area),
    );

    if (result == null) {
      return;
    }

    try {
      await ref.read(deliveryAreaActionsProvider).saveArea(
            id: area?.id,
            name: result.name,
            deliveryFee: result.deliveryFee,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
          );

      if (!mounted) {
        return;
      }

      _showMessage(
        '\u062A\u0645 \u062D\u0641\u0638 \u0627\u0644\u0645\u0646\u0637\u0642\u0629 \u0628\u0646\u062C\u0627\u062D',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '\u062A\u0639\u0630\u0631 \u062D\u0641\u0638 \u0627\u0644\u0645\u0646\u0637\u0642\u0629: $error',
      );
    }
  }

  Widget _defaultFeeCard(AsyncValue<DeliverySettings> settingsAsync) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '\u0631\u0633\u0648\u0645 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u0627\u0644\u0627\u0641\u062A\u0631\u0627\u0639\u064A\u0629 \u0644\u0644\u0645\u0646\u0627\u0637\u0642 \u063A\u064A\u0631 \u0627\u0644\u0645\u062F\u0631\u062C\u0629',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u062A\u0633\u062E\u062F\u0645 \u0639\u0646\u062F \u0639\u062F\u0645 \u0645\u0637\u0627\u0628\u0642\u0629 \u0627\u0644\u0639\u0646\u0648\u0627\u0646',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _defaultFeeFormKey,
              child: TextFormField(
                controller: _defaultFeeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final number =
                      _parseDouble(value ?? '');

                  if (number == null || number < 0) {
                    return '\u0623\u062F\u062E\u0644 \u0642\u064A\u0645\u0629 \u0635\u062D\u064A\u062D\u0629';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: '\u0631\u0633\u0648\u0645 \u0627\u0644\u062A\u0648\u0635\u064A\u0644',
                  hintText: '5.00',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _savingDefaultFee
                  ? null
                  : _saveDefaultAreaFee,
              icon: _savingDefaultFee
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _savingDefaultFee
                    ? '\u062C\u0627\u0631\u064A \u0627\u0644\u062D\u0641\u0638...'
                    : '\u062D\u0641\u0638 \u0627\u0644\u0631\u0633\u0648\u0645 \u0627\u0644\u0627\u0641\u062A\u0631\u0627\u0639\u064A\u0629',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            if (settingsAsync.hasError) ...[
              const SizedBox(height: 12),
              Text(
                '\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0631\u0633\u0648\u0645 \u0627\u0644\u0627\u0641\u062A\u0631\u0627\u0639\u064A\u0629',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _areaRow(DeliveryArea area) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_feeText(area.deliveryFee)}  -  '
                    '\u0627\u0644\u062A\u0631\u062A\u064A\u0628: ${area.sortOrder}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    area.isActive
                        ? '\u0641\u0639\u0627\u0644\u0629'
                        : '\u063A\u064A\u0631 \u0641\u0639\u0627\u0644\u0629',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: area.isActive
                          ? Colors.green
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: area.isActive,
              onChanged: (value) => _toggleActive(area, value),
            ),
            IconButton(
              tooltip: '\u062A\u0639\u062F\u064A\u0644',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openAreaForm(area: area),
            ),
          ],
        ),
      ),
    );
  }

  Widget _areasCard(AsyncValue<List<DeliveryArea>> areasAsync) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '\u0645\u0646\u0627\u0637\u0642 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u0627\u0644\u0645\u0633\u062C\u0644\u0629',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            areasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '\u062A\u0639\u0630\u0631 \u062D\u0645\u064A\u0644 \u0645\u0646\u0627\u0637\u0642 \u0627\u0644\u062A\u0648\u0635\u064A\u0644: $error',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(deliveryAreasAdminProvider);
                    },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text(
                      '\u0625\u0639\u0627\u062F\u0629 \u062A\u062D\u0645\u064A\u0644',
                    ),
                  ),
                ],
              ),
              data: (areas) {
                if (areas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '\u0644\u0627 \u062A\u0648\u062C\u062F \u0645\u0646\u0627\u0637\u0642 \u0645\u0633\u062C\u0644\u0629',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return Column(
                  children: areas.map(_areaRow).toList(),
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
    final areasAsync = ref.watch(deliveryAreasAdminProvider);
    final settingsAsync = ref.watch(deliverySettingsProvider);

    _syncDefaultFee(
      settingsAsync.asData?.value.defaultAreaFee,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '\u0645\u0646\u0627\u0642\u064A\u0637 \u0627\u0644\u062A\u0648\u0635\u064A\u0644',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _defaultFeeCard(settingsAsync),
                  const SizedBox(height: 16),
                  _areasCard(areasAsync),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openAreaForm(),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text(
                      '\u0623\u0636\u0627\u0641\u0629 \u0645\u0646\u0637\u0642\u0629',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
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

/// The result of the add / edit form of an area.
class _AreaFormResult {
  final String name;
  final double deliveryFee;
  final int sortOrder;
  final bool isActive;

  const _AreaFormResult({
    required this.name,
    required this.deliveryFee,
    required this.sortOrder,
    required this.isActive,
  });
}

/// The form that creates or edits an area.
class _AreaFormDialog extends StatefulWidget {
  final DeliveryArea? area;

  const _AreaFormDialog({this.area});

  @override
  State<_AreaFormDialog> createState() => _AreaFormDialogState();
}

class _AreaFormDialogState extends State<_AreaFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _feeController;
  late final TextEditingController _sortOrderController;

  late bool _isActive;

  @override
  void initState() {
    super.initState();

    final area = widget.area;

    _nameController = TextEditingController(
      text: area?.name ?? '',
    );
    _feeController = TextEditingController(
      text: area == null
          ? ''
          : area.deliveryFee.toStringAsFixed(2),
    );
    _sortOrderController = TextEditingController(
      text: (area?.sortOrder ?? 0).toString(),
    );
    _isActive = area?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final fee = _parseDouble(_feeController.text);
    final sortOrder = int.tryParse(_sortOrderController.text.trim());

    if (fee == null || sortOrder == null) {
      return;
    }

    Navigator.of(context).pop(
      _AreaFormResult(
        name: _nameController.text.trim(),
        deliveryFee: fee,
        sortOrder: sortOrder,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.area != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? '\u062A\u0639\u062F\u064A\u0644 \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0645\u0646\u0637\u0642\u0629'
            : '\u0623\u0636\u0627\u0641\u0629 \u0645\u0646\u0637\u0642\u0629 \u062C\u062F\u064A\u062F\u0629',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '\u0623\u062F\u062E\u0644 \u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0637\u0642\u0629';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: '\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0637\u0642\u0629',
                  hintText: '\u0645\u062B\u0627\u0644: \u0645\u0646\u0637\u0642\u0629',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final number = _parseDouble(value ?? '');

                  if (number == null || number < 0) {
                    return '\u0623\u062F\u062E\u0644 \u0642\u064A\u0645\u0629 \u0635\u062D\u064A\u062D\u0629';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: '\u0631\u0633\u0648\u0645 \u0627\u0644\u062A\u0648\u0635\u064A\u0644',
                  hintText: '5.00',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sortOrderController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final number = int.tryParse(
                    (value ?? '').trim(),
                  );

                  if (number == null || number < 0) {
                    return '\u0623\u062F\u062E\u0644 \u062A\u0631\u062A\u064A\u0628 \u0635\u062D\u064A\u062D';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: '\u062A\u0631\u062A\u064A\u0628 \u0627\u0644\u0639\u0631\u0636',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.low_priority_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('\u0641\u0639\u0627\u0644\u0629'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u0625\u0644\u063A\u0627\u0621'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('\u062D\u0641\u0638'),
        ),
      ],
    );
  }
}
