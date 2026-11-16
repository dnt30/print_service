import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class PrintController extends ChangeNotifier {
  static const _channel = MethodChannel('id.printservice/native');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool loading = true;
  bool working = false;
  bool bluetoothEnabled = false;
  bool permissionGranted = false;
  bool serviceEnabled = false;
  int paperMm = 58;
  bool cutPaper = false;
  String? selectedAddress;
  String website = '';
  String? error;
  List<PrinterDevice> printers = [];
  List<PrintRecord> records = [];

  PrinterDevice? get selectedPrinter {
    for (final printer in printers) {
      if (printer.address == selectedAddress) return printer;
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!supported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Cetak Bluetooth tersedia di aplikasi Android. Pasang APK untuk menghubungkan printer.',
      );
    }
    return _channel.invokeMethod<T>(method, args);
  }

  Future<void> refresh() async {
    try {
      if (supported) {
        final raw = await _invoke<Map>('getState');
        final map = Map<String, dynamic>.from(raw!);
        bluetoothEnabled = map['bluetoothEnabled'] == true;
        permissionGranted = map['permissionGranted'] == true;
        serviceEnabled = map['serviceEnabled'] == true;
        paperMm = map['paperMm'] == 80 ? 80 : 58;
        cutPaper = map['cutPaper'] == true;
        selectedAddress = map['selectedAddress'] as String?;
        website = map['website'] as String? ?? '';
        printers = (map['printers'] as List? ?? [])
            .map(
              (e) => PrinterDevice.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        records = (map['records'] as List? ?? [])
            .map(
              (e) => PrintRecord.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'Data aplikasi tidak dapat dimuat.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<PrinterDevice>> pairedPrinters() async {
    final items = await _invoke<List>('getPairedPrinters') ?? [];
    return items
        .map((e) => PrinterDevice.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> selectPrinter(PrinterDevice printer) async {
    await _invoke<void>('selectPrinter', {
      'address': printer.address,
      'name': printer.name,
    });
    await refresh();
  }

  Future<void> forgetPrinter(String address) async {
    await _invoke<void>('forgetPrinter', {'address': address});
    await refresh();
  }

  Future<void> setPreferences({int? paper, bool? cut, String? url}) async {
    if (supported) {
      await _invoke<void>('setPreferences', {
        'paperMm': ?paper,
        'cutPaper': ?cut,
        'website': ?url,
      });
    }
    if (paper != null) paperMm = paper;
    if (cut != null) cutPaper = cut;
    if (url != null) website = url;
    notifyListeners();
  }

  Future<void> printText(String text, int paper, int copies) async {
    if (working) {
      throw PlatformException(
        code: 'printer_busy',
        message: 'Cetakan sebelumnya masih dikirim. Tunggu hingga selesai.',
      );
    }
    working = true;
    notifyListeners();
    try {
      await _invoke<void>('printText', {
        'text': text,
        'paperMm': paper,
        'copies': copies,
        'address': selectedAddress,
        'title': 'Cetak teks',
      });
    } finally {
      working = false;
      await refresh();
    }
  }

  Future<void> openWebsite(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Masukkan alamat website HTTP atau HTTPS yang valid.',
      );
    }
    await setPreferences(url: uri.toString());
    await _invoke<void>('openExternalWebsite', {'url': uri.toString()});
  }

  Future<void> openBluetoothSettings() =>
      _invoke<void>('openBluetoothSettings');
  Future<void> openPrintSettings() => _invoke<void>('openPrintSettings');

  Future<void> clearRecords() async {
    await _invoke<void>('clearRecords');
    await refresh();
  }
}
