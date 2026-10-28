import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/offer.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_pricing.dart';
import '../providers/catalog_providers.dart';

class OffersPage extends ConsumerWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: offersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _OffersErrorView(
          error: error,
          onRetry: () {
            ref.invalidate(activeOffersProvider);
          },
        ),
        data: (offers) {
          if (offers.isEmpty) {
            return const _OffersEmptyView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeOffersProvider);
              await ref.read(activeOffersProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _OfferCard(
                  offer: offers[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  final Offer offer;

  const _OfferCard({
    required this.offer,
  });

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(
      productByIdProvider(widget.offer.productId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: productAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '    ',
          ),
        ),
        data: (product) {
          if (product == null || !product.isActive) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '     ',
              ),
            );
          }

          return _buildCard(
            context,
            product,
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Product product,
  ) {
    final pricingAsync = ref.watch(
      activePricingByProductProvider(product.id),
    );

    return pricingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '    ',
        ),
      ),
      data: (pricingList) {
        ProductPricing? pricing;

        for (final item in pricingList) {
          if (item.id == widget.offer.pricingId) {
            pricing = item;
            break;
          }
        }

        final selectedPricing = pricing;

        if (selectedPricing == null || !selectedPricing.isActive) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '      ',
            ),
          );
        }

        final imageUrl = widget.offer.imageUrl;
        final description = widget.offer.description;
        final totalPrice = widget.offer.offerPrice * _quantity;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl?.trim().isNotEmpty ?? false)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return const _OfferImagePlaceholder();
                      },
                    ),
                  ),
                )
              else
                const _OfferImagePlaceholder(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.offer.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ' ${widget.offer.discountPercentage.round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.offer.offerPrice.toStringAsFixed(2)} .',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.offer.originalPrice.toStringAsFixed(2)} .',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _pricingLabel(selectedPricing),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quantity++;
                      });
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ': ${totalPrice.toStringAsFixed(2)} .',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(cartProvider).addItem(
                        product: product,
                        pricing: selectedPricing,
                        offer: widget.offer,
                        quantity: _quantity.toDouble(),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '  ${product.name}  ',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text(' '),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _pricingLabel(ProductPricing pricing) {
    switch (pricing.pricingType) {
      case ProductPricingType.unit:
        if (pricing.unitName != null &&
            pricing.unitName!.trim().isNotEmpty) {
          return ' : ${pricing.unitName}';
        }
        return ' : ';

      case ProductPricingType.weight:
        if (pricing.unitName != null &&
            pricing.unitName!.trim().isNotEmpty) {
          return ' : ${pricing.unitName}';
        }
        return ' : ';

      case ProductPricingType.value:
        return ' : ';

      case ProductPricingType.fraction:
        final fraction = pricing.fractionValue;

        if (fraction == 0.25) {
          return ' :  ';
        }

        if (fraction == 0.5) {
          return ' :  ';
        }

        if (fraction == 1) {
          return ' : 1 ';
        }

        return ' :  ';
    }
  }
}

class _OfferImagePlaceholder extends StatelessWidget {
  const _OfferImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Center(
        child: Icon(
          Icons.local_offer_outlined,
          size: 56,
        ),
      ),
    );
  }
}

class _OffersEmptyView extends StatelessWidget {
  const _OffersEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '    ',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _OffersErrorView({
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
            const Icon(
              Icons.error_outline,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              '    ',
              textAlign: TextAlign.center,
            ),
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
