import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/services/image_upload_service.dart';

import '../../../../catalog/domain/entities/product.dart';
import '../../../../catalog/domain/entities/product_category.dart';
import '../../../../catalog/domain/entities/product_pricing.dart';
import '../../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../stores/data/repositories/admin_stores_repository.dart';
import '../../../stores/domain/entities/admin_store.dart';

class ProductsManagementPage extends ConsumerStatefulWidget {
  const ProductsManagementPage({super.key});

  @override
  ConsumerState<ProductsManagementPage> createState() =>
      _ProductsManagementPageState();
}

class _ProductsManagementPageState
    extends ConsumerState<ProductsManagementPage> {
  late final AdminStoresRepository _storesRepository;

  List<AdminStore> _stores = [];
  List<ProductCategory> _categories = [];
  List<Product> _products = [];

  String? _selectedStoreId;
  String _productSort = 'nameAsc';

  bool _loadingStores = true;
  bool _loadingCategories = false;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();

    _storesRepository = AdminStoresRepository(Supabase.instance.client);

    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loadingStores = true);

    try {
      final stores = await _storesRepository.getStores();

      if (!mounted) return;

      final activeStores = stores.where((store) => store.isActive).toList();

      setState(() {
        _stores = activeStores;
        _loadingStores = false;

        if (_selectedStoreId == null && activeStores.isNotEmpty) {
          _selectedStoreId = activeStores.first.id;
        }
      });

      if (_selectedStoreId != null) {
        await _loadCatalog();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingStores = false);

      _showMessage('Failed to load stores: $error');
    }
  }

  Future<void> _loadCatalog() async {
    final storeId = _selectedStoreId;

    if (storeId == null) {
      setState(() {
        _categories = [];
        _products = [];
      });
      return;
    }

    await Future.wait([_loadCategories(storeId), _loadProducts(storeId)]);
  }

  Future<void> _loadCategories(String storeId) async {
    setState(() => _loadingCategories = true);

    try {
      final repository = ref.read(productCategoryRepositoryProvider);

      final categories = await repository.getActiveCategoriesByStore(storeId);

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingCategories = false);

      _showMessage('Failed to load categories: $error');
    }
  }

  Future<void> _loadProducts([String? storeIdOverride]) async {
    final storeId = storeIdOverride ?? _selectedStoreId;

    if (storeId == null) {
      if (!mounted) return;

      setState(() {
        _products = [];
        _loadingProducts = false;
      });
      return;
    }

    setState(() {
      _products = [];
      _loadingProducts = true;
    });

    try {
      final repository = ref.read(productRepositoryProvider);
      final allProducts = await repository.getProductsByStoreForAdmin(storeId);

      if (!mounted || _selectedStoreId != storeId) return;

      final products = allProducts
          .where((product) => product.storeId == storeId)
          .toList();

      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (error) {
      if (!mounted || _selectedStoreId != storeId) return;

      setState(() {
        _products = [];
        _loadingProducts = false;
      });

      _showMessage('Failed to load products: $error');
    }
  }
  Future<void> _openAddProduct() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(initialStoreId: _selectedStoreId),
      ),
    );

    if (created == true && mounted) {
      await _loadCatalog();
    }
  }

  Future<void> _toggleProductAvailability(Product product) async {
    final newAvailability = !product.isAvailable;

    try {
      await Supabase.instance.client
          .from('products')
          .update({'is_available': newAvailability})
          .eq('id', product.id);

      if (!mounted) return;

      _showMessage(
        newAvailability
            ? 'Product is available again.'
            : 'Product marked as out of stock.',
      );

      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to update product availability: $error');
    }
  }
  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101610),
          title: const Text(
            'DELETE PRODUCT',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '    "${product.name}"\n\n'
            '   .',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(productRepositoryProvider);

      await repository.deleteProduct(product.id);

      if (!mounted) return;

      _showMessage('Product deleted successfully.');

      await _loadProducts();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      final isForeignKeyConflict =
          error.code == '23503' ||
          error.message.toLowerCase().contains('foreign key');

      if (!isForeignKeyConflict) {
        _showMessage('Failed to delete product: $error');
        return;
      }

      final deactivateConfirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Product is linked to existing records'),
          content: Text(
            '"${product.name}" cannot be permanently deleted because '
            'other records reference it. Deactivate it so customers '
            'can no longer buy it, while preserving historical records?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('KEEP PRODUCT'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('DEACTIVATE PRODUCT'),
            ),
          ],
        ),
      );

      if (deactivateConfirmed != true || !mounted) return;

      try {
        await Supabase.instance.client
            .from('products')
            .update({'is_active': false})
            .eq('id', product.id);

        if (!mounted) return;

        _showMessage('Product deactivated. Historical records were preserved.');

        await _loadProducts();
      } catch (deactivationError) {
        if (!mounted) return;

        _showMessage('Failed to deactivate product: $deactivationError');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to delete product: $error');
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(
          initialStoreId: product.storeId,
          initialProduct: product,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadCatalog();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddCategory() async {
    final storeId = _selectedStoreId;

    if (storeId == null) {
      _showMessage('Please select a store first.');
      return;
    }

    final result = await _showCategoryEditor();

    if (result == null || !mounted) return;

    try {
      final repository = ref.read(productCategoryRepositoryProvider);
      final selectedImage = result['selectedImage'] as XFile?;
      String? imageUrl = result['imageUrl'] as String?;

      if (selectedImage != null) {
        imageUrl = await ImageUploadService().uploadStoreImage(
          file: selectedImage,
          storeId: storeId,
          imageType: 'category-${DateTime.now().microsecondsSinceEpoch}',
        );
      }

      await repository.createCategory(
        storeId: storeId,
        name: result['name'] as String,
        description: result['description'] as String?,
        imageUrl: imageUrl,
        isActive: result['isActive'] as bool,
        sortOrder: _categories.length,
      );

      await _loadCategories(storeId);

      if (!mounted) return;

      _showMessage('Category created successfully.');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to create category: $error');
    }
  }

  Future<void> _openEditCategory(ProductCategory category) async {
    final result = await _showCategoryEditor(category: category);

    if (result == null || !mounted) return;

    try {
      final repository = ref.read(productCategoryRepositoryProvider);
      final selectedImage = result['selectedImage'] as XFile?;
      String? imageUrl = result['imageUrl'] as String?;

      if (selectedImage != null) {
        imageUrl = await ImageUploadService().uploadStoreImage(
          file: selectedImage,
          storeId: category.storeId,
          imageType:
              'category-${category.id}-${DateTime.now().microsecondsSinceEpoch}',
        );
      }

      await repository.updateCategory(
        categoryId: category.id,
        name: result['name'] as String,
        description: result['description'] as String?,
        imageUrl: imageUrl,
        isActive: result['isActive'] as bool,
        sortOrder: category.sortOrder,
      );

      final storeId = _selectedStoreId;

      if (storeId != null) {
        await _loadCategories(storeId);
      }

      if (!mounted) return;

      _showMessage('Category updated successfully.');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to update category: $error');
    }
  }

  Future<Map<String, dynamic>?> _showCategoryEditor({
    ProductCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');

    final descriptionController = TextEditingController(
      text: category?.description ?? '',
    );

    final imageUrlController = TextEditingController(
      text: category?.imageUrl ?? '',
    );

    XFile? selectedCategoryImage;
    Uint8List? selectedCategoryImageBytes;

    bool isActive = category?.isActive ?? true;

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF101610),
                title: Text(
                  category == null ? 'ADD CATEGORY' : 'EDIT CATEGORY',
                  style: const TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'CATEGORY NAME',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 150,
                            child: selectedCategoryImageBytes != null
                                ? Image.memory(
                                    selectedCategoryImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : imageUrlController.text.trim().isNotEmpty
                                ? Image.network(
                                    imageUrlController.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF263329),
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white70,
                                          size: 42,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFF263329),
                                    child: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: Colors.white70,
                                      size: 42,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );

                                if (picked == null) {
                                  return;
                                }

                                final bytes = await picked.readAsBytes();

                                if (!dialogContext.mounted) {
                                  return;
                                }

                                setDialogState(() {
                                  selectedCategoryImage = picked;
                                  selectedCategoryImageBytes = bytes;
                                  imageUrlController.clear();
                                });
                              } catch (error) {
                                if (!dialogContext.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to select image: $error',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              selectedCategoryImage != null ||
                                      (category?.imageUrl?.trim().isNotEmpty ??
                                          false)
                                  ? 'CHANGE CATEGORY IMAGE'
                                  : 'ADD CATEGORY IMAGE',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: imageUrlController,
                          onChanged: (_) => setDialogState(() {}),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'IMAGE URL (OPTIONAL)',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: isActive,
                          onChanged: (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                          title: const Text(
                            'ACTIVE',
                            style: TextStyle(color: Colors.white),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('CANCEL'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Category name is required.'),
                          ),
                        );
                        return;
                      }

                      final description =
                          descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim();

                      final imageUrl = imageUrlController.text.trim().isEmpty
                          ? null
                          : imageUrlController.text.trim();

                      Navigator.of(dialogContext).pop({
                        'name': name,
                        'description': description,
                        'imageUrl': imageUrl,
                        'selectedImage': selectedCategoryImage,
                        'isActive': isActive,
                      });
                    },
                    child: Text(
                      category == null ? 'SAVE CATEGORY' : 'UPDATE CATEGORY',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        nameController.dispose();
        descriptionController.dispose();
        imageUrlController.dispose();
      });
    }
  }

  Widget _sectionHeader({
    required String title,
    required String actionLabel,
    required VoidCallback? onAction,
    required IconData icon,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: Icon(icon, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No active categories for this store.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final category = _categories[index];

        return Card(
          color: const Color(0xFF101610),
          child: ListTile(
            leading: const Icon(Icons.category_outlined, color: Colors.white70),
            title: Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              category.isActive ? 'ACTIVE' : 'INACTIVE',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: OutlinedButton(
              onPressed: () => _openEditCategory(category),
              child: const Text('EDIT'),
            ),
          ),
        );
      },
    );
  }

  List<Product> _sortProducts(List<Product> products) {
    final sorted = List<Product>.of(products);

    String normalizedName(String name) {
      return name
          .toLowerCase()
          .replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627')
          .replaceAll('\u0649', '\u064a');
    }

    sorted.sort((a, b) {
      switch (_productSort) {
        case 'nameDesc':
          return normalizedName(b.name).compareTo(normalizedName(a.name));
        case 'priceDesc':
          return b.price.compareTo(a.price);
        case 'priceAsc':
          return a.price.compareTo(b.price);
        case 'nameAsc':
        default:
          return normalizedName(a.name).compareTo(normalizedName(b.name));
      }
    });

    return sorted;
  }

  Widget _buildProductList() {
    final selectedStoreId = _selectedStoreId;
    final visibleProducts = selectedStoreId == null
        ? <Product>[]
        : _products
            .where((product) => product.storeId == selectedStoreId)
            .toList();
    final sortedProducts = _sortProducts(visibleProducts);

    if (_loadingProducts) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (visibleProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No products available.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    String storeNameFor(String storeId) {
      for (final store in _stores) {
        if (store.id == storeId) {
          return store.name;
        }
      }
      return 'Unknown store';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 340,
            child: DropdownButtonFormField<String>(
              initialValue: _productSort,
              isExpanded: true,
              dropdownColor: const Color(0xFF101610),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '\u062a\u0631\u062a\u064a\u0628 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'nameAsc',
                  child: Text('\u0627\u0644\u0627\u0633\u0645: \u0645\u0646 \u0623 \u0625\u0644\u0649 \u064a'),
                ),
                DropdownMenuItem(
                  value: 'nameDesc',
                  child: Text('\u0627\u0644\u0627\u0633\u0645: \u0645\u0646 \u064a \u0625\u0644\u0649 \u0623'),
                ),
                DropdownMenuItem(
                  value: 'priceDesc',
                  child: Text('\u0627\u0644\u0633\u0639\u0631: \u0645\u0646 \u0627\u0644\u0623\u0639\u0644\u0649 \u0625\u0644\u0649 \u0627\u0644\u0623\u0642\u0644'),
                ),
                DropdownMenuItem(
                  value: 'priceAsc',
                  child: Text('\u0627\u0644\u0633\u0639\u0631: \u0645\u0646 \u0627\u0644\u0623\u0642\u0644 \u0625\u0644\u0649 \u0627\u0644\u0623\u0639\u0644\u0649'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _productSort = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final product = sortedProducts[index];
        final storeName = storeNameFor(product.storeId);

        return Card(
          color: const Color(0xFF101610),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child:
                    product.imageUrl != null &&
                        product.imageUrl!.trim().isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white70,
                      ),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'STORE: $storeName    '
                'PRICE: ${product.price.toStringAsFixed(2)} EGP    '
                'METHOD: ${product.sellingMethod.name.toUpperCase()}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: product.isAvailable ? 'Mark out of stock' : 'Mark available',
                  onPressed: () => _toggleProductAvailability(product),
                  icon: Icon(
                    product.isAvailable
                        ? Icons.inventory_2_outlined
                        : Icons.check_circle_outline,
                    color: product.isAvailable
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit product',
                  onPressed: () => _openEditProduct(product),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Delete product',
                  onPressed: () => _deleteProduct(product),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D130D),
        foregroundColor: Colors.white,
        title: const Text('CATALOG MANAGEMENT'),
      ),
      body: _loadingStores
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
          ? const Center(
              child: Text(
                'No active stores available.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedStoreId,
                  dropdownColor: const Color(0xFF101610),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'STORE',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                  items: _stores
                      .map(
                        (store) => DropdownMenuItem<String>(
                          value: store.id,
                          child: Text(store.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      _selectedStoreId = value;
                      _products = [];
                      _loadingProducts = true;
                    });

                    await _loadCatalog();
                  },
                ),
                const SizedBox(height: 28),

                _sectionHeader(
                  title: 'CATEGORY',
                  actionLabel: 'ADD CATEGORY',
                  onAction: _openAddCategory,
                  icon: Icons.add,
                ),
                const SizedBox(height: 12),
                _buildCategoryList(),

                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 28),

                _sectionHeader(
                  title: 'PRODUCT',
                  actionLabel: 'ADD PRODUCT',
                  onAction: _selectedStoreId == null ? null : _openAddProduct,
                  icon: Icons.add_box_outlined,
                ),
                const SizedBox(height: 12),
                _buildProductList(),
              ],
            ),
    );
  }
}

