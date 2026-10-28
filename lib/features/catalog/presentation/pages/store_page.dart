import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_pricing.dart';
import '../providers/catalog_providers.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

class StorePage extends ConsumerWidget {
  final String storeId;
  final String storeName;

  const StorePage({super.key, required this.storeId, required this.storeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeByIdProvider(storeId));
    final categoriesAsync = ref.watch(
      activeProductCategoriesByStoreProvider(storeId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),

        actions: [
          Builder(
            builder: (context) {
              return Consumer(
                builder: (context, ref, child) {
                  final count = ref.watch(cartItemCountProvider);

                  return IconButton(
                    tooltip: '',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: '    ',
          error: error,
          onRetry: () {
            ref.invalidate(storeByIdProvider(storeId));
          },
        ),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('      '));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(storeByIdProvider(storeId));
              ref.invalidate(activeProductCategoriesByStoreProvider(storeId));
              ref.invalidate(activeProductsByStoreProvider(storeId));

              await ref.read(storeByIdProvider(storeId).future);
              await ref.read(
                activeProductCategoriesByStoreProvider(storeId).future,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _StoreHeader(
                  name: store.name,
                  description: store.description,
                  coverImageUrl: store.coverImageUrl,
                  logoUrl: store.logoUrl,
                  phone: store.phone,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u062a\u0635\u0646\u064a\u0641\u0627\u062a \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF20312B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      categoriesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stackTrace) => _ErrorView(
                          message: '     ',
                          error: error,
                          onRetry: () {
                            ref.invalidate(
                              activeProductCategoriesByStoreProvider(storeId),
                            );
                          },
                        ),
                        data: (categories) {
                          if (categories.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  '    .',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.88,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: categories
                                .map(
                                  (category) => _ProductCategorySection(
                                    category: category,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductCategorySection extends StatelessWidget {
  final ProductCategory category;

  const _ProductCategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        category.imageUrl != null && category.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _CategoryProductsPage(category: category),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDEAE4)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 112,
                child: hasImage
                    ? Image.network(
                        category.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _CategoryImageFallback(),
                      )
                    : const _CategoryImageFallback(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF20312B),
                              ),
                            ),
                            if (category.description != null &&
                                category.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                category.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF718079),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Color(0xFF23845D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryImageFallback extends StatelessWidget {
  const _CategoryImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE5F5EC), Color(0xFFE9F3FA)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.category_rounded, size: 43, color: Color(0xFF23845D)),
      ),
    );
  }
}

class _CategoryProductsPage extends ConsumerWidget {
  final ProductCategory category;

  const _CategoryProductsPage({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
      activeProductsByCategoryProvider(category.id),
    );
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'السلة',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CartPage()));
            },
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: 'تعذر تحميل منتجات التصنيف',
          error: error,
          onRetry: () {
            ref.invalidate(activeProductsByCategoryProvider(category.id));
          },
        ),
        data: (loadedProducts) {
          // Keep this page restricted to the selected category and its store.
          final products = loadedProducts
              .where(
                (product) =>
                    product.storeId == category.storeId &&
                    product.categoryId == category.id,
              )
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeProductsByCategoryProvider(category.id));
              for (final product in products) {
                ref.invalidate(activePricingByProductProvider(product.id));
              }
              await ref.read(
                activeProductsByCategoryProvider(category.id).future,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFE5F5EC), Color(0xFFE9F3FA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDEAE4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shopping_basket_outlined,
                          color: Color(0xFF23845D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF20312B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${products.length} منتج',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF718079),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 52,
                          color: Color(0xFF9BAAA2),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد منتجات متاحة في هذا التصنيف حاليًا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF718079),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...products.map((product) => _ProductCard(product: product)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingAsync = ref.watch(activePricingByProductProvider(product.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5E4DD), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF23483A).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _openProductSelection(context, ref, product);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Product image
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFF0F8F4), Color(0xFFEAF4FA)],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFDCEAE4)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _ProductImage(imageUrl: product.imageUrl),
                      ),
                      if (!product.isAvailable)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      if (!product.isAvailable)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD84343),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'نفذت الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),

