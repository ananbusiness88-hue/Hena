import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../providers/catalog_providers.dart';
import 'store_page.dart';

class ProductSearchPage extends ConsumerWidget {
  final String query;

  const ProductSearchPage({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedQuery = query.trim();
    final resultsAsync = ref.watch(
      searchActiveProductsProvider(normalizedQuery),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '\u0646\u062a\u0627\u0626\u062c \u0627\u0644\u0628\u062d\u062b',
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56),
                const SizedBox(height: 14),
                const Text(
                  '\u062d\u0635\u0644 \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0644\u0628\u062d\u062b',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      '\u0645\u0641\u064a\u0634 \u0646\u062a\u0627\u0626\u062c \u0644\u0640 "\$normalizedQuery"',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(searchActiveProductsProvider(normalizedQuery));
              await ref.read(
                searchActiveProductsProvider(normalizedQuery).future,
              );
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _SearchResultCard(product: products[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends ConsumerWidget {
  final Product product;

  const _SearchResultCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final store = await ref.read(
            storeByIdProvider(product.storeId).future,
          );

          if (!context.mounted) {
            return;
          }

          if (store == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '\u0627\u0644\u0645\u062a\u062c\u0631 \u063a\u064a\u0631 \u0645\u062a\u0627\u062d \u062d\u0627\u0644\u064a\u064b\u0627',
                ),
              ),
            );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  StorePage(storeId: store.id, storeName: store.name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _SearchProductImage(imageUrl: product.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${product.price.toStringAsFixed(2)} \u062c\u0646\u064a\u0647',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchProductImage extends StatelessWidget {
  final String? imageUrl;

  const _SearchProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        height: 82,
        child: imageUrl == null || imageUrl!.trim().isEmpty
            ? const ColoredBox(
                color: Color(0xFFF1F5F2),
                child: Icon(Icons.image_outlined, color: Color(0xFF8B9A92)),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const ColoredBox(
                    color: Color(0xFFF1F5F2),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF8B9A92),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
