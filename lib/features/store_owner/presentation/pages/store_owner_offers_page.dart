import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/product_pricing.dart';
import '../../../catalog/domain/entities/store.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../domain/entities/store_owner_offer.dart';
import '../providers/store_owner_providers.dart';

class StoreOwnerOffersPage extends ConsumerStatefulWidget {
  const StoreOwnerOffersPage({super.key});

  @override
  ConsumerState<StoreOwnerOffersPage> createState() =>
      _StoreOwnerOffersPageState();
}

class _StoreOwnerOffersPageState extends ConsumerState<StoreOwnerOffersPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _offerPriceController = TextEditingController();

  String? _selectedStoreId;
  String? _selectedProductId;
  String? _selectedPricingId;

  DateTime? _startDate;
  DateTime? _endDate;

  String? _editingOfferId;
  Product? _selectedProduct;
  double _originalPrice = 0;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _offerPriceController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _editingOfferId = null;
      _selectedStoreId = null;
      _selectedProductId = null;
      _selectedPricingId = null;
      _selectedProduct = null;
      _startDate = null;
      _endDate = null;
      _originalPrice = 0;

      _titleController.clear();
      _descriptionController.clear();
      _offerPriceController.clear();
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _selectedProductId = product.id;
      _selectedPricingId = null;
      _originalPrice = 0;
      _offerPriceController.clear();

      if (_titleController.text.trim().isEmpty) {
        _titleController.text = '\u{639}\u{631}\u{636} ${product.name}';
      }
    });
  }

  void _editOffer(StoreOwnerOffer offer) {
    setState(() {
      _editingOfferId = offer.id;
      _selectedStoreId = offer.storeId;
      _selectedProductId = offer.productId;
      _selectedPricingId = offer.pricingId;
      _selectedProduct = null;
      _originalPrice = offer.originalPrice;
      _startDate = offer.startDate.toLocal();
      _endDate = offer.endDate.toLocal();

      _titleController.text = offer.title;
      _descriptionController.text = offer.description ?? '';
      _offerPriceController.text = offer.offerPrice.toStringAsFixed(2);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _formKey.currentContext == null) return;

      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText:
          '\u{627}\u{62E}\u{62A}\u{631} \u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{628}\u{62F}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
      cancelText: '\u{625}\u{644}\u{63A}\u{627}\u{621}',
      confirmText: '\u{62A}\u{623}\u{643}\u{64A}\u{62F}',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate ?? now),
      cancelText: '\u{625}\u{644}\u{63A}\u{627}\u{621}',
      confirmText: '\u{62A}\u{623}\u{643}\u{64A}\u{62F}',
      helpText:
          '\u{627}\u{62E}\u{62A}\u{631} \u{648}\u{642}\u{62A} \u{628}\u{62F}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
    );

    if (time == null || !mounted) return;

    setState(() {
      _startDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final minimum = _startDate ?? now;
    final initial = _endDate ?? minimum.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minimum) ? minimum : initial,
      firstDate: minimum,
      lastDate: DateTime(now.year + 5),
      helpText:
          '\u{627}\u{62E}\u{62A}\u{631} \u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{646}\u{647}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
      cancelText: '\u{625}\u{644}\u{63A}\u{627}\u{621}',
      confirmText: '\u{62A}\u{623}\u{643}\u{64A}\u{62F}',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _endDate ?? minimum.add(const Duration(days: 1)),
      ),
      cancelText: '\u{625}\u{644}\u{63A}\u{627}\u{621}',
      confirmText: '\u{62A}\u{623}\u{643}\u{64A}\u{62F}',
      helpText:
          '\u{627}\u{62E}\u{62A}\u{631} \u{648}\u{642}\u{62A} \u{646}\u{647}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
    );

    if (time == null || !mounted) return;

    setState(() {
      _endDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _onPricingChanged(String? pricingId, List<ProductPricing> pricingList) {
    ProductPricing? pricing;

    for (final item in pricingList) {
      if (item.id == pricingId) {
        pricing = item;
        break;
      }
    }

    setState(() {
      _selectedPricingId = pricingId;
      _originalPrice = pricing?.price ?? 0;
      _offerPriceController.clear();
    });
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStoreId == null ||
        _selectedProductId == null ||
        _selectedPricingId == null) {
      _showMessage(
        '\u{64A}\u{631}\u{62C}\u{649} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631} \u{648}\u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} \u{648}\u{646}\u{648}\u{639} \u{627}\u{644}\u{633}\u{639}\u{631}.',
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showMessage(
        '\u{64A}\u{631}\u{62C}\u{649} \u{62A}\u{62D}\u{62F}\u{64A}\u{62F} \u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{628}\u{62F}\u{627}\u{64A}\u{629} \u{648}\u{646}\u{647}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}.',
      );
      return;
    }

    if (!_endDate!.isAfter(_startDate!)) {
      _showMessage(
        '\u{64A}\u{62C}\u{628} \u{623}\u{646} \u{64A}\u{643}\u{648}\u{646} \u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{646}\u{647}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636} \u{628}\u{639}\u{62F} \u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{627}\u{644}\u{628}\u{62F}\u{627}\u{64A}\u{629}.',
      );
      return;
    }

    final offerPrice = double.tryParse(
      _offerPriceController.text.trim().replaceAll(',', '.'),
    );

    if (offerPrice == null || offerPrice <= 0) {
      _showMessage(
        '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{633}\u{639}\u{631} \u{639}\u{631}\u{636} \u{635}\u{62D}\u{64A}\u{62D} \u{623}\u{643}\u{628}\u{631} \u{645}\u{646} \u{635}\u{641}\u{631}.',
      );
      return;
    }

    if (_originalPrice <= 0) {
      _showMessage(
        '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{62F}\u{64A}\u{62F} \u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A} \u{644}\u{644}\u{645}\u{646}\u{62A}\u{62C}.',
      );
      return;
    }

    if (offerPrice >= _originalPrice) {
      _showMessage(
        '\u{64A}\u{62C}\u{628} \u{623}\u{646} \u{64A}\u{643}\u{648}\u{646} \u{633}\u{639}\u{631} \u{627}\u{644}\u{639}\u{631}\u{636} \u{623}\u{642}\u{644} \u{645}\u{646} \u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A}.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final repository = ref.read(storeOwnerOfferRepositoryProvider);

      if (_editingOfferId == null) {
        await repository.createOffer(
          storeId: _selectedStoreId!,
          productId: _selectedProductId!,
          pricingId: _selectedPricingId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          originalPrice: _originalPrice,
          offerPrice: offerPrice,
          imageUrl: _selectedProduct?.imageUrl,
          startDate: _startDate!,
          endDate: _endDate!,
        );

        _showMessage(
          '\u{62A}\u{645} \u{625}\u{646}\u{634}\u{627}\u{621} \u{627}\u{644}\u{639}\u{631}\u{636} \u{628}\u{646}\u{62C}\u{627}\u{62D}\u{60C} \u{648}\u{647}\u{648} \u{628}\u{627}\u{646}\u{62A}\u{638}\u{627}\u{631} \u{627}\u{644}\u{645}\u{631}\u{627}\u{62C}\u{639}\u{629}.',
        );
      } else {
        await repository.updateOffer(
          offerId: _editingOfferId!,
          storeId: _selectedStoreId!,
          productId: _selectedProductId!,
          pricingId: _selectedPricingId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          originalPrice: _originalPrice,
          offerPrice: offerPrice,
          imageUrl: _selectedProduct?.imageUrl,
          startDate: _startDate!,
          endDate: _endDate!,
        );

        _showMessage(
          '\u{62A}\u{645} \u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{627}\u{644}\u{639}\u{631}\u{636} \u{628}\u{646}\u{62C}\u{627}\u{62D}\u{60C} \u{648}\u{647}\u{648} \u{628}\u{627}\u{646}\u{62A}\u{638}\u{627}\u{631} \u{627}\u{644}\u{645}\u{631}\u{627}\u{62C}\u{639}\u{629}.',
        );
      }

      ref.invalidate(storeOwnerOffersProvider);
      _clearForm();
    } catch (error) {
      _showMessage('\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '\u{63A}\u{64A}\u{631} \u{645}\u{62D}\u{62F}\u{62F}';
    }

    final local = value.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _approvalText(StoreOwnerOfferApprovalStatus status) {
    switch (status) {
      case StoreOwnerOfferApprovalStatus.pending:
        return '\u{642}\u{64A}\u{62F} \u{627}\u{644}\u{645}\u{631}\u{627}\u{62C}\u{639}\u{629}';
      case StoreOwnerOfferApprovalStatus.approved:
        return '\u{645}\u{642}\u{628}\u{648}\u{644}';
      case StoreOwnerOfferApprovalStatus.rejected:
        return '\u{645}\u{631}\u{641}\u{648}\u{636}';
    }
  }

  Color _approvalColor(StoreOwnerOfferApprovalStatus status) {
    switch (status) {
      case StoreOwnerOfferApprovalStatus.pending:
        return const Color(0xFFE89A24);
      case StoreOwnerOfferApprovalStatus.approved:
        return const Color(0xFF2E9B68);
      case StoreOwnerOfferApprovalStatus.rejected:
        return const Color(0xFFD9534F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);
    final offersAsync = ref.watch(storeOwnerOffersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          '\u{627}\u{644}\u{639}\u{631}\u{648}\u{636} \u{648}\u{627}\u{644}\u{62E}\u{635}\u{648}\u{645}\u{627}\u{62A}',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip:
                '\u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{627}\u{644}\u{639}\u{631}\u{648}\u{636}',
            onPressed: () {
              ref.invalidate(storeOwnerOffersProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(storeOwnerOffersProvider);
          await ref.read(storeOwnerOffersProvider.future);
        },
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildForm(storesAsync),
            const SizedBox(height: 24),
            _buildOffersSection(offersAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFE8F3FF), Color(0xFFF4F9FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6E8FA)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: Color(0xFF2878C8),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u{639}\u{631}\u{648}\u{636} \u{648}\u{62E}\u{635}\u{648}\u{645}\u{627}\u{62A} \u{645}\u{62A}\u{62C}\u{631}\u{643}',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  '\u{623}\u{646}\u{634}\u{626} \u{639}\u{631}\u{648}\u{636}\u{64B}\u{627} \u{645}\u{645}\u{64A}\u{632}\u{629} \u{639}\u{644}\u{649} \u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{645}\u{62A}\u{62C}\u{631}\u{643}.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Store>> storesAsync) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE3EAF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_business_outlined,
                      color: Color(0xFF2878C8),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _editingOfferId == null
                          ? '\u{625}\u{636}\u{627}\u{641}\u{629} \u{639}\u{631}\u{636} \u{62C}\u{62F}\u{64A}\u{62F}'
                          : '\u{62A}\u{639}\u{62F}\u{64A}\u{644} \u{627}\u{644}\u{639}\u{631}\u{636}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_editingOfferId != null)
                    IconButton(
                      tooltip:
                          '\u{645}\u{633}\u{62D} \u{627}\u{644}\u{62D}\u{642}\u{648}\u{644}',
                      onPressed: _saving ? null : _clearForm,
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              storesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _errorText(
                  '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{645}\u{64A}\u{644} \u{627}\u{644}\u{645}\u{62A}\u{627}\u{62C}\u{631}: $error',
                ),
                data: (stores) {
                  if (stores.isEmpty) {
                    return const Text(
                      '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{645}\u{62A}\u{627}\u{62C}\u{631} \u{645}\u{631}\u{62A}\u{628}\u{637}\u{629} \u{628}\u{62D}\u{633}\u{627}\u{628}\u{643}.',
                    );
                  }

                  return _dropdown<String>(
                    value: _selectedStoreId,
                    label:
                        '\u{627}\u{62E}\u{62A}\u{631} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}',
                    icon: Icons.storefront_outlined,
                    items: stores
                        .map(
                          (store) => DropdownMenuItem<String>(
                            value: store.id,
                            child: Text(
                              store.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedStoreId = value;
                              _selectedProductId = null;
                              _selectedPricingId = null;
                              _selectedProduct = null;
                              _originalPrice = 0;
                              _offerPriceController.clear();
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return '\u{64A}\u{631}\u{62C}\u{649} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}.';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              if (_selectedStoreId != null)
                _buildProductSelector(_selectedStoreId!),
              if (_selectedProductId != null) const SizedBox(height: 14),
              if (_selectedProductId != null)
                _buildPricingSelector(_selectedProductId!),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 14),
                _buildProductPreview(_selectedProduct!),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label:
                      '\u{639}\u{646}\u{648}\u{627}\u{646} \u{627}\u{644}\u{639}\u{631}\u{636}',
                  hint:
                      '\u{645}\u{62B}\u{627}\u{644}: \u{62E}\u{635}\u{645} \u{639}\u{644}\u{649} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
                  icon: Icons.title_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{639}\u{646}\u{648}\u{627}\u{646} \u{627}\u{644}\u{639}\u{631}\u{636}.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: _inputDecoration(
                  label:
                      '\u{648}\u{635}\u{641} \u{627}\u{644}\u{639}\u{631}\u{636}',
                  hint:
                      '\u{623}\u{636}\u{641} \u{62A}\u{641}\u{627}\u{635}\u{64A}\u{644} \u{627}\u{644}\u{639}\u{631}\u{636} (\u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631}\u{64A}).',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 14),
              _buildPriceArea(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      label:
                          '\u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{628}\u{62F}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
                      value: _formatDate(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onPressed: _saving ? null : _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateButton(
                      label:
                          '\u{62A}\u{627}\u{631}\u{64A}\u{62E} \u{646}\u{647}\u{627}\u{64A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{636}',
                      value: _formatDate(_endDate),
                      icon: Icons.event_outlined,
                      onPressed: _saving ? null : _pickEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveOffer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2878C8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _editingOfferId == null
                        ? '\u{625}\u{646}\u{634}\u{627}\u{621} \u{627}\u{644}\u{639}\u{631}\u{636}'
                        : '\u{62D}\u{641}\u{638} \u{627}\u{644}\u{62A}\u{639}\u{62F}\u{64A}\u{644}\u{627}\u{62A}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSelector(String storeId) {
    final productsAsync = ref.watch(activeProductsByStoreProvider(storeId));

    return productsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => _errorText(
        '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{645}\u{64A}\u{644} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}: $error',
      ),
      data: (products) {
        if (products.isEmpty) {
          return _emptyFieldMessage(
            Icons.inventory_2_outlined,
            '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{646}\u{634}\u{637}\u{629} \u{641}\u{64A} \u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}.',
          );
        }

        final selectedExists = products.any(
          (product) => product.id == _selectedProductId,
        );

        return _dropdown<String>(
          value: selectedExists ? _selectedProductId : null,
          label:
              '\u{627}\u{62E}\u{62A}\u{631} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
          icon: Icons.inventory_2_outlined,
          items: products
              .map(
                (product) => DropdownMenuItem<String>(
                  value: product.id,
                  child: Text(product.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) {
                  for (final product in products) {
                    if (product.id == value) {
                      _selectProduct(product);
                      break;
                    }
                  }
                },
          validator: (value) {
            if (value == null) {
              return '\u{64A}\u{631}\u{62C}\u{649} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}.';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildPricingSelector(String productId) {
    final pricingAsync = ref.watch(activePricingByProductProvider(productId));

    return pricingAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => _errorText(
        '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{645}\u{64A}\u{644} \u{627}\u{644}\u{623}\u{633}\u{639}\u{627}\u{631}: $error',
      ),
      data: (pricingList) {
        if (pricingList.isEmpty) {
          return _emptyFieldMessage(
            Icons.price_check_outlined,
            '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{62E}\u{64A}\u{627}\u{631}\u{627}\u{62A} \u{62A}\u{633}\u{639}\u{64A}\u{631} \u{646}\u{634}\u{637}\u{629} \u{644}\u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}.',
          );
        }

        if (pricingList.length == 1) {
          final pricing = pricingList.first;

          if (_selectedPricingId != pricing.id ||
              _originalPrice != pricing.price) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              setState(() {
                _selectedPricingId = pricing.id;
                _originalPrice = pricing.price;
              });
            });
          }

          return _buildOriginalPriceCard(pricing, showSelector: false);
        }

        return Column(
          children: [
            _dropdown<String>(
              value:
                  pricingList.any((pricing) => pricing.id == _selectedPricingId)
                  ? _selectedPricingId
                  : null,
              label:
                  '\u{646}\u{648}\u{639} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631} / \u{627}\u{644}\u{648}\u{62D}\u{62F}\u{629}',
              icon: Icons.sell_outlined,
              items: pricingList
                  .map(
                    (pricing) => DropdownMenuItem<String>(
                      value: pricing.id,
                      child: Text(
                        '${_pricingLabel(pricing)}  '
                        '${pricing.price.toStringAsFixed(2)} \u{62C}.\u{645}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => _onPricingChanged(value, pricingList),
              validator: (value) {
                if (value == null) {
                  return '\u{64A}\u{631}\u{62C}\u{649} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{646}\u{648}\u{639} \u{627}\u{644}\u{633}\u{639}\u{631}.';
                }
                return null;
              },
            ),
            if (_selectedPricingId != null) ...[
              const SizedBox(height: 10),
              for (final pricing in pricingList)
                if (pricing.id == _selectedPricingId)
                  _buildOriginalPriceCard(pricing, showSelector: true),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOriginalPriceCard(
    ProductPricing pricing, {
    required bool showSelector,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sell_outlined, color: Color(0xFF2878C8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showSelector
                      ? '\u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A} \u{62D}\u{633}\u{628} \u{62E}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631}'
                      : '\u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  '${pricing.price.toStringAsFixed(2)} \u{62C}.\u{645}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D3557),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPreview(Product product) {
    final imageUrl = product.imageUrl?.trim();

    return Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 80,
              height: 80,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFFEAF4FF),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF7AA7CF),
                        size: 30,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Container(
                          color: const Color(0xFFEAF4FF),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF7AA7CF),
                            size: 30,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} \u{627}\u{644}\u{645}\u{62D}\u{62F}\u{62F}',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9B68)),
        ],
      ),
    );
  }

  Widget _buildPriceArea() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE1E6EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A}',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _originalPrice > 0
                      ? '${_originalPrice.toStringAsFixed(2)} \u{62C}.\u{645}'
                      : '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D3557),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _offerPriceController,
            enabled: !_saving && _originalPrice > 0,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _inputDecoration(
              label:
                  '\u{633}\u{639}\u{631} \u{627}\u{644}\u{639}\u{631}\u{636}',
              hint:
                  '\u{623}\u{62F}\u{62E}\u{644} \u{633}\u{639}\u{631} \u{627}\u{644}\u{639}\u{631}\u{636}',
              icon: Icons.local_offer_outlined,
            ).copyWith(suffixText: '\u{62C}.\u{645}'),
            validator: (value) {
              final price = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );

              if (price == null || price <= 0) {
                return '\u{623}\u{62F}\u{62E}\u{644} \u{633}\u{639}\u{631}\u{64B}\u{627} \u{635}\u{62D}\u{64A}\u{62D}\u{64B}\u{627} \u{623}\u{643}\u{628}\u{631} \u{645}\u{646} \u{635}\u{641}\u{631}.';
              }

              if (_originalPrice > 0 && price >= _originalPrice) {
                return '\u{633}\u{639}\u{631} \u{627}\u{644}\u{639}\u{631}\u{636} \u{64A}\u{62C}\u{628} \u{623}\u{646} \u{64A}\u{643}\u{648}\u{646} \u{623}\u{642}\u{644} \u{645}\u{646} \u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A}.';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFFBFCFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF6BA8DC), width: 1.5),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    FormFieldValidator<T>? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDecoration(label: label, hint: label, icon: icon),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildDateButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2878C8),
        side: const BorderSide(color: Color(0xFFD5E4F2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      icon: Icon(icon, size: 20),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D3557),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersSection(AsyncValue<List<StoreOwnerOffer>> offersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 4),
          child: Text(
            '\u{627}\u{644}\u{639}\u{631}\u{648}\u{636} \u{627}\u{644}\u{62D}\u{627}\u{644}\u{64A}\u{629}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        offersAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _errorText(
                '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{645}\u{64A}\u{644} \u{627}\u{644}\u{639}\u{631}\u{648}\u{636}: $error',
              ),
            ),
          ),
          data: (offers) {
            if (offers.isEmpty) {
              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 46,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{639}\u{631}\u{648}\u{636} \u{62D}\u{62A}\u{649} \u{627}\u{644}\u{622}\u{646}.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(children: offers.map(_buildOfferCard).toList());
          },
        ),
      ],
    );
  }

  Widget _buildOfferCard(StoreOwnerOffer offer) {
    final color = _approvalColor(offer.approvalStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3EAF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusChip(_approvalText(offer.approvalStatus), color),
              ],
            ),
            if (offer.description != null &&
                offer.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                offer.description!,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _priceInfo(
                    '\u{627}\u{644}\u{633}\u{639}\u{631} \u{627}\u{644}\u{623}\u{635}\u{644}\u{64A}',
                    '${offer.originalPrice.toStringAsFixed(2)} \u{62C}.\u{645}',
                  ),
                ),
                Expanded(
                  child: _priceInfo(
                    '\u{633}\u{639}\u{631} \u{627}\u{644}\u{639}\u{631}\u{636}',
                    '${offer.offerPrice.toStringAsFixed(2)} \u{62C}.\u{645}',
                  ),
                ),
                Expanded(
                  child: _priceInfo(
                    '\u{646}\u{633}\u{628}\u{629} \u{627}\u{644}\u{62E}\u{635}\u{645}',
                    '${offer.discountPercentage.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoLine(
              Icons.date_range_outlined,
              '\u{645}\u{646} ${_formatDate(offer.startDate)} \u{625}\u{644}\u{649} '
              '${_formatDate(offer.endDate)}',
            ),
            const SizedBox(height: 5),
            _infoLine(
              offer.isActive
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              offer.isActive
                  ? '\u{646}\u{634}\u{637}'
                  : '\u{63A}\u{64A}\u{631} \u{646}\u{634}\u{637}',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _editOffer(offer),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('\u{62A}\u{639}\u{62F}\u{64A}\u{644}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _priceInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }

  Widget _errorText(String message) {
    return Text(message, style: const TextStyle(color: Colors.red));
  }

  Widget _emptyFieldMessage(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7AA7CF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  String _pricingLabel(ProductPricing pricing) {
    switch (pricing.pricingType) {
      case ProductPricingType.unit:
        if (pricing.quantity != null && pricing.unitName != null) {
          return '${pricing.quantity} ${pricing.unitName}';
        }
        return pricing.unitName ?? '';

      case ProductPricingType.weight:
        if (pricing.quantity != null && pricing.unitName != null) {
          return '${pricing.quantity} ${pricing.unitName}';
        }
        return '\u{628}\u{627}\u{644}\u{648}\u{632}\u{646}';

      case ProductPricingType.value:
        return '\u{62D}\u{633}\u{628} \u{627}\u{644}\u{642}\u{64A}\u{645}\u{629}';

      case ProductPricingType.fraction:
        if (pricing.fractionValue != null) {
          return '\u{643}\u{633}\u{631} ${pricing.fractionValue}';
        }
        return '\u{628}\u{627}\u{644}\u{643}\u{633}\u{631}';
    }
  }
}