                // Product information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F3029),
                        ),
                      ),

                      if (product.description != null &&
                          product.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          product.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Color(0xFF75847D),
                          ),
                        ),
                      ],

                      const SizedBox(height: 9),

                      pricingAsync.when(
                        loading: () => const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),

                        error: (error, stackTrace) => const Text(
                          '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0633\u0639\u0631',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB15C5C),
                          ),
                        ),

                        data: (pricing) {
                          if (pricing.isEmpty) {
                            return const Text(
                              '\u0644\u0627 \u064a\u0648\u062c\u062f \u0633\u0639\u0631 \u0645\u062a\u0627\u062d',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A9690),
                              ),
                            );
                          }

                          final firstPrice = pricing.first.price;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    firstPrice.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 21,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF19734D),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 1),
                                    child: Text(
                                      '\u062c\u0646\u064a\u0647',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF398060),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (pricing.length > 1) ...[
                                const SizedBox(height: 5),
                                const Text(
                                  '\u062a\u062a\u0648\u0641\u0631 \u062e\u064a\u0627\u0631\u0627\u062a \u062a\u0633\u0639\u064a\u0631 \u0623\u062e\u0631\u0649',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B8A83),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Add to cart
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF2AA978), Color(0xFF23845D)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF23845D).withValues(alpha: 0.20),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip:
                        '\u0625\u0636\u0627\u0641\u0629 \u0644\u0644\u0633\u0644\u0629',
                    padding: const EdgeInsets.all(11),
                    constraints: const BoxConstraints(
                      minWidth: 46,
                      minHeight: 46,
                    ),
                    onPressed: () {
                      pricingAsync.when(
                        data: (pricing) {
                          if (pricing.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u062a\u0633\u0639\u064a\u0631 \u0645\u062a\u0627\u062d \u0644\u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062a\u062c.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return _ProductSelectionSheet(
                                product: product,
                                pricing: pricing,
                                ref: ref,
                              );
                            },
                          );
                        },
                        loading: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('\u062c\u0627\u0631\u064a \u062a\u062d\u0645\u064a\u0644 \u0633\u0639\u0631 \u0627\u0644\u0645\u0646\u062a\u062c...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        error: (error, stackTrace) {
                          debugPrint('HENA: Product pricing failed: $error');
                          debugPrintStack(stackTrace: stackTrace);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0633\u0639\u0631. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProductSelection(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final pricing = await ref.read(
      activePricingByProductProvider(product.id).future,
    );

    if (!context.mounted) {
      return;
    }

    if (pricing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u0644\u0627 \u064a\u0648\u062c\u062f \u062a\u0633\u0639\u064a\u0631 \u0645\u062a\u0627\u062d \u0644\u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062a\u062c.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProductSelectionSheet(
          product: product,
          pricing: pricing,
          ref: ref,
        );
      },
    );
  }
}

class _ProductSelectionSheet extends StatefulWidget {
  final Product product;
  final List<ProductPricing> pricing;
  final WidgetRef ref;

  const _ProductSelectionSheet({
    required this.product,
    required this.pricing,
    required this.ref,
  });

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  ProductPricing? _selectedPricing;
  ProductPricingType? _selectedPricingType;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();

