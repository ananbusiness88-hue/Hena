import 'package:flutter/foundation.dart';

import '../../../catalog/domain/entities/offer.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/product_pricing.dart';

class CartItem {
  final Product product;
  final ProductPricing pricing;
  final Offer? offer;
  final double quantity;

  const CartItem({
    required this.product,
    required this.pricing,
    this.offer,
    required this.quantity,
  });

  double get unitPrice {
    return offer?.offerPrice ?? pricing.price;
  }

  double get totalPrice {
    return unitPrice * quantity;
  }

  String get uniqueKey {
    if (offer != null) {
      return '${product.id}_${pricing.id}_offer_${offer!.id}';
    }

    return '${product.id}_${pricing.id}';
  }

  CartItem copyWith({
    double? quantity,
    Offer? offer,
  }) {
    return CartItem(
      product: product,
      pricing: pricing,
      offer: offer ?? this.offer,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _storeId;

  String? get storeId => _storeId;

  List<CartItem> get items => List.unmodifiable(_items.values);

  int get itemCount => _items.length;

  bool get isEmpty => _items.isEmpty;

  double get subtotal {
    return _items.values.fold<double>(
      0.0,
      (total, item) => total + item.totalPrice,
    );
  }

  bool addItem({
    required Product product,
    required ProductPricing pricing,
    Offer? offer,
    double quantity = 1.0,
  }) {
    if (!product.isAvailable) {
      return false;
    }
    //          .
    //      .
    _storeId = null;

    final item = CartItem(
      product: product,
      pricing: pricing,
      offer: offer,
      quantity: quantity,
    );

    final key = item.uniqueKey;
    final existing = _items[key];

    if (existing != null) {
      _items[key] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _items[key] = item;
    }

    notifyListeners();
    return true;
  }

  void increase(String key) {
    final item = _items[key];

    if (item == null) {
      return;
    }

    _items[key] = item.copyWith(
      quantity: item.quantity + 1.0,
    );

    notifyListeners();
  }

  void decrease(String key) {
    final item = _items[key];

    if (item == null) {
      return;
    }

    if (item.quantity <= 1.0) {
      _items.remove(key);

      if (_items.isEmpty) {
        _storeId = null;
      }
    } else {
      _items[key] = item.copyWith(
        quantity: item.quantity - 1.0,
      );
    }

    notifyListeners();
  }

  void remove(String key) {
    _items.remove(key);

    if (_items.isEmpty) {
      _storeId = null;
    }

    notifyListeners();
  }

  void clear() {
    _items.clear();
    _storeId = null;
    notifyListeners();
  }
}