class AddProductPage extends ConsumerStatefulWidget {
  final String? initialStoreId;
  final Product? initialProduct;

  const AddProductPage({super.key, this.initialStoreId, this.initialProduct});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  late final AdminStoresRepository _storesRepository;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<XFile> _selectedImages = [];
  List<String> _existingImageUrls = [];
  final _priceController = TextEditingController();
  final _sellingValueController = TextEditingController(text: '1');

  List<AdminStore> _stores = [];
  List<ProductCategory> _categories = [];

  String? _selectedStoreId;
  String? _selectedCategoryId;

  ProductSellingMethod _sellingMethod = ProductSellingMethod.unit;

  bool _isActive = true;
  bool _loadingStores = true;
  bool _loadingCategories = false;
  bool _saving = false;

  List<ProductPricingDraft> _pricing = [];

  bool get _isEditMode => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();

    _storesRepository = AdminStoresRepository(Supabase.instance.client);

    _pricing = [
      const ProductPricingDraft(
        pricingType: ProductPricingType.unit,
        unitName: 'piece',
        quantity: 1,
        price: 1,
        sortOrder: 0,
      ),
    ];

    final product = widget.initialProduct;

    _selectedStoreId = product?.storeId ?? widget.initialStoreId;

    if (product != null) {
      _nameController.text = product.name;
      _descriptionController.text = product.description ?? '';
      _priceController.text = product.price.toString();
      _sellingValueController.text = product.sellingValue.toString();
      _sellingMethod = product.sellingMethod;
      _isActive = product.isActive;
      _selectedCategoryId = product.categoryId;
    }

    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _storesRepository.getStores();

