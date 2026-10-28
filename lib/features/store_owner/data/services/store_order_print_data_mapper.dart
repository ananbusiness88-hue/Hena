import '../../domain/entities/store_order_part.dart';
import 'store_order_receipt_builder.dart';

class StoreOrderPrintDataMapper {
  const StoreOrderPrintDataMapper();

  StoreOrderPrintData build({
    required StoreOrderPart part,
    required List<Map<String, dynamic>> items,
  }) {
    return StoreOrderPrintData(
      orderNumber: _orderNumber(part),
      customerName: part.customerName,
      customerPhone: part.customerPhone,
      deliveryAddress: part.deliveryAddress,
      items: items.map(_mapItem).toList(growable: false),
      itemCount: part.itemCount,
      subtotal: part.subtotal,
      status: part.status.name,
      customerNote: part.customerNote,
    );
  }

  String _orderNumber(StoreOrderPart part) {
    final number = part.unifiedOrderNumber?.trim() ?? '';
    if (number.isNotEmpty) {
      return number;
    }

    return part.orderId.length >= 8
        ? part.orderId.substring(0, 8).toUpperCase()
        : part.orderId.toUpperCase();
  }
  StoreOrderPrintItem _mapItem(Map<String, dynamic> item) {
    final quantity = _formatQuantity(item['quantity']);
    final unitPrice = _toDouble(item['unit_price']);
    final itemTotal = _toDouble(item['item_total']);

    return StoreOrderPrintItem(
      productName: item['product_name']?.toString() ?? '',
      quantity: quantity,
      unitPrice: unitPrice,
      itemTotal: itemTotal,
    );
  }

  String _formatQuantity(dynamic value) {
    if (value is num) {
      final d = value.toDouble();

      if (d == d.roundToDouble()) {
        return d.toInt().toString();
      }

      return d.toStringAsFixed(2);
    }

    return value?.toString() ?? '0';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}