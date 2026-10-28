import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/cart_item.dart';

final cartProvider = ChangeNotifierProvider<CartState>((ref) {
  return CartState();
});

final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).items;
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});
