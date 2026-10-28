import 'package:thermal_printer_billbay/thermal_printer_billbay.dart';

class StoreOrderPrintItem {
  final String productName;
  final String quantity;
  final double unitPrice;
  final double itemTotal;

  const StoreOrderPrintItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
  });
}

class StoreOrderPrintData {
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final List<StoreOrderPrintItem> items;
  final int itemCount;
  final double subtotal;
  final String status;
  final String? customerNote;

  const StoreOrderPrintData({
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.status,
    this.customerNote,
  });
}

class StoreOrderReceiptBuilder {
  const StoreOrderReceiptBuilder();

  List<int> build({
    required StoreOrderPrintData order,
    required PaperSize paperSize,
    required CodePage codePage,
  }) {
    final cmd = EscPosCommands(paperSize);

    cmd.initialize();
    cmd.setCodePage(codePage);

    cmd.textStyled(
      'Hena',
      const PosStyles(
        bold: true,
        align: PrintAlign.center,
      ),
      useLatin: true,
    );

    cmd.textStyled(
      'طلب #${order.orderNumber}',
      const PosStyles(
        bold: true,
        align: PrintAlign.center,
      ),
    );

    cmd.hr();

    cmd.setAlign(PrintAlign.right);
    cmd.textStyled(
      'العميل',
      const PosStyles(bold: true, align: PrintAlign.right),
    );

    cmd.textLn('الاسم: ${order.customerName}');

    cmd.textLn(
      order.customerPhone.trim().isEmpty
          ? 'الهاتف: غير متاح'
          : 'الهاتف: ${order.customerPhone}',
    );

    cmd.textLn(
      order.deliveryAddress.trim().isEmpty
          ? 'العنوان: غير متاح'
          : 'العنوان: ${order.deliveryAddress}',
    );

    cmd.newLine();

    cmd.textStyled(
      'منتجات متجرك',
      const PosStyles(bold: true, align: PrintAlign.right),
    );

    for (final item in order.items) {
      cmd.textStyled(
        item.productName,
        const PosStyles(bold: true, align: PrintAlign.right),
      );

      cmd.textLn(
        '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} جنيه',
      );

      cmd.leftRight(
        'الإجمالي',
        '${item.itemTotal.toStringAsFixed(2)} جنيه',
      );

      cmd.newLine();
    }

    cmd.hr();

    cmd.textStyled(
      'ملخص المحل',
      const PosStyles(bold: true, align: PrintAlign.right),
    );

    cmd.leftRight(
      'عدد المنتجات',
      '${order.itemCount}',
    );

    cmd.leftRight(
      'قيمة المحل',
      '${order.subtotal.toStringAsFixed(2)} جنيه',
    );

    cmd.leftRight(
      'الحالة',
      order.status,
    );

    final note = order.customerNote?.trim() ?? '';
    if (note.isNotEmpty) {
      cmd.newLine();
      cmd.textStyled(
        'ملاحظات العميل',
        const PosStyles(bold: true, align: PrintAlign.right),
      );
      cmd.textLn(note);
    }

    cmd.feedAndCut(lines: 3);

    return cmd.getBytes();
  }
}