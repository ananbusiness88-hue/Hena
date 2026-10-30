import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer_billbay/thermal_printer_billbay.dart';

class StorePrinterSettings {
  final String? printerName;
  final String? printerAddress;
  final PaperSize paperSize;
  final CodePage codePage;

  const StorePrinterSettings({
    this.printerName,
    this.printerAddress,
    this.paperSize = PaperSize.mm80,
    this.codePage = CodePage.cp864,
  });

  bool get hasPrinter {
    return printerAddress?.trim().isNotEmpty == true;
  }
}

class StorePrinterSettingsService {
  final SharedPreferencesAsync _preferences;

  StorePrinterSettingsService({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  String _key(String storeId, String field) {
    return 'hena.store_printer.$storeId.$field';
  }

  Future<StorePrinterSettings> load(String storeId) async {
    final printerName = await _preferences.getString(
      _key(storeId, 'printer_name'),
    );

    final printerAddress = await _preferences.getString(
      _key(storeId, 'printer_address'),
    );

    final paperSizeKey = await _preferences.getString(
      _key(storeId, 'paper_size'),
    );

    final codePageKey = await _preferences.getString(
      _key(storeId, 'code_page'),
    );

    return StorePrinterSettings(
      printerName: printerName,
      printerAddress: printerAddress,
      paperSize: _paperSizeFromKey(paperSizeKey),
      codePage: _codePageFromKey(codePageKey),
    );
  }

  Future<void> save(
    String storeId, {
    required String printerName,
    required String printerAddress,
    required PaperSize paperSize,
    CodePage codePage = CodePage.utf8,  }) async {
    await _preferences.setString(
      _key(storeId, 'printer_name'),
      printerName,
    );

    await _preferences.setString(
      _key(storeId, 'printer_address'),
      printerAddress,
    );

    await _preferences.setString(
      _key(storeId, 'paper_size'),
      _paperSizeToKey(paperSize),
    );

    await _preferences.setString(
      _key(storeId, 'code_page'),
      _codePageToKey(codePage),
    );
  }

  Future<void> clear(String storeId) async {
    await _preferences.remove(_key(storeId, 'printer_name'));
    await _preferences.remove(_key(storeId, 'printer_address'));
    await _preferences.remove(_key(storeId, 'paper_size'));
    await _preferences.remove(_key(storeId, 'code_page'));
  }

  String _paperSizeToKey(PaperSize value) {
    switch (value) {
      case PaperSize.mm58:
        return 'mm58';
      case PaperSize.mm72:
        return 'mm72';
      case PaperSize.mm80:
        return 'mm80';
      case PaperSize.mm110:
        return 'mm110';
    }
  }

  PaperSize _paperSizeFromKey(String? value) {
    switch (value) {
      case 'mm58':
        return PaperSize.mm58;
      case 'mm72':
        return PaperSize.mm72;
      case 'mm110':
        return PaperSize.mm110;
      case 'mm80':
      default:
        return PaperSize.mm80;
    }
  }

  String _codePageToKey(CodePage value) {
    if (value == CodePage.utf8) return 'utf8';
    if (value == CodePage.utf8Alt) return 'utf8Alt';
    if (value == CodePage.win1256) return 'win1256';
    if (value == CodePage.cp864) return 'cp864';
    if (value == CodePage.cp720) return 'cp720';
    if (value == CodePage.pc437) return 'pc437';
    if (value == CodePage.win1252) return 'win1252';
    if (value == CodePage.pc850) return 'pc850';

    return 'utf8';
  }

  CodePage _codePageFromKey(String? value) {
    switch (value) {
      case 'utf8Alt':
        return CodePage.utf8Alt;
      case 'win1256':
        return CodePage.win1256;
      case 'cp864':
        return CodePage.cp864;
      case 'cp720':
        return CodePage.cp720;
      case 'pc437':
        return CodePage.pc437;
      case 'win1252':
        return CodePage.win1252;
      case 'pc850':
        return CodePage.pc850;
      case 'utf8':
      default:
        return CodePage.utf8;
    }
  }
}
