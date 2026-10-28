import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OffersManagementPage extends StatefulWidget {
  const OffersManagementPage({super.key});

  @override
  State<OffersManagementPage> createState() => _OffersManagementPageState();
}

class _OffersManagementPageState extends State<OffersManagementPage> {
  final SupabaseClient _client = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _offerPriceController = TextEditingController();

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _pricing = [];
  List<Map<String, dynamic>> _offers = [];

  String? _selectedStoreId;
  String? _selectedProductId;
  String? _selectedPricingId;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  bool _loadingStores = true;
  bool _loadingProducts = false;
  bool _loadingPricing = false;
  bool _loadingOffers = true;
  bool _saving = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadOffers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _originalPriceController.dispose();
    _offerPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final response = await _client
          .from('stores')
          .select('id,name,is_active')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      setState(() {
        _stores = List<Map<String, dynamic>>.from(response);
        _loadingStores = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingStores = false;
      });

      _showMessage('  : $error', isError: true);
    }
  }

  Future<void> _loadProducts(String storeId) async {
    setState(() {
      _selectedProductId = null;
      _selectedPricingId = null;
      _products = [];
      _pricing = [];
      _loadingProducts = true;
      _loadingPricing = false;
    });

    try {
      final response = await _client
          .from('products')
          .select('id,name,price,is_active')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _loadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingProducts = false;
      });

      _showMessage('  : $error', isError: true);
    }
  }

  Future<void> _loadPricing(String productId) async {
    setState(() {
      _selectedPricingId = null;
      _pricing = [];
      _loadingPricing = true;
    });

    try {
      final response = await _client
          .from('product_pricing')
          .select(
            'id,product_id,pricing_type,unit_name,quantity,price,fraction_value,is_active',
          )
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;

      final rows = List<Map<String, dynamic>>.from(response);

      setState(() {
        _pricing = rows;
        _loadingPricing = false;
      });

      if (rows.length == 1) {
        _selectPricing(rows.first);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingPricing = false;
      });

      _showMessage('   : $error', isError: true);
    }
  }

  Future<void> _loadOffers() async {
    try {
      final response = await _client
          .from('offers')
          .select(
            'id,title,description,image_url,original_price,offer_price,start_date,end_date,is_active,approval_status,store_id,product_id,pricing_id',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _offers = List<Map<String, dynamic>>.from(response);
        _loadingOffers = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingOffers = false;
      });

      _showMessage('  : $error', isError: true);
    }
  }

  void _selectPricing(Map<String, dynamic> pricing) {
    setState(() {
      _selectedPricingId = pricing['id'] as String?;

      final price = pricing['price'];
      if (price != null) {
        _originalPriceController.text = price.toString();
      }
    });
  }

  String _pricingLabel(Map<String, dynamic> pricing) {
    final type = pricing['pricing_type']?.toString() ?? '';

    final unitName = pricing['unit_name']?.toString();
    final quantity = pricing['quantity'];
    final fractionValue = pricing['fraction_value'];

    switch (type) {
      case 'unit':
        if (unitName != null && unitName.isNotEmpty && quantity != null) {
          return '$quantity $unitName';
        }
        return '';

      case 'weight':
        if (unitName != null && unitName.isNotEmpty && quantity != null) {
          return '$quantity $unitName';
        }
        return '';

      case 'value':
        return ' ';

      case 'fraction':
        if (fractionValue != null) {
          return ': $fractionValue';
        }
        return '';

      default:
        return type;
    }
  }

  String _storeName(String storeId) {
    for (final store in _stores) {
      if (store['id'] == storeId) {
        return store['name']?.toString() ?? storeId;
      }
    }
    return storeId;
  }

  String _productName(String productId) {
    for (final product in _products) {
      if (product['id'] == productId) {
        return product['name']?.toString() ?? productId;
      }
    }
    return productId;
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStoreId == null ||
        _selectedProductId == null ||
        _selectedPricingId == null) {
      _showMessage('     .', isError: true);
      return;
    }

    final originalPrice = double.tryParse(_originalPriceController.text.trim());
    final offerPrice = double.tryParse(_offerPriceController.text.trim());

    if (originalPrice == null || originalPrice <= 0) {
      _showMessage('   .', isError: true);
      return;
    }

    if (offerPrice == null || offerPrice <= 0) {
      _showMessage('   .', isError: true);
      return;
    }

    if (offerPrice >= originalPrice) {
      _showMessage('        .', isError: true);
      return;
    }

    if (!_endDate.isAfter(_startDate)) {
      _showMessage(
        '        .',
        isError: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _client.from('offers').insert({
        'product_id': _selectedProductId,
        'store_id': _selectedStoreId,
        'pricing_id': _selectedPricingId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'original_price': originalPrice,
        'offer_price': offerPrice,
        'image_url': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'start_date': _startDate.toUtc().toIso8601String(),
        'end_date': _endDate.toUtc().toIso8601String(),
        'is_active': _isActive,
        'approval_status': 'approved',
      });

      if (!mounted) return;

      _showMessage('   .');

      _titleController.clear();
      _descriptionController.clear();
      _imageUrlController.clear();
      _originalPriceController.clear();
      _offerPriceController.clear();

      setState(() {
        _selectedStoreId = null;
        _selectedProductId = null;
        _selectedPricingId = null;
        _products = [];
        _pricing = [];
        _startDate = DateTime.now();
        _endDate = DateTime.now().add(const Duration(days: 7));
        _isActive = true;
      });

      await _loadOffers();
    } catch (error) {
      if (!mounted) return;

      _showMessage('  : $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selected == null || !mounted) return;

    setState(() {
      final value = DateTime(
        selected.year,
        selected.month,
        selected.day,
        isStart ? 0 : 23,
        isStart ? 0 : 59,
        isStart ? 0 : 59,
      );

      if (isStart) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B100D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101610),
        foregroundColor: Colors.white,
        title: const Text('OFFERS MANAGEMENT'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildCreateCard(),
            const SizedBox(height: 24),
            _buildOffersCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      color: const Color(0xFF101610),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CREATE OFFER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                initialValue: _selectedStoreId,
                dropdownColor: const Color(0xFF181F1A),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'STORE',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                items: _stores
                    .map(
                      (store) => DropdownMenuItem<String>(
                        value: store['id'] as String,
                        child: Text(store['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: _loadingStores
                    ? null
                    : (value) {
                        setState(() {
                          _selectedStoreId = value;
                          _selectedProductId = null;
                          _selectedPricingId = null;
                          _products = [];
                          _pricing = [];
                        });

                        if (value != null) {
                          _loadProducts(value);
                        }
                      },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedProductId,
                dropdownColor: const Color(0xFF181F1A),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PRODUCT',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                items: _products
                    .map(
                      (product) => DropdownMenuItem<String>(
                        value: product['id'] as String,
                        child: Text(product['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: _loadingProducts
                    ? null
                    : (value) {
                        setState(() {
                          _selectedProductId = value;
                          _selectedPricingId = null;
                          _pricing = [];
                        });

                        if (value != null) {
                          _loadPricing(value);
                        }
                      },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedPricingId,
                dropdownColor: const Color(0xFF181F1A),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PRICING',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                items: _pricing
                    .map(
                      (pricing) => DropdownMenuItem<String>(
                        value: pricing['id'] as String,
                        child: Text(
                          '${_pricingLabel(pricing)}  ${pricing['price']} EGP',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingPricing
                    ? null
                    : (value) {
                        final selected = _pricing.firstWhere(
                          (item) => item['id'] == value,
                        );

                        _selectPricing(selected);
                      },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'OFFER TITLE',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '  ';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'DESCRIPTION',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _imageUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'IMAGE URL',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'ORIGINAL PRICE',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        suffixText: 'EGP',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _offerPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'OFFER PRICE',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        suffixText: 'EGP',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: Text(
                        'START: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: Text(
                        'END: ${_endDate.day}/${_endDate.month}/${_endDate.year}',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'ACTIVE',
                  style: TextStyle(color: Colors.white),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveOffer,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_offer_outlined),
                  label: Text(_saving ? 'SAVING...' : 'CREATE OFFER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffersCard() {
    return Card(
      color: const Color(0xFF101610),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT OFFERS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            if (_loadingOffers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_offers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No offers yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ..._offers.map(_buildOfferRow),
          ],
        ),
      ),
    );
  }

  Future<void> _approveOffer(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();

    if (id == null || id.isEmpty) {
      _showMessage('  .', isError: true);
      return;
    }

    try {
      await _client
          .from('offers')
          .update({
            'approval_status': 'approved',
            'is_active': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;

      _showMessage('    .');
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;

      _showMessage('  : $error', isError: true);
    }
  }

  Future<void> _rejectOffer(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();

    if (id == null || id.isEmpty) {
      _showMessage('  .', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101610),
          title: const Text(
            'REJECT OFFER',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '    "${offer['title'] ?? ''}"',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('REJECT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _client
          .from('offers')
          .update({
            'approval_status': 'rejected',
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;

      _showMessage('  .');
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;

      _showMessage('  : $error', isError: true);
    }
  }

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();
    if (id == null || id.isEmpty) {
      _showMessage('  .', isError: true);
      return;
    }

    final titleController = TextEditingController(
      text: offer['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: offer['description']?.toString() ?? '',
    );
    final imageUrlController = TextEditingController(
      text: offer['image_url']?.toString() ?? '',
    );
    final originalPriceController = TextEditingController(
      text: ((offer['original_price'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    final offerPriceController = TextEditingController(
      text: ((offer['offer_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(
        2,
      ),
    );

    DateTime startDate =
        DateTime.tryParse(offer['start_date']?.toString() ?? '') ??
        DateTime.now();

    DateTime endDate =
        DateTime.tryParse(offer['end_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 7));

    bool isActive = offer['is_active'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101610),
              title: const Text(
                'EDIT OFFER',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'OFFER TITLE',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'DESCRIPTION',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'IMAGE URL',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: originalPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'ORIGINAL PRICE',
                                labelStyle: TextStyle(color: Colors.white70),
                                suffixText: 'EGP',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: offerPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'OFFER PRICE',
                                labelStyle: TextStyle(color: Colors.white70),
                                suffixText: 'EGP',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'START DATE',
                          style: TextStyle(color: Colors.white70),
                        ),
                        subtitle: Text(
                          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white70,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              startDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                startDate.hour,
                                startDate.minute,
                                startDate.second,
                              );
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'END DATE',
                          style: TextStyle(color: Colors.white70),
                        ),
                        subtitle: Text(
                          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white70,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              endDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                endDate.hour,
                                endDate.minute,
                                endDate.second,
                              );
                            });
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'ACTIVE',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    final originalPrice = double.tryParse(
                      originalPriceController.text.trim(),
                    );
                    final offerPrice = double.tryParse(
                      offerPriceController.text.trim(),
                    );

                    if (titleController.text.trim().isEmpty) {
                      _showMessage('  .', isError: true);
                      return;
                    }

                    if (originalPrice == null || originalPrice <= 0) {
                      _showMessage('   .', isError: true);
                      return;
                    }

                    if (offerPrice == null || offerPrice <= 0) {
                      _showMessage('   .', isError: true);
                      return;
                    }

                    if (offerPrice >= originalPrice) {
                      _showMessage(
                        '        .',
                        isError: true,
                      );
                      return;
                    }

                    if (!endDate.isAfter(startDate)) {
                      _showMessage(
                        '       .',
                        isError: true,
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('SAVE CHANGES'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      titleController.dispose();
      descriptionController.dispose();
      imageUrlController.dispose();
      originalPriceController.dispose();
      offerPriceController.dispose();
      return;
    }

    try {
      final originalPrice = double.parse(originalPriceController.text.trim());
      final offerPrice = double.parse(offerPriceController.text.trim());

      await _client
          .from('offers')
          .update({
            'title': titleController.text.trim(),
            'description': descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            'image_url': imageUrlController.text.trim().isEmpty
                ? null
                : imageUrlController.text.trim(),
            'original_price': originalPrice,
            'offer_price': offerPrice,
            'start_date': startDate.toUtc().toIso8601String(),
            'end_date': endDate.toUtc().toIso8601String(),
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;

      _showMessage('   .');
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;

      _showMessage('  : $error', isError: true);
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      imageUrlController.dispose();
      originalPriceController.dispose();
      offerPriceController.dispose();
    }
  }

  Future<void> _stopOffer(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();
    if (id == null || id.isEmpty) {
      _showMessage('  .', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101610),
          title: const Text(
            'STOP OFFER',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '    "${offer['title'] ?? ''}"',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('STOP OFFER'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _client
          .from('offers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;

      _showMessage('  .');
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;

      _showMessage('  : $error', isError: true);
    }
  }

  Widget _buildOfferRow(Map<String, dynamic> offer) {
    final original = (offer['original_price'] as num?)?.toDouble() ?? 0;
    final price = (offer['offer_price'] as num?)?.toDouble() ?? 0;
    final storeId = offer['store_id']?.toString() ?? '';
    final productId = offer['product_id']?.toString() ?? '';
    final isActive = offer['is_active'] == true;
    final approvalStatus =
        offer['approval_status']?.toString().toLowerCase() ?? 'pending';

    final discount = original > 0
        ? ((original - price) / original * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isActive ? Icons.local_offer_outlined : Icons.block_outlined,
                color: isActive ? Colors.white70 : Colors.white38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          offer['title']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: approvalStatus == 'approved'
                                ? Colors.green.withValues(alpha: 0.15)
                                : approvalStatus == 'rejected'
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            approvalStatus == 'approved'
                                ? 'APPROVED'
                                : approvalStatus == 'rejected'
                                    ? 'REJECTED'
                                    : 'PENDING REVIEW',
                            style: TextStyle(
                              color: approvalStatus == 'approved'
                                  ? Colors.greenAccent
                                  : approvalStatus == 'rejected'
                                      ? Colors.redAccent
                                      : Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isActive
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.white10,
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'STOPPED',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.lightBlueAccent
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_storeName(storeId)}  ${_productName(productId)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          );

          final pricing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${price.toStringAsFixed(2)} EGP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '-$discount%',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              if (approvalStatus == 'pending') ...[
                IconButton(
                  tooltip: 'Approve and publish',
                  onPressed: () => _approveOffer(offer),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  ),
                ),
                IconButton(
                  tooltip: 'Reject offer',
                  onPressed: () => _rejectOffer(offer),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                  ),
                ),
              ],
              IconButton(
                tooltip: 'Edit offer',
                onPressed: () => _editOffer(offer),
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
              ),
              if (isActive)
                IconButton(
                  tooltip: 'Stop offer',
                  onPressed: () => _stopOffer(offer),
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: pricing,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    pricing,
                  ],
                );
        },
      ),
    );
  }
}
