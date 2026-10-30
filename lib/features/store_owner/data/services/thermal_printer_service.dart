import 'dart:typed_data';

import 'package:thermal_printer_billbay/thermal_printer_billbay.dart';

import '../../domain/entities/store_order_part.dart';
import 'store_order_print_data_mapper.dart';
import 'store_order_receipt_builder.dart';

class ThermalPrinterService {
  final ThermalPrinterManager _printer;

  ThermalPrinterService({ThermalPrinterManager? printer})
      : _printer = printer ?? ThermalPrinterManager();

  Future<bool> prepare() async {
    return _printer.ensureReady();
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return _printer.getBondedDevices();
  }

  Future<bool> connect(String address) async {
    return _printer.connectWithRetry(address);
  }

  Future<bool> printBytes({
    required String address,
    required Uint8List bytes,
  }) async {
    final ready = await prepare();
    if (!ready) return false;

    final connected =
        _printer.isConnected || await _printer.connectWithRetry(address);

    if (!connected) return false;

    return _printer.sendBytes(bytes);
  }

  Future<bool> printStoreOrder({
    required String address,
    required StoreOrderPart part,
    required List<Map<String, dynamic>> items,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    const mapper = StoreOrderPrintDataMapper();

    final order = mapper.build(
      part: part,
      items: items,
    );

    return printReceipt(
      address: address,
      order: order,
      paperSize: paperSize,
    );
  }
  Future<bool> printReceipt({
    required String address,
    required StoreOrderPrintData order,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    final builder = const StoreOrderReceiptBuilder();

    final bytes = await builder.build(
      order: order,
      paperSize: paperSize,
    );

    return printBytes(
      address: address,
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<void> disconnect() async {
    if (_printer.isConnected) {
      await _printer.disconnect();
    }
  }

  void dispose() {
    _printer.dispose();
  }
}