    if (widget.pricing.length == 1) {
      _selectedPricing = widget.pricing.first;
    }
  }

  Future<List<String>> _loadProductImageUrls() async {
    final storage = Supabase.instance.client.storage.from('product-images');

    final files = await storage.list(path: widget.product.id);

    final imageFiles =
        files
            .where((file) => RegExp(r'^[1-3]\.[^.]+$').hasMatch(file.name))
            .toList()
          ..sort((a, b) {
            final aNumber = int.parse(a.name.split('.').first);
            final bNumber = int.parse(b.name.split('.').first);
            return aNumber.compareTo(bNumber);
          });

    if (imageFiles.isEmpty) {
      final primary = widget.product.imageUrl;

      if (primary != null && primary.trim().isNotEmpty) {
        return [primary];
      }

      return [];
    }

    return imageFiles
        .map(
          (file) => storage.getPublicUrl('${widget.product.id}/${file.name}'),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pricingTypes = widget.pricing
        .map((pricing) => pricing.pricingType)
        .toSet()
        .toList();

    final hasMultipleTypes = pricingTypes.length > 1;
    final selectedType = _selectedPricingType;

    final visiblePricing = selectedType == null
        ? widget.pricing
        : widget.pricing
              .where((pricing) => pricing.pricingType == selectedType)
              .toList();

    final totalPrice = _selectedPricing == null
        ? 0.0
        : _selectedPricing!.price * _quantity;

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FBF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9D8D1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              FutureBuilder<List<String>>(
                future: _loadProductImageUrls(),
                builder: (context, snapshot) {
                  final urls = snapshot.data ?? const <String>[];

                  if (urls.isEmpty) {
                    return Container(
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEAF6F0), Color(0xFFEAF3F8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFD8E8E0)),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        size: 58,
                        color: Color(0xFF6C9A86),
                      ),
                    );
                  }

                  if (urls.length == 1) {
                    return Container(
                      height: 230,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCE8E2)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        urls.first,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 42,
                              color: Color(0xFF91A39A),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return SizedBox(
                    height: 230,
                    child: PageView.builder(
                      itemCount: urls.length,
                      controller: PageController(viewportFraction: 0.90),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFDCE8E2),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              urls[index],
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 42,
                                    color: Color(0xFF91A39A),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDCE8E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F3029),
                      ),
                    ),
                    if (widget.product.description != null &&
                        widget.product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        widget.product.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xFF718079),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (hasMultipleTypes) ...[
                _sectionTitle('اختر نوع التسعير', Icons.tune_rounded),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pricingTypes.map((type) {
                    final selected = selectedType == type;

                    return ChoiceChip(
                      label: Text(
                        _pricingTypeLabel(type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF315E4B),
                        ),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF23845D),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF23845D)
                            : const Color(0xFFD4E3DC),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedPricingType = type;
                          _selectedPricing = null;
                          _quantity = 1;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              if (hasMultipleTypes && selectedType == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F0),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD2E7DC)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Color(0xFF23845D),
                        size: 22,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'اختر نوع التسعير لعرض الخيارات المتاحة',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF416B58),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!hasMultipleTypes || selectedType != null) ...[
                if (visiblePricing.isNotEmpty) ...[
                  _sectionTitle(
                    _selectionTitle(selectedType),
                    Icons.sell_outlined,
                  ),
                  const SizedBox(height: 9),
                  _buildPricingOptions(context, visiblePricing),
                  const SizedBox(height: 14),
                ],

                if (_selectedPricing != null) ...[
                  _buildQuantitySelector(context),
                  const SizedBox(height: 14),
                  _buildTotal(context, totalPrice),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final pricing = _selectedPricing;
                        if (pricing == null) return;

                        try {
                          final current = await Supabase.instance.client
                              .from('products')
                              .select('is_available')
                              .eq('id', widget.product.id)
                              .maybeSingle();

                          if (!context.mounted) return;

                          if (current == null ||
                              current['is_available'] == false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Out of stock. This product cannot be ordered.'),
                              ),
                            );
                            Navigator.of(context).pop();
                            return;
                          }

                          final added = widget.ref
                              .read(cartProvider)
                              .addItem(
                                product: widget.product,
                                pricing: pricing,
                                quantity: _quantity.toDouble(),
                              );

                          if (!added) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This product is unavailable.'),
                              ),
                            );
                            return;
                          }

                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${widget.product.name} to cart',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not verify product availability. Please try again.'),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF23845D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text(
                        'إضافة للسلة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF23845D)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20312B),
            ),
          ),
        ),
      ],
    );
  }

  String _selectionTitle(ProductPricingType? type) {
    if (type == null) {
      return 'اختر الخيار المناسب';
    }

    switch (type) {
      case ProductPricingType.unit:
        return 'اختر الوحدة';

      case ProductPricingType.weight:
        return 'اختر الوزن';

      case ProductPricingType.value:
        return 'اختر القيمة';

      case ProductPricingType.fraction:
        return 'اختر الكمية';
    }
  }

  Widget _buildQuantitySelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFDCE8E2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.production_quantity_limits_rounded,
            size: 21,
            color: Color(0xFF4B6E5D),
          ),
          const SizedBox(width: 9),
          const Text(
            'الكمية',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF354B42),
            ),
          ),
          const Spacer(),
          _quantityButton(
            icon: Icons.remove_rounded,
            enabled: _quantity > 1,
            onPressed: () {
              setState(() {
                _quantity--;
              });
            },
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF20312B),
              ),
            ),
          ),
          _quantityButton(
            icon: Icons.add_rounded,
            enabled: true,
            onPressed: () {
              setState(() {
                _quantity++;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: enabled ? const Color(0xFFE7F4ED) : const Color(0xFFF0F3F1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? const Color(0xFF23845D) : const Color(0xFFADB8B3),
          ),
        ),
      ),
    );
  }

  Widget _buildTotal(BuildContext context, double totalPrice) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Color(0xFFE7F5ED), Color(0xFFEAF3F8)],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFD4E6DE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF23845D),
            size: 22,
          ),
          const SizedBox(width: 9),
          const Text(
            'الإجمالي',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF355447),
            ),
          ),
          const Spacer(),
          Text(
            '${_formatNumber(totalPrice)} جنيه',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF19734D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOptions(
    BuildContext context,
    List<ProductPricing> pricing,
  ) {
    return RadioGroup<ProductPricing>(
      groupValue: _selectedPricing,
      onChanged: (value) {
        setState(() {
          _selectedPricing = value;
          _quantity = 1;
        });
      },
      child: Column(
        children: pricing.map((option) {
          final selected = _selectedPricing?.id == option.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () {
                  setState(() {
                    _selectedPricing = option;
                    _quantity = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF23845D)
                          : const Color(0xFFD9E5DF),
                      width: selected ? 1.6 : 1,
                    ),
                    color: selected ? const Color(0xFFF0F9F4) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Radio<ProductPricing>(
                        value: option,
                        activeColor: const Color(0xFF23845D),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _pricingSelectionLabel(option),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2C4037),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatNumber(option.price)} جنيه',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? const Color(0xFF19734D)
                              : const Color(0xFF355A49),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _pricingSelectionLabel(ProductPricing pricing) {
    switch (pricing.pricingType) {
      case ProductPricingType.unit:
        if (pricing.unitName != null && pricing.unitName!.trim().isNotEmpty) {
          return pricing.unitName!;
        }

        return 'وحدة';

      case ProductPricingType.weight:
        if (pricing.quantity != null) {
          return '${_formatNumber(pricing.quantity!)} '
              '${pricing.unitName ?? ''}';
        }

        return pricing.unitName ?? 'وزن';

      case ProductPricingType.value:
        if (pricing.quantity != null) {
          return '${_formatNumber(pricing.quantity!)} '
              '${pricing.unitName ?? ''}';
        }

        return pricing.unitName ?? 'قيمة';

      case ProductPricingType.fraction:
        final fraction = pricing.fractionValue;

        if (fraction != null) {
          return '${_fractionLabel(fraction)} '
              '${pricing.unitName ?? ''}';
        }

        return pricing.unitName ?? 'كمية';
    }
  }

  String _fractionLabel(double value) {
    if (value == 0.125) {
      return '1/8';
    }

    if (value == 0.25) {
      return '1/4';
    }

    if (value == 0.5) {
      return '1/2';
    }

    if (value == 1) {
      return '1';
    }

    return _formatNumber(value);
  }

  String _pricingTypeLabel(ProductPricingType type) {
    switch (type) {
      case ProductPricingType.unit:
        return 'بالوحدة';

      case ProductPricingType.weight:
        return 'بالوزن';

      case ProductPricingType.value:
        return 'بالقيمة';

      case ProductPricingType.fraction:
        return 'بالكمية';
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        height: 76,
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) {
                  return const _Placeholder();
                },
              )
            : const _Placeholder(),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 32)),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final String name;
  final String? description;
  final String? coverImageUrl;
  final String? logoUrl;
  final String? phone;

  const _StoreHeader({
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.logoUrl,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDCE8E2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 205,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty)
                  Image.network(
                    coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const _StoreImagePlaceholder();
                    },
                  )
                else
                  const _StoreImagePlaceholder(),

                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.62),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 18,
                  right: 18,
                  left: 18,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            shadows: [
                              Shadow(blurRadius: 9, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: Color(0xFF2EAD74),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '\u0645\u062a\u0627\u062d \u0644\u0644\u0637\u0644\u0628',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF285443),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F0),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFD8E8E0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: logoUrl != null && logoUrl!.trim().isNotEmpty
                        ? Image.network(
                            logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF23845D),
                                size: 30,
                              );
                            },
                          )
                        : const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF23845D),
                            size: 30,
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description != null && description!.trim().isNotEmpty)
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF687A72),
                          ),
                        ),

                      if (phone != null && phone!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            textDirection: TextDirection.rtl,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF4FA),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.phone_rounded,
                                  size: 20,
                                  color: Color(0xFF317DA2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                phone!,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF244F61),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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

class _StoreImagePlaceholder extends StatelessWidget {
  const _StoreImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.store, size: 64)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(' '),
            ),
          ],
        ),
      ),
    );
  }
}
