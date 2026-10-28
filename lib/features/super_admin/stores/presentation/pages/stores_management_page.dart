import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/admin_stores_repository.dart';
import '../../domain/entities/admin_store.dart';

import '../../../../../core/services/image_upload_service.dart';

class StoresManagementPage extends StatefulWidget {
  const StoresManagementPage({super.key});

  @override
  State<StoresManagementPage> createState() => _StoresManagementPageState();
}

class _StoresManagementPageState extends State<StoresManagementPage> {
  late final AdminStoresRepository _repository;

  bool _loading = true;

  List<AdminStore> _stores = [];
  List<Map<String, dynamic>> _owners = [];

  String _search = '';

  static const _categories = <String>[
    'supermarkets',
    'pharmacies',
    'vegetables',
    'bakeries',
    'poultry_frozen',
    'dairy',
    'butcher_meat',
    'snacks',
    'restaurants',
    'card_recharge',
    'cigarettes',
    'stationery',
    'cleaning_household',
    'herbs_spices',
  ];

  @override
  void initState() {
    super.initState();
    _repository = AdminStoresRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _repository.getStores(),
        _repository.getStoreOwners(),
      ]);

      if (!mounted) return;

      setState(() {
        _stores = results[0] as List<AdminStore>;
        _owners = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load stores: $error')));
    }
  }

  List<AdminStore> get _filteredStores {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _stores;
    }

    return _stores.where((store) {
      return store.name.toLowerCase().contains(query) ||
          store.category.toLowerCase().contains(query) ||
          store.phone.toLowerCase().contains(query) ||
          store.ownerName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openAddStore() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddStoreDialog(
        owners: _owners,
        categories: _categories,
        repository: _repository,
      ),
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _openEditStore(AdminStore store) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditStoreDialog(
        store: store,
        categories: _categories,
        repository: _repository,
      ),
    );

    if (updated == true && mounted) {
      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store updated successfully.')),
      );
    }
  }

  Future<void> _openTransferStoreOwnership(AdminStore store) async {
    final newOwnerId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _TransferStoreOwnershipDialog(store: store, owners: _owners),
    );

    if (newOwnerId == null || newOwnerId == store.ownerId || !mounted) {
      return;
    }

    Map<String, dynamic> newOwner = <String, dynamic>{};

    for (final owner in _owners) {
      if (owner['id']?.toString() == newOwnerId) {
        newOwner = owner;
        break;
      }
    }

    if (newOwner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected owner is no longer available.'),
        ),
      );
      return;
    }

    final newOwnerName = newOwner['full_name']?.toString() ?? 'Unknown Owner';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0D130D),
        title: const Text(
          'CONFIRM OWNERSHIP TRANSFER',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Transfer "${store.name}" from ${store.ownerName} to $newOwnerName?'
          '\n\nThe new owner will be able to manage this store. '
          'Products and historical orders will remain unchanged.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF147D45),
            ),
            child: const Text('TRANSFER OWNERSHIP'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _repository.transferStoreOwnership(
        storeId: store.id,
        newOwnerId: newOwnerId,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ownership of "${store.name}" transferred to $newOwnerName.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to transfer store ownership: $error')),
      );
    }
  }

  Future<void> _toggleStoreStatus(AdminStore store) async {
    final newStatus = !store.isActive;

    try {
      await _repository.updateStoreStatus(
        storeId: store.id,
        isActive: newStatus,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Store reopened successfully.'
                : 'Store closed successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update store status: $error')),
      );
    }
  }

  Future<void> _deleteStore(AdminStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D130D),
        title: const Text(
          'DELETE STORE',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${store.name}"? '
          'This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteStore(storeId: store.id);

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete store. It may have related products or orders. '
            '$error',
          ),
        ),
      );
    }
  }

  Future<void> _openEditStoreCategory(AdminStore store) async {
    final category = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditStoreCategoryDialog(store: store, categories: _categories),
    );

    if (category == null || category == store.category) {
      return;
    }

    try {
      await _repository.updateStoreCategory(
        storeId: store.id,
        category: category,
      );

      if (!mounted) return;

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store category updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update store category: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stores = _filteredStores;

    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D130D),
        foregroundColor: Colors.white,
        title: const Text('STORES'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStore,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('ADD STORE'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _search = value);
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search stores...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF101610),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: stores.isEmpty
                      ? const Center(
                          child: Text(
                            'NO STORES',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: stores.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final store = stores[index];

                            return Card(
                              color: const Color(0xFF0F150F),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF112516),
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    color: store.isActive
                                        ? const Color(0xFF00FF88)
                                        : Colors.white38,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        store.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: store.isActive
                                            ? const Color(0xFF123C28)
                                            : const Color(0xFF252525),
                                      ),
                                      child: Text(
                                        store.isActive ? 'ACTIVE' : 'CLOSED',
                                        style: TextStyle(
                                          color: store.isActive
                                              ? const Color(0xFF00FF88)
                                              : Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${store.category}  ${store.ownerName}\n'
                                    '${store.phone}  ${store.address}\n'
                                    'Products: ${store.productLimit}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Store actions',
                                  onSelected: (value) {
                                    if (value == 'edit_store') {
                                      _openEditStore(store);
                                    } else if (value == 'transfer_owner') {
                                      _openTransferStoreOwnership(store);
                                    } else if (value == 'edit_category') {
                                      _openEditStoreCategory(store);
                                    } else if (value == 'toggle_status') {
                                      _toggleStoreStatus(store);
                                    } else if (value == 'delete_store') {
                                      _deleteStore(store);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem<String>(
                                      value: 'edit_store',
                                      child: ListTile(
                                        leading: Icon(Icons.edit_outlined),
                                        title: Text('Edit Store'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'transfer_owner',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.person_add_alt_1_outlined,
                                        ),
                                        title: Text('Transfer Store Ownership'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'edit_category',
                                      child: ListTile(
                                        leading: Icon(Icons.category_outlined),
                                        title: Text('Edit Category'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'toggle_status',
                                      child: ListTile(
                                        leading: Icon(
                                          store.isActive
                                              ? Icons.store_outlined
                                              : Icons.storefront_outlined,
                                        ),
                                        title: Text(
                                          store.isActive
                                              ? 'Close Store'
                                              : 'Reopen Store',
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem<String>(
                                      value: 'delete_store',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        title: Text(
                                          'Delete Store',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _AddStoreDialog extends StatefulWidget {
  final List<Map<String, dynamic>> owners;
  final List<String> categories;
  final AdminStoresRepository repository;

  const _AddStoreDialog({
    required this.owners,
    required this.categories,
    required this.repository,
  });

  @override
  State<_AddStoreDialog> createState() => _AddStoreDialogState();
}

class _AddStoreDialogState extends State<_AddStoreDialog> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _logoUrl = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _logoImage;
  XFile? _coverImage;

  String? _ownerId;
  String? _category;
  bool _isActive = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    if (widget.owners.isNotEmpty) {
      _ownerId = widget.owners.first['id']?.toString();
    }

    if (widget.categories.isNotEmpty) {
      _category = widget.categories.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _description.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() => _logoImage = image);
  }

  Future<void> _pickCoverImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() => _coverImage = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ownerId == null) {
      _showMessage('Please select a store owner.');
      return;
    }

    if (_category == null) {
      _showMessage('Please select a category.');
      return;
    }

    setState(() => _saving = true);

    try {
      final store = await widget.repository.createStore(
        ownerId: _ownerId!,
        name: _name.text.trim(),
        category: _category!,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        description: _description.text.trim(),
        logoUrl: _logoUrl.text.trim(),
        isActive: _isActive,
      );

      if (_logoImage != null) {
        final imageUrl = await ImageUploadService().uploadStoreImage(
          file: _logoImage!,
          storeId: store.id,
          imageType: 'logo',
        );

        await widget.repository.updateStoreLogo(
          storeId: store.id,
          logoUrl: imageUrl,
        );
      }

      if (_coverImage != null) {
        final coverImageUrl = await ImageUploadService().uploadStoreImage(
          file: _coverImage!,
          storeId: store.id,
          imageType: 'cover',
        );

        await widget.repository.updateStoreCoverImage(
          storeId: store.id,
          coverImageUrl: coverImageUrl,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      _showMessage('Failed to create store: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D130D),
      title: const Text('ADD STORE', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _ownerId,
                  dropdownColor: const Color(0xFF101610),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('STORE OWNER'),
                  items: widget.owners.map((owner) {
                    final id = owner['id']?.toString();
                    final name = owner['full_name']?.toString() ?? 'Unnamed';
                    final email = owner['email']?.toString() ?? '';

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(email.isEmpty ? name : '$name    $email'),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: const Color(0xFF101610),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('CATEGORY'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _category = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _phone,
                  label: 'PHONE',
                  requiredField: true,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _address,
                  label: 'ADDRESS',
                  requiredField: true,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _description,
                  label: 'DESCRIPTION',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'STORE LOGO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _saving ? null : _pickLogoImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101610),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _logoImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white54,
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'SELECT LOGO IMAGE',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: FutureBuilder<Uint8List>(
                              future: _logoImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'STORE COVER IMAGE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _saving ? null : _pickCoverImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 170,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101610),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _coverImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.panorama_outlined,
                                color: Colors.white54,
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'SELECT COVER IMAGE',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: FutureBuilder<Uint8List>(
                              future: _coverImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _isActive = value);
                        },
                  title: const Text(
                    'ACTIVE IMMEDIATELY',
                    style: TextStyle(color: Colors.white),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CREATE STORE'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool requiredField = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
    );
  }
}

class _EditStoreDialog extends StatefulWidget {
  final AdminStore store;
  final List<String> categories;
  final AdminStoresRepository repository;

  const _EditStoreDialog({
    required this.store,
    required this.categories,
    required this.repository,
  });

  @override
  State<_EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<_EditStoreDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late final TextEditingController _logoUrl;
  late final TextEditingController _productLimit;

  late String _category;
  late bool _isActive;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _logoImage;
  XFile? _coverImage;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.store.name);
    _phone = TextEditingController(text: widget.store.phone);
    _address = TextEditingController(text: widget.store.address);
    _description = TextEditingController(text: widget.store.description);
    _logoUrl = TextEditingController(text: widget.store.logoUrl ?? '');
    _productLimit = TextEditingController(
      text: widget.store.productLimit.toString(),
    );

    _category = widget.categories.contains(widget.store.category)
        ? widget.store.category
        : widget.categories.first;

    _isActive = widget.store.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _description.dispose();
    _logoUrl.dispose();
    _productLimit.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() => _logoImage = image);
  }

  Future<void> _pickCoverImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() => _coverImage = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final productLimit = int.tryParse(_productLimit.text.trim());

    if (productLimit == null || productLimit <= 0) {
      _showMessage('Enter a valid product limit.');
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.repository.updateStore(
        storeId: widget.store.id,
        name: _name.text.trim(),
        category: _category,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        description: _description.text.trim(),
        logoUrl: _logoUrl.text.trim(),
        productLimit: productLimit,
        isActive: _isActive,
      );

      if (_logoImage != null) {
        final imageUrl = await ImageUploadService().uploadStoreImage(
          file: _logoImage!,
          storeId: widget.store.id,
          imageType: 'logo',
        );

        await widget.repository.updateStoreLogo(
          storeId: widget.store.id,
          logoUrl: imageUrl,
        );
      }

      if (_coverImage != null) {
        final coverImageUrl = await ImageUploadService().uploadStoreImage(
          file: _coverImage!,
          storeId: widget.store.id,
          imageType: 'cover',
        );

        await widget.repository.updateStoreCoverImage(
          storeId: widget.store.id,
          coverImageUrl: coverImageUrl,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      _showMessage('Failed to update store: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D130D),
      title: const Text('EDIT STORE', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  controller: _name,
                  label: 'STORE NAME',
                  requiredField: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: const Color(0xFF101610),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('CATEGORY'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _phone,
                  label: 'PHONE',
                  requiredField: true,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _address,
                  label: 'ADDRESS',
                  requiredField: true,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _description,
                  label: 'DESCRIPTION',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'STORE LOGO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _saving ? null : _pickLogoImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101610),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _logoImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: FutureBuilder<Uint8List>(
                              future: _logoImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          )
                        : (_logoUrl.text.trim().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    _logoUrl.text.trim(),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
                                      return const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                            size: 36,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'CURRENT IMAGE UNAVAILABLE',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: Colors.white54,
                                      size: 36,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'SELECT LOGO IMAGE',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                )),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _productLimit,
                  label: 'PRODUCT LIMIT',
                  requiredField: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');

                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid positive limit';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'STORE COVER IMAGE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _saving ? null : _pickCoverImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 170,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101610),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _coverImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: FutureBuilder<Uint8List>(
                              future: _coverImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          )
                        : (widget.store.coverImageUrl != null &&
                                  widget.store.coverImageUrl!.trim().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    widget.store.coverImageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
                                      return const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                            size: 36,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'CURRENT COVER UNAVAILABLE',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.panorama_outlined,
                                      color: Colors.white54,
                                      size: 36,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'SELECT COVER IMAGE',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                )),
                  ),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _isActive = value);
                        },
                  title: const Text(
                    'ACTIVE STORE',
                    style: TextStyle(color: Colors.white),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('SAVE CHANGES'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool requiredField = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator:
          validator ??
          (value) {
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }

            return null;
          },
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
    );
  }
}

class _EditStoreCategoryDialog extends StatefulWidget {
  final AdminStore store;
  final List<String> categories;

  const _EditStoreCategoryDialog({
    required this.store,
    required this.categories,
  });

  @override
  State<_EditStoreCategoryDialog> createState() =>
      _EditStoreCategoryDialogState();
}

class _EditStoreCategoryDialogState extends State<_EditStoreCategoryDialog> {
  late String _category;

  @override
  void initState() {
    super.initState();

    _category = widget.categories.contains(widget.store.category)
        ? widget.store.category
        : widget.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D130D),
      title: const Text('EDIT CATEGORY', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: DropdownButtonFormField<String>(
          initialValue: _category,
          dropdownColor: const Color(0xFF101610),
          style: const TextStyle(color: Colors.white),
          items: widget.categories
              .map(
                (category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
          decoration: const InputDecoration(
            labelText: 'Category',
            labelStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_category),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _TransferStoreOwnershipDialog extends StatefulWidget {
  final AdminStore store;
  final List<Map<String, dynamic>> owners;

  const _TransferStoreOwnershipDialog({
    required this.store,
    required this.owners,
  });

  @override
  State<_TransferStoreOwnershipDialog> createState() =>
      _TransferStoreOwnershipDialogState();
}

class _TransferStoreOwnershipDialogState
    extends State<_TransferStoreOwnershipDialog> {
  String? _selectedOwnerId;

  List<Map<String, dynamic>> get _eligibleOwners {
    return widget.owners
        .where(
          (owner) =>
              owner['id'] != null &&
              owner['id'].toString() != widget.store.ownerId,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final eligibleOwners = _eligibleOwners;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D130D),
      title: const Text(
        'TRANSFER STORE OWNERSHIP',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store: ${widget.store.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Current owner: ${widget.store.ownerName}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (eligibleOwners.isEmpty)
                const Text(
                  'No other active store-owner accounts are available.',
                  style: TextStyle(color: Colors.orangeAccent),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('transfer-owner-${widget.store.id}'),
                  initialValue:
                      eligibleOwners.any(
                        (owner) => owner['id']?.toString() == _selectedOwnerId,
                      )
                      ? _selectedOwnerId
                      : null,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF101610),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'NEW STORE OWNER',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                  items: eligibleOwners.map((owner) {
                    final id = owner['id'].toString();
                    final name =
                        owner['full_name']?.toString() ?? 'Unnamed Owner';
                    final email = owner['email']?.toString() ?? '';
                    final phone = owner['phone']?.toString() ?? '';
                    final contact = email.isNotEmpty ? email : phone;

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        contact.isEmpty ? name : '$name  $contact',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedOwnerId = value);
                  },
                ),
              const SizedBox(height: 12),
              const Text(
                'You will be asked to confirm this change before it is saved.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _selectedOwnerId == null || eligibleOwners.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedOwnerId),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF147D45),
          ),
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}
