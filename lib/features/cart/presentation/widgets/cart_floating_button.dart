import '../../../catalog/presentation/pages/store_categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/cart_page.dart';
import '../providers/cart_provider.dart';

class CartFloatingButton extends ConsumerWidget {
  const CartFloatingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);

    return FloatingActionButton.extended(
      heroTag: 'hena_cart_button',
      onPressed: () async {
        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const CartPage(),
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
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart),
      ),
      label: const Text(''),
    );
  }
}
