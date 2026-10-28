import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cart_item.dart';
import '../providers/cart_provider.dart';
import '../../../checkout/presentation/pages/checkout_page.dart';
import '../../../catalog/presentation/pages/store_categories_page.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _pricingLabel(CartItem item) {
    final pricing = item.pricing;

    if (pricing.unitName != null && pricing.unitName!.isNotEmpty) {
      switch (pricing.pricingType.name) {
        case 'unit':
          return pricing.unitName!;

        case 'weight':
          return '\u0628\u0627\u0644\u0643\u064a\u0644\u0648';

        case 'value':
          return '\u0628\u0627\u0644\u0642\u064a\u0645\u0629';

        case 'fraction':
          if (pricing.fractionValue != null) {
            final fraction = pricing.fractionValue!;

            if (fraction == 0.25) {
              return '\u0631\u0628\u0639 \u0643\u064a\u0644\u0648';
            }

            if (fraction == 0.5) {
              return '\u0646\u0635\u0641 \u0643\u064a\u0644\u0648';
            }

            if (fraction == 1.0) {
              return '\u0643\u064a\u0644\u0648';
            }

            return '${_formatNumber(fraction)} \u0643\u062c\u0645';
          }

          return pricing.unitName!;
      }
    }

    return pricing.pricingType.name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(title: const Text('\u0627\u0644\u0633\u0644\u0629')),
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('\u0627\u0644\u0633\u0644\u0629 \u0641\u0627\u0631\u063a\u0629', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child:
                                          item.product.imageUrl != null &&
                                              item.product.imageUrl!
                                                  .trim()
                                                  .isNotEmpty
                                          ? Image.network(
                                              item.product.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.image_outlined,
                                              size: 32,
                                            ),
                                    ),
                                  ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(_pricingLabel(item)),
                              const SizedBox(height: 4),
                              Text('${_formatNumber(item.pricing.price)} \u062c.\u0645'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.10),
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      shape: const CircleBorder(),
                                    ),
                                    onPressed: () {
                                      cart.decrease(item.uniqueKey);
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _formatNumber(item.quantity),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.10),
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      shape: const CircleBorder(),
                                    ),
                                    onPressed: () {
                                      cart.increase(item.uniqueKey);
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_formatNumber(item.totalPrice)} \u062c.\u0645',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    tooltip: '\u062d\u0630\u0641',
                                    onPressed: () {
                                      cart.remove(item.uniqueKey);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${_formatNumber(cart.subtotal)} \u062c.\u0645',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              final completed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutPage(),
                                ),
                              );

                              if (!context.mounted) {
                                return;
                              }

                              if (completed == true) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const StoreCategoriesPage(
                                      initialNavIndex: 2,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                             child: const Text('\u0625\u062a\u0645\u0627\u0645 \u0627\u0644\u0637\u0644\u0628'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
