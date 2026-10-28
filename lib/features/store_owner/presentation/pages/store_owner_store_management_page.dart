import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/image_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_printer_billbay/thermal_printer_billbay.dart';

import '../../data/services/store_printer_settings_service.dart';
import '../../data/services/store_order_receipt_builder.dart';
import '../../data/services/thermal_printer_service.dart';

import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/product_category.dart';
import '../../../catalog/domain/entities/product_pricing.dart';
import '../../../catalog/domain/entities/store.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import 'store_owner_offers_page.dart';

class StoreOwnerStoreManagementPage extends ConsumerWidget {
  final Store store;

  const StoreOwnerStoreManagementPage({super.key, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      activeProductCategoriesByStoreProvider(store.id),
    );
    final productsAsync = ref.watch(activeProductsByStoreProvider(store.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: Text(
          '\u{625}\u{62F}\u{627}\u{631}\u{629} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}: ${store.name}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip:
                '\u{627}\u{644}\u{639}\u{631}\u{648}\u{636} \u{648}\u{627}\u{644}\u{62E}\u{635}\u{648}\u{645}\u{627}\u{62A}',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreOwnerOffersPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeProductCategoriesByStoreProvider(store.id));
          ref.invalidate(activeProductsByStoreProvider(store.id));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _StoreHero(store: store),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            _StorePrinterSettingsCard(storeId: store.id),
            const SizedBox(height: 24),
            _QuickStats(
              categoriesAsync: categoriesAsync,
              productsAsync: productsAsync,
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title:
                  '\u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}\u{627}\u{62A}',
              subtitle:
                  '\u{625}\u{62F}\u{627}\u{631}\u{629} \u{62A}\u{635}\u{646}\u{64A}\u{641}\u{627}\u{62A} \u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}.',
              icon: Icons.category_outlined,
              actionLabel:
                  '\u{625}\u{636}\u{627}\u{641}\u{629} \u{62A}\u{635}\u{646}\u{64A}\u{641}',
              onAction: () {
                _showCategoryDialog(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _CategoriesCard(
              storeId: store.id,
              categoriesAsync: categoriesAsync,
              onEdit: (category) {
                _showCategoryDialog(context, ref, category: category);
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: '\u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
              subtitle:
                  '\u{625}\u{62F}\u{627}\u{631}\u{629} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{648}\u{627}\u{644}\u{623}\u{633}\u{639}\u{627}\u{631} \u{641}\u{64A} \u{645}\u{62A}\u{62C}\u{631}\u{643}.',
              icon: Icons.inventory_2_outlined,
              actionLabel:
                  '\u{625}\u{636}\u{627}\u{641}\u{629} \u{645}\u{646}\u{62A}\u{62C}',
              onAction: () {
                _showProductDialog(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _ProductsCard(
              storeId: store.id,
              productsAsync: productsAsync,
              onToggleAvailability: (product) async {
                final newAvailability = !product.isAvailable;

                try {
                  final updatedProduct = await Supabase.instance.client
                      .from('products')
                      .update({'is_available': newAvailability})
                      .eq('id', product.id)
                      .eq('store_id', store.id)
                      .select('id')
                      .maybeSingle();

                  if (updatedProduct == null) {
                    throw StateError('Product availability was not updated.');
                  }

                  ref.invalidate(activeProductsByStoreProvider(store.id));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newAvailability
                              ? '\u{62A}\u{645} \u{625}\u{62A}\u{627}\u{62D}\u{629} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} \u{644}\u{644}\u{628}\u{64A}\u{639}.'
                              : '\u{62A}\u{645} \u{62A}\u{62D}\u{62F}\u{64A}\u{62F} \u{646}\u{641}\u{630}\u{62A} \u{627}\u{644}\u{643}\u{645}\u{64A}\u{629}.',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '\u{62A}\u{639}\u{630}\u{631} \u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{62D}\u{627}\u{644}\u{629} \u{627}\u{644}\u{62A}\u{648}\u{641}\u{631}: $error',
                      ),
                    ),
                  );
                }
              },
              onEdit: (product) {
                _showProductDialog(context, ref, product: product);
              },
              onDelete: (product) {
                _confirmDeleteProduct(context, ref, product);
              },
            ),
            _ManagementActionCard(
              icon: Icons.local_offer_outlined,
              title:
                  '\u{627}\u{644}\u{639}\u{631}\u{648}\u{636} \u{648}\u{627}\u{644}\u{62E}\u{635}\u{648}\u{645}\u{627}\u{62A}',
              subtitle:
                  '\u{623}\u{646}\u{634}\u{626} \u{639}\u{631}\u{648}\u{636}\u{64B}\u{627} \u{648}\u{62E}\u{635}\u{648}\u{645}\u{627}\u{62A} \u{644}\u{639}\u{645}\u{644}\u{627}\u{626}\u{643}.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StoreOwnerOffersPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    ProductCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(
      text: category?.description ?? '',
    );

    XFile? selectedCategoryImage;
    Uint8List? selectedCategoryImageBytes;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            category == null
                ? '\u{625}\u{636}\u{627}\u{641}\u{629} \u{62A}\u{635}\u{646}\u{64A}\u{641}'
                : '\u{62A}\u{639}\u{62F}\u{64A}\u{644} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText:
                      '\u{627}\u{633}\u{645} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      '\u{648}\u{635}\u{641} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(
                builder: (imageContext, setImageState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 125,
                          child: selectedCategoryImageBytes != null
                              ? Image.memory(
                                  selectedCategoryImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (category?.imageUrl?.trim().isNotEmpty ?? false)
                              ? Image.network(
                                  category!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFEAF4EF),
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 42,
                                        color: Color(0xFF23845D),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: const Color(0xFFEAF4EF),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 46,
                                    color: Color(0xFF23845D),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
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

                            if (!imageContext.mounted) {
                              return;
                            }

                            setImageState(() {
                              selectedCategoryImage = picked;
                              selectedCategoryImageBytes = bytes;
                            });
                          } catch (error) {
                            if (!imageContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(imageContext).showSnackBar(
                              SnackBar(
                                content: Text('تعذر اختيار الصورة: $error'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          selectedCategoryImage != null ||
                                  (category?.imageUrl?.trim().isNotEmpty ??
                                      false)
                              ? '\u{62A}\u{63A}\u{64A}\u{64A}\u{631} \u{635}\u{648}\u{631}\u{629} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}'
                              : '\u{625}\u{636}\u{627}\u{641}\u{629} \u{635}\u{648}\u{631}\u{629} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG, PNG, WEBP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF718079),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('\u{625}\u{644}\u{63A}\u{627}\u{621}'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{627}\u{633}\u{645} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  final repository = ref.read(
                    productCategoryRepositoryProvider,
                  );

                  String? imageUrl = category?.imageUrl;

                  if (selectedCategoryImage != null) {
                    imageUrl = await ImageUploadService().uploadStoreImage(
                      file: selectedCategoryImage!,
                      storeId: store.id,
                      imageType:
                          'category-${category?.id ?? 'new'}-${DateTime.now().microsecondsSinceEpoch}',
                    );
                  }

                  if (category == null) {
                    await repository.createCategory(
                      storeId: store.id,
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      imageUrl: imageUrl,
                    );
                  } else {
                    await repository.updateCategory(
                      categoryId: category.id,
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      imageUrl: imageUrl,
                      isActive: category.isActive,
                      sortOrder: category.sortOrder,
                    );
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        '\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}:\n$error',
                      ),
                    ),
                  );
                }
              },
              child: const Text('\u{62D}\u{641}\u{638}'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      ref.invalidate(activeProductCategoriesByStoreProvider(store.id));
    }

    nameController.dispose();
    descriptionController.dispose();

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            category == null
                ? '\u{62A}\u{645}\u{62A} \u{625}\u{636}\u{627}\u{641}\u{629} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641} \u{628}\u{646}\u{62C}\u{627}\u{62D}.'
                : '\u{62A}\u{645} \u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641} \u{628}\u{646}\u{62C}\u{627}\u{62D}.',
          ),
        ),
      );
    }
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) async {
    final categories = await ref.read(
      activeProductCategoriesByStoreProvider(store.id).future,
    );

    if (!context.mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductEditorDialog(
        storeId: store.id,
        categories: categories,
        product: product,
      ),
    );

    if (saved == true) {
      ref.invalidate(activeProductsByStoreProvider(store.id));
    }
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '\u{62D}\u{630}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
          ),
          content: Text(
            '\u{647}\u{644} \u{62A}\u{631}\u{64A}\u{62F} \u{62D}\u{630}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} "${product.name}"\u{61F}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('\u{625}\u{644}\u{63A}\u{627}\u{621}'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('\u{62D}\u{630}\u{641}'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(productRepositoryProvider).deleteProduct(product.id);

      ref.invalidate(activeProductsByStoreProvider(store.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '\u{62A}\u{645} \u{62D}\u{630}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} \u{628}\u{646}\u{62C}\u{627}\u{62D}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}:\n$error',
            ),
          ),
        );
      }
    }
  }
}

class _StoreHero extends StatelessWidget {
  final Store store;