      if (!mounted) return;

      final activeStores = stores.where((store) => store.isActive).toList();

      setState(() {
        _stores = activeStores;
        _loadingStores = false;

        if (_selectedStoreId == null && activeStores.isNotEmpty) {
          _selectedStoreId = activeStores.first.id;
        }
      });

      if (_selectedStoreId != null) {
        await _loadCategories(_selectedStoreId!);
      }

      if (widget.initialProduct != null) {
        await _loadExistingPricing(widget.initialProduct!.id);
        await _loadExistingProductImages(widget.initialProduct!.id);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingStores = false);

      _showMessage('Failed to load stores: $error');
    }
  }

  Future<void> _loadCategories(String storeId) async {
    setState(() {
      _loadingCategories = true;

      if (!_isEditMode) {
        _selectedCategoryId = null;
      }
    });

    try {
      final repository = ref.read(productCategoryRepositoryProvider);

      final categories = (await repository.getActiveCategoriesByStore(
        storeId,
      )).toList();

      if (!mounted) return;

      final savedCategoryId = _selectedCategoryId;

      if (_isEditMode &&
          savedCategoryId != null &&
          !categories.any((category) => category.id == savedCategoryId)) {
        try {
          final savedCategory = await repository.getById(savedCategoryId);

          if (!mounted) return;

          if (savedCategory != null) {
            categories.add(savedCategory);
          }
        } catch (error) {
          debugPrint('PRODUCT EDIT: Could not load saved category: $error');
        }
      }

      setState(() {
        _categories = categories;
        _loadingCategories = false;

        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingCategories = false);

      _showMessage('Failed to load categories: $error');
    }
  }

  Future<void> _loadExistingPricing(String productId) async {
    try {
      final repository = ref.read(productPricingRepositoryProvider);

      final pricing = await repository.getActivePricingByProduct(productId);

      if (!mounted) return;

      if (pricing.isEmpty) {
        return;
      }

      setState(() {
        _pricing = pricing
            .map(
              (item) => ProductPricingDraft(
                pricingType: item.pricingType,
                unitName: item.unitName,
                quantity: item.quantity,
                price: item.price,
                fractionValue: item.fractionValue,
                isActive: item.isActive,
                sortOrder: item.sortOrder,
              ),
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to load pricing options: $error');
    }
  }

  void _addPricing() {
    setState(() {
      _pricing = [
        ..._pricing,
        ProductPricingDraft(
          pricingType: ProductPricingType.unit,
          unitName: 'piece',
          quantity: 1,
          price: 1,
          sortOrder: _pricing.length,
        ),
      ];
    });
  }

  void _removePricing(int index) {
    if (_pricing.length == 1) {
      return;
    }

    setState(() {
      final copy = [..._pricing];
      copy.removeAt(index);

      _pricing = [
        for (var i = 0; i < copy.length; i++)
          ProductPricingDraft(
            pricingType: copy[i].pricingType,
            unitName: copy[i].unitName,
            quantity: copy[i].quantity,
            price: copy[i].price,
            fractionValue: copy[i].fractionValue,
            isActive: copy[i].isActive,
            sortOrder: i,
          ),
      ];
    });
  }

  Future<void> _loadExistingProductImages(String productId) async {
    try {
      final files = await Supabase.instance.client.storage
          .from('product-images')
          .list(path: productId);

      final urls = files
          .where((file) => file.name.isNotEmpty)
          .map(
            (file) => Supabase.instance.client.storage
                .from('product-images')
                .getPublicUrl('$productId/${file.name}'),
          )
          .toList();

      urls.sort();

      if (!mounted) return;

      setState(() {
        _existingImageUrls = urls.take(3).toList();
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to load product photos: $error');
    }
  }

  Future<void> _deleteExistingProductImage(int index) async {
    if (index < 0 || index >= _existingImageUrls.length) {
      return;
    }

    final productId = widget.initialProduct?.id;
    if (productId == null) {
      return;
    }

    try {
      final storage = Supabase.instance.client.storage.from('product-images');

      final files = await storage.list(path: productId);

      final imageFiles =
          files
              .where((file) => RegExp(r'^[1-3]\.[^.]+$').hasMatch(file.name))
              .toList()
            ..sort((a, b) {
              final aNumber = int.parse(a.name.split('.').first);
              final bNumber = int.parse(b.name.split('.').first);
              return aNumber.compareTo(bNumber);
            });

      if (index >= imageFiles.length) {
        throw Exception('Product image no longer exists.');
      }

      final remainingFiles = <Map<String, dynamic>>[];

      for (var i = 0; i < imageFiles.length; i++) {
        if (i == index) {
          continue;
        }

        final file = imageFiles[i];
        final extension = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';

        final Uint8List bytes = await storage.download(
          '$productId/${file.name}',
        );

        remainingFiles.add({'bytes': bytes, 'extension': extension});
      }

      await storage.remove([
        for (final file in imageFiles) '$productId/${file.name}',
      ]);

      final reorderedUrls = <String>[];

      for (var i = 0; i < remainingFiles.length; i++) {
        final extension = remainingFiles[i]['extension'] as String;
        final bytes = remainingFiles[i]['bytes'] as List<int>;
        final targetPath = '$productId/${i + 1}.$extension';

        final contentType = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'application/octet-stream',
        };

        await storage.uploadBinary(
          targetPath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

        reorderedUrls.add(storage.getPublicUrl(targetPath));
      }

      await Supabase.instance.client
          .from('products')
          .update({
            'image_url': reorderedUrls.isEmpty ? null : reorderedUrls.first,
          })
          .eq('id', productId);

      if (!mounted) return;

      setState(() {
        _existingImageUrls = reorderedUrls;
      });

      _showMessage('Product photo deleted.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to delete product photo: $error');
    }
  }

  Future<void> _pickProductImages() async {
    final remaining = 3 - _existingImageUrls.length - _selectedImages.length;

    if (remaining <= 0) {
      _showMessage('You can upload up to 3 product photos.');
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 85);

      if (images.isEmpty) return;

      setState(() {
        _selectedImages = [..._selectedImages, ...images.take(remaining)];
      });

      if (images.length > remaining && mounted) {
        _showMessage('Only 3 product photos are allowed.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to select images: $error');
    }
  }

  Future<List<String>> _uploadProductImages(String productId) async {
    if (_selectedImages.isEmpty) {
      return [];
    }

    final storage = Supabase.instance.client.storage.from('product-images');

    final files = await storage.list(path: productId);

    final usedSlots = <int>{};

    for (final file in files) {
      final match = RegExp(r'^([1-3])\.[^.]+$').firstMatch(file.name);

      if (match != null) {
        usedSlots.add(int.parse(match.group(1)!));
      }
    }

    final uploadedUrls = <String>[];

    for (var index = 0; index < _selectedImages.length; index++) {
      int? slot;

      for (var candidate = 1; candidate <= 3; candidate++) {
        if (!usedSlots.contains(candidate)) {
          slot = candidate;
          break;
        }
      }

      if (slot == null) {
        throw Exception('A product can have up to 3 photos.');
      }

      usedSlots.add(slot);

      final image = _selectedImages[index];
      final extension = image.path.split('.').last.toLowerCase();

      final safeExtension = extension.isEmpty || extension.length > 5
          ? 'jpg'
          : extension;

      final filePath = '$productId/$slot.$safeExtension';

      try {
        final Uint8List bytes = await image.readAsBytes();

        final contentType = switch (safeExtension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => image.mimeType ?? 'application/octet-stream',
        };

        await storage.uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

        uploadedUrls.add(storage.getPublicUrl(filePath));
      } catch (error) {
        throw Exception('Failed to upload product image ${index + 1}: $error');
      }
    }

    return uploadedUrls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStoreId == null) {
      _showMessage('Please select a store.');
      return;
    }

    if (_selectedCategoryId == null) {
      _showMessage('Please select a category.');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    final sellingValue = double.tryParse(_sellingValueController.text.trim());

    if (price == null || price <= 0) {
      _showMessage('Enter a valid base price.');
      return;
    }

    if (sellingValue == null || sellingValue <= 0) {
      _showMessage('Enter a valid selling value.');
      return;
    }

    if (_pricing.isEmpty) {
      _showMessage('At least one pricing option is required.');
      return;
    }

    for (final option in _pricing) {
      if (option.price <= 0) {
        _showMessage('Each pricing option must have a valid price.');
        return;
      }

      if (option.pricingType == ProductPricingType.fraction) {
        final fraction = option.fractionValue;

        if (fraction == null || fraction <= 0 || fraction > 1) {
          _showMessage(
            'Fraction value must be greater than 0 and less than or equal to 1.',
          );
          return;
        }
      }

      if (option.pricingType == ProductPricingType.unit ||
          option.pricingType == ProductPricingType.weight) {
        if (option.quantity == null || option.quantity! <= 0) {
          _showMessage(
            'Quantity must be greater than zero for unit/weight pricing.',
          );
          return;
        }

        if (option.unitName == null || option.unitName!.trim().isEmpty) {
          _showMessage('Unit name is required for unit/weight pricing.');
          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(productRepositoryProvider);

      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      if (widget.initialProduct == null) {
        final productId = await repository.createProduct(
          storeId: _selectedStoreId!,
          categoryId: _selectedCategoryId,
          name: _nameController.text.trim(),
          description: description,
          imageUrl: null,
          price: price,
          sellingMethod: _sellingMethod,
          sellingValue: sellingValue,
          isActive: _isActive,
          pricing: _pricing,
        );

        final uploadedUrls = await _uploadProductImages(productId);

        if (uploadedUrls.isNotEmpty) {
          await Supabase.instance.client
              .from('products')
              .update({'image_url': uploadedUrls.first})
              .eq('id', productId);
        }
      } else {
        await repository.updateProduct(
          productId: widget.initialProduct!.id,
          categoryId: _selectedCategoryId!,
          name: _nameController.text.trim(),
          description: description,
          price: price,
          sellingMethod: _sellingMethod,
          sellingValue: sellingValue,
          isActive: _isActive,
          pricing: _pricing,
        );

        if (_selectedImages.isNotEmpty) {
          final availableSlots = 3 - _existingImageUrls.length;

          if (_selectedImages.length > availableSlots) {
            throw Exception(
              'A product can have up to 3 photos. '
              'Remove an existing photo before adding more.',
            );
          }

          final uploadedUrls = await _uploadProductImages(
            widget.initialProduct!.id,
          );

          if (_existingImageUrls.isEmpty && uploadedUrls.isNotEmpty) {
            await Supabase.instance.client
                .from('products')
                .update({'image_url': uploadedUrls.first})
                .eq('id', widget.initialProduct!.id);
          }
        }
      }

      if (!mounted) return;

      _showMessage(
        widget.initialProduct == null
            ? 'Product created successfully.'
            : 'Product updated successfully.',
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      _showMessage(
        widget.initialProduct == null
            ? 'Failed to create product: $error'
            : 'Failed to update product: $error',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _sellingValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStores) {
      return const Scaffold(
        backgroundColor: Color(0xFF080C08),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080C08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D130D),
        foregroundColor: Colors.white,
        title: Text(_isEditMode ? 'EDIT PRODUCT' : 'ADD PRODUCT'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _sectionTitle('PRODUCT DETAILS'),
            const SizedBox(height: 12),

            _textField(
              controller: _nameController,
              label: 'PRODUCT NAME',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 12),

            _textField(
              controller: _descriptionController,
              label: 'DESCRIPTION',
              maxLines: 3,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey(
                'product-store-$_selectedStoreId-${_stores.length}',
              ),
              initialValue: _stores.any((store) => store.id == _selectedStoreId)
                  ? _selectedStoreId
                  : null,
              dropdownColor: const Color(0xFF101610),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('STORE'),
              items: _stores
                  .map(
                    (store) => DropdownMenuItem<String>(
                      value: store.id,
                      child: Text(store.name),
                    ),
                  )
                  .toList(),
              onChanged: _isEditMode
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedStoreId = value;
                        _selectedCategoryId = null;
                      });

                      _loadCategories(value);
                    },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey(
                'product-category-$_selectedStoreId-${_categories.length}',
              ),
              initialValue:
                  _categories.any(
                    (category) => category.id == _selectedCategoryId,
                  )
                  ? _selectedCategoryId
                  : null,
              dropdownColor: const Color(0xFF101610),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('CATEGORY'),
              hint: Text(
                _loadingCategories
                    ? 'Loading categories...'
                    : 'No category configured',
                style: const TextStyle(color: Colors.white54),
              ),
              items: _categories
                  .map<DropdownMenuItem<String>>(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: _categories.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
            ),

            const SizedBox(height: 24),

            _sectionTitle('SELLING'),
            const SizedBox(height: 12),

            DropdownButtonFormField<ProductSellingMethod>(
              initialValue: _sellingMethod,
              dropdownColor: const Color(0xFF101610),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('SELLING METHOD'),
              items: ProductSellingMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _sellingMethod = value;
                });
              },
            ),

            const SizedBox(height: 12),

            _numberField(controller: _priceController, label: 'BASE PRICE'),

            const SizedBox(height: 12),

            _numberField(
              controller: _sellingValueController,
              label: 'SELLING VALUE',
            ),

            const SizedBox(height: 12),
            _sectionTitle('PRODUCT PHOTOS'),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _selectedImages.length >= 3
                  ? null
                  : _pickProductImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _selectedImages.isEmpty
                    ? 'ADD PHOTOS'
                    : 'ADD MORE PHOTOS (${_selectedImages.length}/3)',
              ),
            ),

            const SizedBox(height: 12),

            if (_existingImageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_existingImageUrls.length, (index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _existingImageUrls[index],
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 110,
                              height: 110,
                              color: Colors.white10,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _deleteExistingProductImage(index),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            if (_selectedImages.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_selectedImages.length, (index) {
                  final image = _selectedImages[index];

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FutureBuilder<Uint8List>(
                          future: image.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const SizedBox(
                                width: 120,
                                height: 120,
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const SizedBox(
                                width: 120,
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            return Image.memory(
                              snapshot.data!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),

            const SizedBox(height: 24),

            _sectionTitle('PRICING OPTIONS'),
            const SizedBox(height: 12),

            ..._pricing.asMap().entries.map(
              (entry) => _PricingCard(
                index: entry.key,
                pricing: entry.value,
                onChanged: (updated) {
                  setState(() {
                    final copy = [..._pricing];
                    copy[entry.key] = updated;
                    _pricing = copy;
                  });
                },
                onRemove: () => _removePricing(entry.key),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _addPricing,
              icon: const Icon(Icons.add),
              label: const Text('ADD PRICING OPTION'),
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              value: _isActive,
              onChanged: (value) {
                setState(() => _isActive = value);
              },
              title: const Text(
                'ACTIVE PRODUCT',
                style: TextStyle(color: Colors.white),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditMode ? 'UPDATE PRODUCT' : 'CREATE PRODUCT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _decoration(label),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
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

class _PricingCard extends StatelessWidget {
  final int index;
  final ProductPricingDraft pricing;
  final ValueChanged<ProductPricingDraft> onChanged;
  final VoidCallback onRemove;

  const _PricingCard({
    required this.index,
    required this.pricing,
    required this.onChanged,
    required this.onRemove,
  });

  ProductPricingDraft _copy({
    ProductPricingType? pricingType,
    String? unitName,
    bool clearUnitName = false,
    double? quantity,
    bool clearQuantity = false,
    double? price,
    double? fractionValue,
    bool clearFractionValue = false,
  }) {
    return ProductPricingDraft(
      pricingType: pricingType ?? pricing.pricingType,
      unitName: clearUnitName ? null : (unitName ?? pricing.unitName),
      quantity: clearQuantity ? null : (quantity ?? pricing.quantity),
      price: price ?? pricing.price,
      fractionValue: clearFractionValue
          ? null
          : (fractionValue ?? pricing.fractionValue),
      isActive: pricing.isActive,
      sortOrder: index,
    );
  }

  void _changeType(ProductPricingType type) {
    switch (type) {
      case ProductPricingType.unit:
        onChanged(
          ProductPricingDraft(
            pricingType: type,
            unitName: 'piece',
            quantity: 1,
            price: pricing.price,
            fractionValue: null,
            isActive: pricing.isActive,
            sortOrder: index,
          ),
        );
        break;

      case ProductPricingType.weight:
        onChanged(
          ProductPricingDraft(
            pricingType: type,
            unitName: 'kg',
            quantity: 1,
            price: pricing.price,
            fractionValue: null,
            isActive: pricing.isActive,
            sortOrder: index,
          ),
        );
        break;

      case ProductPricingType.value:
        onChanged(
          ProductPricingDraft(
            pricingType: type,
            unitName: null,
            quantity: null,
            price: pricing.price,
            fractionValue: null,
            isActive: pricing.isActive,
            sortOrder: index,
          ),
        );
        break;

      case ProductPricingType.fraction:
        onChanged(
          ProductPricingDraft(
            pricingType: type,
            unitName: null,
            quantity: null,
            price: pricing.price,
            fractionValue: 0.5,
            isActive: pricing.isActive,
            sortOrder: index,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnit = pricing.pricingType == ProductPricingType.unit;
    final isWeight = pricing.pricingType == ProductPricingType.weight;
    final isValue = pricing.pricingType == ProductPricingType.value;
    final isFraction = pricing.pricingType == ProductPricingType.fraction;

    return Card(
      color: const Color(0xFF101610),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'OPTION ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (index > 0)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),

            DropdownButtonFormField<ProductPricingType>(
              initialValue: pricing.pricingType,
              dropdownColor: const Color(0xFF101610),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'PRICING TYPE',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              items: ProductPricingType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _changeType(value);
              },
            ),

            const SizedBox(height: 10),

            if (isUnit || isWeight)
              TextFormField(
                initialValue: pricing.unitName ?? '',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isWeight
                      ? 'UNIT NAME (e.g. kg)'
                      : 'UNIT NAME (e.g. piece)',
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                onChanged: (value) {
                  onChanged(
                    _copy(unitName: value.trim().isEmpty ? null : value.trim()),
                  );
                },
              ),

            if (isUnit || isWeight) const SizedBox(height: 10),

            if (isUnit || isWeight)
              TextFormField(
                initialValue: pricing.quantity?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'QUANTITY',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                onChanged: (value) {
                  onChanged(_copy(quantity: double.tryParse(value)));
                },
              ),

            if (isUnit || isWeight) const SizedBox(height: 10),

            if (isFraction)
              TextFormField(
                initialValue: pricing.fractionValue?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'FRACTION VALUE',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: '0.25 - 0.50 - 0.75 - 1.00',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);

                  onChanged(_copy(fractionValue: parsed));
                },
              ),

            if (isFraction) const SizedBox(height: 10),

            TextFormField(
              initialValue: pricing.price.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'PRICE',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              onChanged: (value) {
                onChanged(_copy(price: double.tryParse(value) ?? 0));
              },
            ),

            const SizedBox(height: 10),

            Text(
              isUnit
                  ? 'Unit pricing: piece/item based.'
                  : isWeight
                  ? 'Weight pricing: kg/g based on quantity.'
                  : isValue
                  ? 'Value pricing: price-based selling.'
                  : 'Fraction pricing: value must be between 0 and 1.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
