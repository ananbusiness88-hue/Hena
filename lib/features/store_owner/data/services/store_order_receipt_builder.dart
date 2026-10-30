import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:thermal_printer_billbay/thermal_printer_billbay.dart';

class StoreOrderPrintItem {
  final String productName;
  final String quantity;
  final double unitPrice;

  /// The extra per-unit surcharge that was charged with this item.
  final double additionalFee;
  final double itemTotal;

  const StoreOrderPrintItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.additionalFee = 0,
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

  Future<List<int>> build({
    required StoreOrderPrintData order,
    required PaperSize paperSize,
  }) async {
    final width = paperSize.maxDotWidth;
    final contentWidth = (width - 32).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rows = <_ReceiptRow>[];

    void add(
      String text, {
      double fontSize = 24,
      bool bold = false,
      TextAlign align = TextAlign.right,
      double gapBefore = 0,
      double gapAfter = 5,
    }) {
      rows.add(
        _ReceiptRow(
          text: text,
          fontSize: fontSize,
          bold: bold,
          align: align,
          gapBefore: gapBefore,
          gapAfter: gapAfter,
        ),
      );
    }

    void addSeparator() {
      add('', fontSize: 18, align: TextAlign.center,
          gapBefore: 5, gapAfter: 9);
    }

    void addPair(String label, String value) {
      add('$label: $value', fontSize: 21, gapAfter: 7);
    }

    add('Hena', fontSize: 34, bold: true, align: TextAlign.center,
        gapAfter: 8);
    add('طلب رقم ${order.orderNumber}',
        fontSize: 27, bold: true, align: TextAlign.center, gapAfter: 12);

    addSeparator();

    add('بيانات العميل', fontSize: 25, bold: true, gapAfter: 8);
    addPair('الاسم', order.customerName);
    addPair(
      'الهاتف',
      order.customerPhone.trim().isEmpty
          ? 'غير متاح'
          : order.customerPhone,
    );
    addPair(
      'العنوان',
      order.deliveryAddress.trim().isEmpty
          ? 'غير متاح'
          : order.deliveryAddress,
    );

    addSeparator();

    add('منتجات المتجر', fontSize: 25, bold: true, gapAfter: 10);

    for (final item in order.items) {
      add(item.productName, fontSize: 24, bold: true, gapAfter: 5);
      add(
        '${item.quantity}  ${item.unitPrice.toStringAsFixed(2)} جنيه',
        fontSize: 21,
        gapAfter: 5,
      );

      if (item.additionalFee > 0) {
        add(
          'رسوم إضافية: ${item.additionalFee.toStringAsFixed(2)} جنيه',
          fontSize: 21,
          gapAfter: 5,
        );
      }

      add(
        'الإجمالي: ${item.itemTotal.toStringAsFixed(2)} جنيه',
        fontSize: 21,
        bold: true,
        gapAfter: 12,
      );
    }

    addSeparator();

    add('ملخص الطلب', fontSize: 25, bold: true, gapAfter: 9);
    addPair('عدد المنتجات', '');
    addPair('قيمة الطلب', '${order.subtotal.toStringAsFixed(2)} جنيه');
    addPair('الحالة', order.status);

    final note = order.customerNote?.trim() ?? '';
    if (note.isNotEmpty) {
      addSeparator();
      add('ملاحظات العميل', fontSize: 24, bold: true);
      add(note, fontSize: 21, gapAfter: 10);
    }

    const bottomPadding = 28.0;
    var totalHeight = bottomPadding + 12.0;
    final painters = <TextPainter>[];

    for (final row in rows) {
      final painter = TextPainter(
        text: TextSpan(
          text: row.text,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontSize: row.fontSize,
            fontWeight: row.bold ? FontWeight.bold : FontWeight.normal,
            height: 1.25,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: row.align,
      );

      painter.layout(maxWidth: contentWidth);
      painters.add(painter);
      totalHeight += row.gapBefore + painter.height + row.gapAfter;
    }

    final imageHeight = totalHeight.ceil();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), imageHeight.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    var y = 10.0;

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final painter = painters[index];

      y += row.gapBefore;
      painter.paint(canvas, Offset(16, y));
      y += painter.height + row.gapAfter;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, imageHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Failed to render receipt image.');
    }

    final pngBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    final cmd = EscPosCommands(paperSize);
    cmd.initialize();
    cmd.printImage(
      Uint8List.fromList(pngBytes),
      maxWidth: width,
      threshold: 160,
      align: PrintAlign.center,
    );
    cmd.feedAndCut(lines: 3);

    return cmd.getBytes();
  }
}

class _ReceiptRow {
  final String text;
  final double fontSize;
  final bool bold;
  final TextAlign align;
  final double gapBefore;
  final double gapAfter;

  const _ReceiptRow({
    required this.text,
    required this.fontSize,
    required this.bold,
    required this.align,
    required this.gapBefore,
    required this.gapAfter,
  });
}



