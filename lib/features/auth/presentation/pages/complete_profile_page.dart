import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  final String phone;
  final String email;
  final String fullName;
  final bool returnToPreviousPage;

  const CompleteProfilePage({
    super.key,
    required this.phone,
    required this.email,
    required this.fullName,
    this.returnToPreviousPage = false,
  });

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState
    extends ConsumerState<CompleteProfilePage> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _buildingController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _addressDetailsController;

  String? _selectedArea;
  bool _isLoading = false;

  static const _areas = <String>[
    'الاندلس',
    'عمارات 266',
    'عمارات النصر',
    'ابني بيتك 5',
    'دار مصر',
    'سكن مصر',
  ];

  @override
  void initState() {
    super.initState();

    _fullNameController = TextEditingController(
      text: widget.fullName,
    );

    _phoneController = TextEditingController(
      text: widget.phone,
    );

    _emailController = TextEditingController(
      text: widget.email,
    );

    _buildingController = TextEditingController();
    _apartmentController = TextEditingController();
    _addressDetailsController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _buildingController.dispose();
    _apartmentController.dispose();
    _addressDetailsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isLoading) {
      return;
    }

    final area = _selectedArea;
    final buildingNumber = _buildingController.text.trim();
    final apartmentNumber = _apartmentController.text.trim();
    final addressDetails = _addressDetailsController.text.trim();

    if (area == null) {
      _showMessage('   .');
      return;
    }

    if (buildingNumber.isEmpty) {
      _showMessage('    .');
      return;
    }

    if (apartmentNumber.isEmpty) {
      _showMessage('    .');
      return;
    }

    final user = ref.read(supabaseClientProvider).auth.currentUser;

    if (user == null) {
      _showMessage(
        '  .     .',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      await repository.createDefaultAddress(
        userId: user.id,
        recipientName: widget.fullName,
        phone: widget.phone,
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

      _showMessage('   .');

      if (widget.returnToPreviousPage) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).popUntil(
          (route) => route.isFirst,
        );
      }
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
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
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 72,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '\u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0648\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
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
                      '\u0623\u0643\u0645\u0644 \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0645\u0631\u0629 \u0648\u0627\u062d\u062f\u0629\u060c \u0648\u0633\u064a\u062a\u0645 \u062d\u0641\u0638\u0647\u0627 \u0644\u062d\u0633\u0627\u0628\u0643.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _fullNameController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '\u0627\u0644\u0627\u0633\u0645',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '\u0631\u0642\u0645 \u0627\u0644\u062a\u0644\u064a\u0641\u0648\u0646',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedArea,
                      decoration: const InputDecoration(
                        labelText: '\u0627\u0644\u0645\u0646\u0637\u0642\u0629',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _areas.map(
                        (area) => DropdownMenuItem<String>(
                          value: area,
                          child: Text(
                            area,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedArea = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _buildingController,
                      label: '\u0631\u0642\u0645 \u0627\u0644\u0639\u0645\u0627\u0631\u0629',
                      icon: Icons.business_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _apartmentController,
                      label: '\u0631\u0642\u0645 \u0627\u0644\u0634\u0642\u0629',
                      icon: Icons.home_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _addressDetailsController,
                      label: '\u062a\u0641\u0627\u0635\u064a\u0644 \u0625\u0636\u0627\u0641\u064a\u0629 \u0644\u0644\u0639\u0646\u0648\u0627\u0646',
                      hint: '\u0627\u0644\u062f\u0648\u0631\u060c \u0639\u0644\u0627\u0645\u0629 \u0645\u0645\u064a\u0632\u0629\u060c \u0625\u0644\u062e - \u0627\u062e\u062a\u064a\u0627\u0631\u064a',
                      icon: Icons.notes_outlined,
                      textInputAction: TextInputAction.done,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed:
                          _isLoading ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(54),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '\u062d\u0641\u0638 \u0648\u0627\u0633\u062a\u0645\u0631\u0627\u0631',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