  const _StoreHero({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F4FF), Color(0xFFF3FAFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7EAF8)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: store.logoUrl?.trim().isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      store.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.storefront_outlined, size: 30),
                    ),
                  )
                : const Icon(Icons.storefront_outlined, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  store.isActive
                      ? '\u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631} \u{646}\u{634}\u{637}'
                      : '\u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631} \u{63A}\u{64A}\u{631} \u{646}\u{634}\u{637}',
                  style: TextStyle(
                    color: store.isActive
                        ? const Color(0xFF277A55)
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final AsyncValue<List<ProductCategory>> categoriesAsync;
  final AsyncValue<List<Product>> productsAsync;

  const _QuickStats({
    required this.categoriesAsync,
    required this.productsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoriesAsync is AsyncData<List<ProductCategory>>
        ? categoriesAsync.value?.length
        : null;
    final products = productsAsync is AsyncData<List<Product>>
        ? productsAsync.value?.length
        : null;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.category_outlined,
            label:
                '\u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}\u{627}\u{62A}',
            value: categories?.toString() ?? '--',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            label: '\u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
            value: products?.toString() ?? '--',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF357AA8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF357AA8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  final String storeId;
  final AsyncValue<List<ProductCategory>> categoriesAsync;
  final void Function(ProductCategory category) onEdit;

  const _CategoriesCard({
    required this.storeId,
    required this.categoriesAsync,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return categoriesAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}:\n$error'),
        ),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{62A}\u{635}\u{646}\u{64A}\u{641}\u{627}\u{62A} \u{644}\u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}.',
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: categories.map((category) {
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.category_outlined),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: category.description == null
                    ? null
                    : Text(category.description!),
                trailing: IconButton(
                  tooltip:
                      '\u{62A}\u{639}\u{62F}\u{64A}\u{644} \u{627}\u{644}\u{62A}\u{635}\u{646}\u{64A}\u{641}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(category),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ProductsCard extends StatefulWidget {
  final String storeId;
  final AsyncValue<List<Product>> productsAsync;
  final Future<void> Function(Product product) onToggleAvailability;
  final void Function(Product product) onEdit;
  final void Function(Product product) onDelete;

  const _ProductsCard({
    required this.storeId,
    required this.productsAsync,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ProductsCard> createState() => _ProductsCardState();
}

class _ProductsCardState extends State<_ProductsCard> {
  String _productSort = 'nameAsc';

  List<Product> _sortProducts(List<Product> products) {
    final sorted = List<Product>.of(products);

    String normalizedName(String name) {
      return name
          .toLowerCase()
          .replaceAll(RegExp('[\u{0623}\u{0625}\u{0622}\u{0671}]'), '\u{0627}')
          .replaceAll('\u{0649}', '\u{064A}');
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

  @override
  Widget build(BuildContext context) {
    return widget.productsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}:\n$error'),
        ),
      ),
      data: (products) {
        final storeProducts = products
            .where((product) => product.storeId == widget.storeId)
            .toList();

        if (storeProducts.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{644}\u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}.',
              ),
            ),
          );
        }

        final sortedProducts = _sortProducts(storeProducts);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _productSort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '\u{62A}\u{631}\u{62A}\u{64A}\u{628} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'nameAsc',
                        child: Text(
                          '\u{627}\u{644}\u{627}\u{633}\u{645}: \u{645}\u{646} \u{623} \u{625}\u{644}\u{649} \u{64A}',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'nameDesc',
                        child: Text(
                          '\u{627}\u{644}\u{627}\u{633}\u{645}: \u{645}\u{646} \u{64A} \u{625}\u{644}\u{649} \u{623}',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'priceDesc',
                        child: Text(
                          '\u{627}\u{644}\u{633}\u{639}\u{631}: \u{645}\u{646} \u{627}\u{644}\u{623}\u{639}\u{644}\u{649} \u{625}\u{644}\u{649} \u{627}\u{644}\u{623}\u{642}\u{644}',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'priceAsc',
                        child: Text(
                          '\u{627}\u{644}\u{633}\u{639}\u{631}: \u{645}\u{646} \u{627}\u{644}\u{623}\u{642}\u{644} \u{625}\u{644}\u{649} \u{627}\u{644}\u{623}\u{639}\u{644}\u{649}',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _productSort = value);
                    },
                  ),
                ),
                ...sortedProducts.map((product) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: _ProductThumb(product: product),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} \u{62C}.\u{645}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.isAvailable
                              ? '\u{645}\u{62A}\u{627}\u{62D} \u{644}\u{644}\u{628}\u{64A}\u{639}'
                              : '\u{646}\u{641}\u{630}\u{62A} \u{627}\u{644}\u{643}\u{645}\u{64A}\u{629}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: product.isAvailable
                                ? const Color(0xFF168957)
                                : Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: product.isAvailable
                              ? '\u{646}\u{641}\u{630}\u{62A} \u{627}\u{644}\u{643}\u{645}\u{64A}\u{629}'
                              : '\u{625}\u{62A}\u{627}\u{62D}\u{629} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
                          onPressed: () async {
                            await widget.onToggleAvailability(product);
                          },
                          icon: Icon(
                            product.isAvailable
                                ? Icons.inventory_2_outlined
                                : Icons.check_circle_outline,
                            color: product.isAvailable
                                ? Colors.deepOrange
                                : const Color(0xFF168957),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              widget.onEdit(product);
                            } else if (value == 'delete') {
                              widget.onDelete(product);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('\u{62A}\u{639}\u{62F}\u{64A}\u{644}'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('\u{62D}\u{630}\u{641}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final Product product;

  const _ProductThumb({required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl?.trim().isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          product.imageUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _ProductPlaceholder(),
        ),
      );
    }

    return const _ProductPlaceholder();
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 52,
      height: 52,
      child: CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
    );
  }
}

class _StorePrinterSettingsCard extends StatefulWidget {
  final String storeId;

  const _StorePrinterSettingsCard({required this.storeId});

  @override
  State<_StorePrinterSettingsCard> createState() =>
      _StorePrinterSettingsCardState();
}

class _StorePrinterSettingsCardState extends State<_StorePrinterSettingsCard> {
  final StorePrinterSettingsService _settingsService =
      StorePrinterSettingsService();
  final ThermalPrinterService _printerService = ThermalPrinterService();

  static const List<CodePage> _codePages = [
    CodePage.utf8,
    CodePage.utf8Alt,
    CodePage.win1256,
    CodePage.cp864,
    CodePage.cp720,
  ];

  StorePrinterSettings _settings = const StorePrinterSettings();

  List<BluetoothDevice> _devices = const [];

  String? _selectedAddress;
  PaperSize _paperSize = PaperSize.mm80;
  CodePage _codePage = CodePage.utf8;

  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _printerService.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.load(widget.storeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _selectedAddress = settings.printerAddress;
        _paperSize = settings.paperSize;
        _codePage = settings.codePage;
        _loading = false;
      });
    } catch (error) {
      debugPrint('STORE MANAGEMENT: printer settings load failed -> $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refreshDevices() async {
    if (_refreshing || _testing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      final ready = await _printerService.prepare();

      if (!ready) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '\u{644}\u{645} \u{64A}\u{62A}\u{645} \u{62A}\u{641}\u{639}\u{64A}\u{644} \u{635}\u{644}\u{627}\u{62D}\u{64A}\u{627}\u{62A} Bluetooth \u{623}\u{648} Bluetooth \u{646}\u{641}\u{633}\u{647}.',
            ),
          ),
        );
        return;
      }

      final devices = await _printerService.getBondedDevices();

      if (!mounted) {
        return;
      }

      setState(() {
        _devices = devices;

        if (_selectedAddress != null &&
            !devices.any((device) => device.address == _selectedAddress)) {
          _selectedAddress = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            devices.isEmpty
                ? '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{623}\u{62C}\u{647}\u{632}\u{629} Bluetooth \u{645}\u{642}\u{62A}\u{631}\u{646}\u{629} \u{62D}\u{627}\u{644}\u{64A}\u{64B}\u{627}.'
                : '\u{62A}\u{645} \u{627}\u{644}\u{639}\u{62B}\u{648}\u{631} \u{639}\u{644}\u{649} ${devices.length} \u{62C}\u{647}\u{627}\u{632} Bluetooth \u{645}\u{642}\u{62A}\u{631}\u{646}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u{62A}\u{639}\u{630}\u{631} \u{642}\u{631}\u{627}\u{621}\u{629} \u{623}\u{62C}\u{647}\u{632}\u{629} Bluetooth:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final address = _selectedAddress?.trim() ?? '';

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u{627}\u{62E}\u{62A}\u{631} \u{637}\u{627}\u{628}\u{639}\u{629} Bluetooth \u{623}\u{648}\u{644}\u{64B}\u{627}.',
          ),
        ),
      );
      return;
    }

    BluetoothDevice? selectedDevice;

    for (final device in _devices) {
      if (device.address == address) {
        selectedDevice = device;
        break;
      }
    }

    final savedName = selectedDevice?.name.trim().isNotEmpty == true
        ? selectedDevice!.name
        : (_settings.printerName?.trim().isNotEmpty == true
              ? _settings.printerName!
              : 'Bluetooth Printer');

    setState(() {
      _saving = true;
    });

    try {
      await _settingsService.save(
        widget.storeId,
        printerName: savedName,
        printerAddress: address,
        paperSize: _paperSize,
        codePage: _codePage,
      );

      final settings = await _settingsService.load(widget.storeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u{62A}\u{645} \u{62D}\u{641}\u{638} \u{625}\u{639}\u{62F}\u{627}\u{62F}\u{627}\u{62A} \u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u{62A}\u{639}\u{630}\u{631} \u{62D}\u{641}\u{638} \u{625}\u{639}\u{62F}\u{627}\u{62F}\u{627}\u{62A} \u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629}:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _printTestTicket() async {
    final address = _selectedAddress?.trim() ?? '';

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u{627}\u{62E}\u{62A}\u{631} \u{637}\u{627}\u{628}\u{639}\u{629} Bluetooth \u{623}\u{648}\u{644}\u{64B}\u{627}.',
          ),
        ),
      );
      return;
    }

    if (_testing || _saving || _refreshing) {
      return;
    }

    setState(() {
      _testing = true;
    });

    try {
      final ready = await _printerService.prepare();

      if (!ready) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bluetooth \u{63A}\u{64A}\u{631} \u{62C}\u{627}\u{647}\u{632} \u{644}\u{644}\u{637}\u{628}\u{627}\u{639}\u{629}.',
            ),
          ),
        );
        return;
      }

      final printerStillPaired = _devices.any(
        (device) => device.address == address,
      );

      if (!printerStillPaired) {
        final bondedDevices = await _printerService.getBondedDevices();

        if (!bondedDevices.any((device) => device.address == address)) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '\u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629} \u{627}\u{644}\u{645}\u{62E}\u{62A}\u{627}\u{631}\u{629} \u{63A}\u{64A}\u{631} \u{645}\u{648}\u{62C}\u{648}\u{62F}\u{629} \u{636}\u{645}\u{646} \u{627}\u{644}\u{623}\u{62C}\u{647}\u{632}\u{629} \u{627}\u{644}\u{645}\u{642}\u{62A}\u{631}\u{646}\u{629}.',
              ),
            ),
          );
          return;
        }
      }

      final order = StoreOrderPrintData(
        orderNumber: 'TEST-PRINTER',
        customerName: 'Hena Test',
        customerPhone: '01000000000',
        deliveryAddress: 'Bluetooth Test',
        items: const [
          StoreOrderPrintItem(
            productName: 'Printer Test Item',
            quantity: '1',
            unitPrice: 1.00,
            itemTotal: 1.00,
          ),
        ],
        itemCount: 1,
        subtotal: 1.00,
        status: 'TEST',
        customerNote: null,
      );

      final printed = await _printerService.printReceipt(
        address: address,
        order: order,
        paperSize: _paperSize,
        codePage: _codePage,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? '\u{62A}\u{645} \u{625}\u{631}\u{633}\u{627}\u{644} \u{628}\u{64A}\u{627}\u{646}\u{627}\u{62A} \u{627}\u{62E}\u{62A}\u{628}\u{627}\u{631} \u{627}\u{644}\u{637}\u{628}\u{627}\u{639}\u{629} \u{625}\u{644}\u{649} \u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629}.'
                : '\u{641}\u{634}\u{644} \u{625}\u{631}\u{633}\u{627}\u{644} \u{628}\u{64A}\u{627}\u{646}\u{627}\u{62A} \u{627}\u{62E}\u{62A}\u{628}\u{627}\u{631} \u{627}\u{644}\u{637}\u{628}\u{627}\u{639}\u{629}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u{641}\u{634}\u{644} \u{627}\u{62E}\u{62A}\u{628}\u{627}\u{631} \u{627}\u{644}\u{637}\u{628}\u{627}\u{639}\u{629}:\n$error',
          ),
        ),
      );
    } finally {
      try {
        await _printerService.disconnect();
      } catch (error) {
        debugPrint('STORE MANAGEMENT: printer disconnect failed -> $error');
      }

      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  String _codePageLabel(CodePage page) {
    if (page == CodePage.utf8) {
      return 'UTF-8  PC10001';
    }

    if (page == CodePage.utf8Alt) {
      return 'UTF-8  FS &';
    }

    if (page == CodePage.win1256) {
      return 'Windows-1256  CP46';
    }

    if (page == CodePage.cp864) {
      return 'CP864  CP22';
    }

    if (page == CodePage.cp720) {
      return 'CP720  CP32';
    }

    return page.name;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDeviceInList = _devices.any(
      (device) => device.address == _selectedAddress,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFD7EAF8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFF1F8FF), Color(0xFFF9FCFF)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F1FC),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.print_outlined,
                            color: Color(0xFF357AA8),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\u{625}\u{639}\u{62F}\u{627}\u{62F}\u{627}\u{62A} \u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF233149),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '\u{637}\u{627}\u{628}\u{639}\u{629} Bluetooth \u{627}\u{644}\u{62E}\u{627}\u{635}\u{629} \u{628}\u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7A8597),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip:
                              '\u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{627}\u{644}\u{623}\u{62C}\u{647}\u{632}\u{629}',
                          onPressed: (_refreshing || _testing)
                              ? null
                              : _refreshDevices,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCEBF7)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _settings.hasPrinter
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: _settings.hasPrinter
                                ? const Color(0xFF2C9A70)
                                : const Color(0xFFD97A2C),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _settings.hasPrinter
                                  ? '\u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629} \u{627}\u{644}\u{645}\u{62D}\u{641}\u{648}\u{638}\u{629}: ${_settings.printerName ?? 'Bluetooth Printer'}\n${_settings.printerAddress}'
                                  : '\u{644}\u{645} \u{64A}\u{62A}\u{645} \u{62D}\u{641}\u{638} \u{637}\u{627}\u{628}\u{639}\u{629} \u{644}\u{647}\u{630}\u{627} \u{627}\u{644}\u{645}\u{62A}\u{62C}\u{631} \u{628}\u{639}\u{62F}.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                                color: _settings.hasPrinter
                                    ? const Color(0xFF376B58)
                                    : const Color(0xFF8A6A45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '\u{627}\u{644}\u{623}\u{62C}\u{647}\u{632}\u{629} \u{627}\u{644}\u{645}\u{642}\u{62A}\u{631}\u{646}\u{629}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF33445C),
                      ),
                    ),
                    const SizedBox(height: 7),
                    InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.bluetooth),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDeviceInList ? _selectedAddress : null,
                          hint: Text(
                            _devices.isEmpty
                                ? '\u{627}\u{636}\u{63A}\u{637} \u{62A}\u{62D}\u{62F}\u{64A}\u{62B} \u{644}\u{639}\u{631}\u{636} \u{627}\u{644}\u{623}\u{62C}\u{647}\u{632}\u{629} \u{627}\u{644}\u{645}\u{642}\u{62A}\u{631}\u{646}\u{629}'
                                : '\u{627}\u{62E}\u{62A}\u{631} \u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629}',
                          ),
                          items: _devices
                              .map(
                                (device) => DropdownMenuItem<String>(
                                  value: device.address,
                                  child: Text(
                                    '${device.name}  ${device.address}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (_testing || _saving)
                              ? null
                              : (address) {
                                  setState(() {
                                    _selectedAddress = address;
                                  });
                                },
                        ),
                      ),
                    ),
                    if (!selectedDeviceInList && _settings.hasPrinter) ...[
                      const SizedBox(height: 7),
                      Text(
                        '\u{627}\u{644}\u{637}\u{627}\u{628}\u{639}\u{629} \u{627}\u{644}\u{645}\u{62D}\u{641}\u{648}\u{638}\u{629}: ${_settings.printerName ?? 'Bluetooth Printer'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A8597),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      '\u{645}\u{642}\u{627}\u{633} \u{627}\u{644}\u{648}\u{631}\u{642}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF33445C),
                      ),
                    ),
                    const SizedBox(height: 7),
                    InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaperSize>(
                          isExpanded: true,
                          value: _paperSize,
                          items: PaperSize.values
                              .map(
                                (size) => DropdownMenuItem<PaperSize>(
                                  value: size,
                                  child: Text(
                                    '${size.label}  ${size.charsPerLineA} \u{62D}\u{631}\u{641}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (_testing || _saving)
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _paperSize = value;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '\u{62A}\u{631}\u{645}\u{64A}\u{632} \u{627}\u{644}\u{644}\u{63A}\u{629} \u{627}\u{644}\u{639}\u{631}\u{628}\u{64A}\u{629}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF33445C),
                      ),
                    ),
                    const SizedBox(height: 7),
                    InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.translate_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CodePage>(
                          isExpanded: true,
                          value: _codePage,
                          items: _codePages
                              .map(
                                (page) => DropdownMenuItem<CodePage>(
                                  value: page,
                                  child: Text(_codePageLabel(page)),
                                ),
                              )
                              .toList(),
                          onChanged: (_testing || _saving)
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _codePage = value;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: (_saving || _testing)
                              ? null
                              : _saveSettings,
                          icon: _saving
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text(
                            '\u{62D}\u{641}\u{638} \u{627}\u{644}\u{625}\u{639}\u{62F}\u{627}\u{62F}\u{627}\u{62A}',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: (_testing || _saving)
                              ? null
                              : _printTestTicket,
                          icon: _testing
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: const Text(
                            '\u{627}\u{62E}\u{62A}\u{628}\u{627}\u{631} \u{627}\u{644}\u{637}\u{628}\u{627}\u{639}\u{629}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ManagementActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductEditorDialog extends ConsumerStatefulWidget {
  final String storeId;
  final List<ProductCategory> categories;
  final Product? product;

  const _ProductEditorDialog({
    required this.storeId,
    required this.categories,
    this.product,
  });

  @override
  ConsumerState<_ProductEditorDialog> createState() =>
      _ProductEditorDialogState();
}

class _ProductEditorDialogState extends ConsumerState<_ProductEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _sellingValueController;

  String? _categoryId;
  ProductSellingMethod _sellingMethod = ProductSellingMethod.unit;

  final List<_PricingDraftRow> _pricingRows = [];

  bool _saving = false;

  XFile? _selectedImage;

  final ImagePicker _imagePicker = ImagePicker();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    _sellingValueController = TextEditingController(
      text: product?.sellingValue.toString() ?? '1',
    );

    _categoryId = product?.categoryId;
    _sellingMethod = product?.sellingMethod ?? ProductSellingMethod.unit;

    if (product != null) {
      _loadExistingPricing(product.id);
    } else {
      _pricingRows.add(_PricingDraftRow());
    }
  }

  Future<void> _loadExistingPricing(String productId) async {
    try {
      final pricing = await ref.read(
        activePricingByProductProvider(productId).future,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pricingRows
          ..clear()
          ..addAll(pricing.map((item) => _PricingDraftRow.fromPricing(item)));

        if (_pricingRows.isEmpty) {
          _pricingRows.add(_PricingDraftRow());
        }
      });
    } catch (error) {
      // The dialog can still be closed without changing the product.
      debugPrint('STORE MANAGEMENT: existing pricing load failed -> $error');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _sellingValueController.dispose();

    for (final row in _pricingRows) {
      row.dispose();
    }

    super.dispose();
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        '\u{641}\u{634}\u{644} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{635}\u{648}\u{631}\u{629}:\n$error',
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final sellingValue = double.tryParse(
      _sellingValueController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty) {
      _showError(
        '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{627}\u{633}\u{645} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}.',
      );
      return;
    }

    if (_categoryId == null) {
      _showError(
        '\u{64A}\u{631}\u{62C}\u{649} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{62A}\u{635}\u{646}\u{64A}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}.',
      );
      return;
    }

    if (price == null || price <= 0) {
      _showError(
        '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{633}\u{639}\u{631} \u{635}\u{62D}\u{64A}\u{62D} \u{623}\u{643}\u{628}\u{631} \u{645}\u{646} \u{635}\u{641}\u{631}.',
      );
      return;
    }

    if (sellingValue == null || sellingValue <= 0) {
      _showError(
        '\u{64A}\u{631}\u{62C}\u{649} \u{625}\u{62F}\u{62E}\u{627}\u{644} \u{642}\u{64A}\u{645}\u{629} \u{628}\u{64A}\u{639} \u{635}\u{62D}\u{64A}\u{62D}\u{629} \u{623}\u{643}\u{628}\u{631} \u{645}\u{646} \u{635}\u{641}\u{631}.',
      );
      return;
    }

    if (_pricingRows.isEmpty) {
      _showError(
        '\u{623}\u{636}\u{641} \u{633}\u{639}\u{631}\u{64B}\u{627} \u{648}\u{627}\u{62D}\u{62F}\u{64B}\u{627} \u{639}\u{644}\u{649} \u{627}\u{644}\u{623}\u{642}\u{644}.',
      );
      return;
    }

    final pricing = <ProductPricingDraft>[];

    for (var index = 0; index < _pricingRows.length; index++) {
      final row = _pricingRows[index];

      final rowPrice = double.tryParse(
        row.priceController.text.trim().replaceAll(',', '.'),
      );

      if (rowPrice == null || rowPrice <= 0) {
        _showError(
          '\u{627}\u{644}\u{633}\u{639}\u{631} \u{641}\u{64A} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631} \u{631}\u{642}\u{645} ${index + 1} \u{63A}\u{64A}\u{631} \u{635}\u{62D}\u{64A}\u{62D}.',
        );
        return;
      }

      double? quantity;
      double? fractionValue;

      if (row.pricingType == ProductPricingType.unit ||
          row.pricingType == ProductPricingType.weight) {
        final unitName = row.unitNameController.text.trim();

        quantity = double.tryParse(
          row.quantityController.text.trim().replaceAll(',', '.'),
        );

        if (unitName.isEmpty || quantity == null || quantity <= 0) {
          _showError(
            '\u{623}\u{62F}\u{62E}\u{644} \u{627}\u{644}\u{648}\u{62D}\u{62F}\u{629} \u{648}\u{627}\u{644}\u{643}\u{645}\u{64A}\u{629} \u{641}\u{64A} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631} \u{631}\u{642}\u{645} ${index + 1} \u{628}\u{635}\u{648}\u{631}\u{629} \u{635}\u{62D}\u{64A}\u{62D}\u{629}.',
          );
          return;
        }
      }

      if (row.pricingType == ProductPricingType.fraction) {
        fractionValue = double.tryParse(
          row.fractionController.text.trim().replaceAll(',', '.'),
        );

        if (fractionValue == null || fractionValue <= 0 || fractionValue > 1) {
          _showError(
            '\u{642}\u{64A}\u{645}\u{629} \u{627}\u{644}\u{643}\u{633}\u{631} \u{641}\u{64A} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631} \u{631}\u{642}\u{645} ${index + 1} \u{64A}\u{62C}\u{628} \u{623}\u{646} \u{62A}\u{643}\u{648}\u{646} \u{623}\u{643}\u{628}\u{631} \u{645}\u{646} 0 \u{648}\u{623}\u{642}\u{644} \u{645}\u{646} \u{623}\u{648} \u{62A}\u{633}\u{627}\u{648}\u{64A} 1.',
          );
          return;
        }
      }

      pricing.add(
        ProductPricingDraft(
          pricingType: row.pricingType,
          unitName:
              row.pricingType == ProductPricingType.unit ||
                  row.pricingType == ProductPricingType.weight
              ? row.unitNameController.text.trim()
              : null,
          quantity: quantity,
          price: rowPrice,
          fractionValue: fractionValue,
          isActive: row.isActive,
          sortOrder: index,
        ),
      );
    }

    setState(() {
      _saving = true;
    });

    try {
      final repository = ref.read(storeOwnerProductRepositoryProvider);

      late final String productId;

      if (_isEditing) {
        productId = widget.product!.id;

        await repository.updateProduct(
          productId: productId,
          categoryId: _categoryId!,
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          price: price,
          sellingMethod: _sellingMethod,
          sellingValue: sellingValue,
          isActive: widget.product!.isActive,
          pricing: pricing,
        );
      } else {
        productId = await repository.createProduct(
          storeId: widget.storeId,
          categoryId: _categoryId!,
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          price: price,
          sellingMethod: _sellingMethod,
          sellingValue: sellingValue,
          isActive: true,
          pricing: pricing,
        );
      }

      if (_selectedImage != null) {
        final imageUrl = await ImageUploadService().uploadProductImage(
          file: _selectedImage!,
          productId: productId,
        );

        await Supabase.instance.client
            .from('products')
            .update({'image_url': imageUrl})
            .eq('id', productId);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError(
        '\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623} \u{623}\u{62B}\u{646}\u{627}\u{621} \u{62D}\u{641}\u{638} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}:\n$error',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addPricingRow() {
    setState(() {
      _pricingRows.add(_PricingDraftRow());
    });
  }

  void _removePricingRow(int index) {
    if (_pricingRows.length == 1) {
      return;
    }

    final row = _pricingRows.removeAt(index);
    row.dispose();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing
            ? '\u{62A}\u{639}\u{62F}\u{64A}\u{644} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}'
            : '\u{625}\u{636}\u{627}\u{641}\u{629} \u{645}\u{646}\u{62A}\u{62C}',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProductImagePicker(
                selectedImage: _selectedImage,
                existingImageUrl: widget.product?.imageUrl,
                onPick: _pickProductImage,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText:
                      '\u{627}\u{633}\u{645} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText:
                      '\u{627}\u{62E}\u{62A}\u{631} \u{62A}\u{635}\u{646}\u{64A}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      '\u{627}\u{62E}\u{62A}\u{631} \u{62A}\u{635}\u{646}\u{64A}\u{641}\u{64B}\u{627}',
                    ),
                  ),
                  ...widget.categories.map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      '\u{648}\u{635}\u{641} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C} (\u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631}\u{64A})',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '\u{627}\u{644}\u{633}\u{639}\u{631}',
                        suffixText: '\u{62C}.\u{645}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _sellingValueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText:
                            '\u{642}\u{64A}\u{645}\u{629} \u{627}\u{644}\u{628}\u{64A}\u{639}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProductSellingMethod>(
                initialValue: _sellingMethod,
                decoration: const InputDecoration(
                  labelText:
                      '\u{637}\u{631}\u{64A}\u{642}\u{629} \u{627}\u{644}\u{628}\u{64A}\u{639}',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                items: ProductSellingMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_sellingMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _sellingMethod = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '\u{623}\u{633}\u{639}\u{627}\u{631} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPricingRow,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      '\u{625}\u{636}\u{627}\u{641}\u{629} \u{633}\u{639}\u{631}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._pricingRows.asMap().entries.map(
                (entry) => _PricingRowEditor(
                  key: ObjectKey(entry.value),
                  row: entry.value,
                  index: entry.key,
                  onRemove: () => _removePricingRow(entry.key),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('\u{625}\u{644}\u{63A}\u{627}\u{621}'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text(
            '\u{62D}\u{641}\u{638} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
          ),
        ),
      ],
    );
  }

  String _sellingMethodLabel(ProductSellingMethod method) {
    switch (method) {
      case ProductSellingMethod.unit:
        return '\u{628}\u{627}\u{644}\u{648}\u{62D}\u{62F}\u{629}';
      case ProductSellingMethod.value:
        return '\u{62D}\u{633}\u{628} \u{627}\u{644}\u{642}\u{64A}\u{645}\u{629}';
      case ProductSellingMethod.fraction:
        return '\u{628}\u{627}\u{644}\u{643}\u{633}\u{631}';
      case ProductSellingMethod.weight:
        return '\u{628}\u{627}\u{644}\u{648}\u{632}\u{646}';
    }
  }
}

class _ProductImagePicker extends StatelessWidget {
  final XFile? selectedImage;
  final String? existingImageUrl;
  final VoidCallback onPick;

  const _ProductImagePicker({
    required this.selectedImage,
    required this.existingImageUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasExistingImage = existingImageUrl?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '\u{635}\u{648}\u{631}\u{629} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: selectedImage != null
              ? FutureBuilder<Uint8List>(
                  future: selectedImage!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const _ProductImagePlaceholder();
                    }

                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  },
                )
              : hasExistingImage
              ? Image.network(
                  existingImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _ProductImagePlaceholder(),
                )
              : const _ProductImagePlaceholder(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              selectedImage != null || hasExistingImage
                  ? '\u{62A}\u{63A}\u{64A}\u{64A}\u{631} \u{627}\u{644}\u{635}\u{648}\u{631}\u{629}'
                  : '\u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{635}\u{648}\u{631}\u{629}',
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          const Text(
            '\u{644}\u{645} \u{64A}\u{62A}\u{645} \u{627}\u{62E}\u{62A}\u{64A}\u{627}\u{631} \u{635}\u{648}\u{631}\u{629}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('JPG  PNG  WEBP', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PricingDraftRow {
  ProductPricingType pricingType = ProductPricingType.unit;
  final TextEditingController unitNameController = TextEditingController(
    text: '',
  );
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController priceController = TextEditingController();
  final TextEditingController fractionController = TextEditingController();
  bool isActive = true;

  _PricingDraftRow();

  factory _PricingDraftRow.fromPricing(ProductPricing pricing) {
    final row = _PricingDraftRow()
      ..pricingType = pricing.pricingType
      ..isActive = pricing.isActive;

    row.unitNameController.text = pricing.unitName ?? '';
    row.quantityController.text = pricing.quantity?.toString() ?? '';
    row.priceController.text = pricing.price.toString();
    row.fractionController.text = pricing.fractionValue?.toString() ?? '';

    return row;
  }

  void dispose() {
    unitNameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    fractionController.dispose();
  }
}

class _PricingRowEditor extends StatefulWidget {
  final _PricingDraftRow row;
  final int index;
  final VoidCallback onRemove;

  const _PricingRowEditor({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_PricingRowEditor> createState() => _PricingRowEditorState();
}

class _PricingRowEditorState extends State<_PricingRowEditor> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ' ${widget.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip:
                      '\u{62D}\u{630}\u{641} \u{62E}\u{64A}\u{627}\u{631} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631}',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            DropdownButtonFormField<ProductPricingType>(
              initialValue: row.pricingType,
              decoration: const InputDecoration(
                labelText:
                    '\u{646}\u{648}\u{639} \u{627}\u{644}\u{62A}\u{633}\u{639}\u{64A}\u{631}',
              ),
              items: ProductPricingType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_pricingTypeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  row.pricingType = value;
                });
              },
            ),
            const SizedBox(height: 8),
            if (row.pricingType == ProductPricingType.unit ||
                row.pricingType == ProductPricingType.weight)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.unitNameController,
                      decoration: const InputDecoration(
                        labelText: '\u{627}\u{644}\u{648}\u{62D}\u{62F}\u{629}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '\u{627}\u{644}\u{643}\u{645}\u{64A}\u{629}',
                      ),
                    ),
                  ),
                ],
              ),
            if (row.pricingType == ProductPricingType.fraction)
              TextField(
                controller: row.fractionController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText:
                      '\u{642}\u{64A}\u{645}\u{629} \u{627}\u{644}\u{643}\u{633}\u{631}',
                  hintText: '\u{645}\u{62B}\u{627}\u{644}: 0.5',
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: row.priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '\u{627}\u{644}\u{633}\u{639}\u{631}',
                suffixText: '\u{62C}.\u{645}',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: row.isActive,
              onChanged: (value) {
                setState(() {
                  row.isActive = value;
                });
              },
              title: const Text(
                '\u{645}\u{62A}\u{627}\u{62D} \u{644}\u{644}\u{628}\u{64A}\u{639}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pricingTypeLabel(ProductPricingType type) {
    switch (type) {
      case ProductPricingType.unit:
        return '\u{628}\u{627}\u{644}\u{648}\u{62D}\u{62F}\u{629}';
      case ProductPricingType.weight:
        return '\u{628}\u{627}\u{644}\u{648}\u{632}\u{646}';
      case ProductPricingType.value:
        return '\u{62D}\u{633}\u{628} \u{627}\u{644}\u{642}\u{64A}\u{645}\u{629}';
      case ProductPricingType.fraction:
        return '\u{628}\u{627}\u{644}\u{643}\u{633}\u{631}';
    }
  }
}
