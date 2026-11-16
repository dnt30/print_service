import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_service/src/app.dart';
import 'package:print_service/src/print_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('id.printservice/native');
  late List<MethodCall> calls;
  late Map<String, dynamic> state;

  setUp(() {
    calls = [];
    state = {
      'bluetoothEnabled': true,
      'permissionGranted': true,
      'serviceEnabled': true,
      'paperMm': 58,
      'printers': [
        {'address': '00:11:22:33:44:55', 'name': 'POS Test'},
      ],
      'selectedAddress': '00:11:22:33:44:55',
      'records': [],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getState':
              return state;
            case 'getPairedPrinters':
              return state['printers'];
            case 'setPreferences':
              state.addAll(Map<String, dynamic>.from(call.arguments as Map));
              return null;
            case 'printText':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('navigation and responsive layout at $width px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const PrintServiceApp());
      await tester.pumpAndSettle();
      expect(find.text('Cetak dari browser Anda.'), findsOneWidget);
      expect(find.text('POS Test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Printer', 'Riwayat', 'Pengaturan', 'Beranda']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow on $label at $width',
        );
      }
    });
  }

  testWidgets('print dialog sends selected paper, copies, and text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PrintServiceApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tes printer'));
    await tester.tap(find.text('Tes printer'));
    await tester.pumpAndSettle();
    expect(find.text('Tes cetak printer'), findsOneWidget);
    await tester.tap(find.text('80 mm').last);
    await tester.tap(find.byTooltip('Tambah salinan'));
    await tester.ensureVisible(find.text('Cetak sekarang'));
    await tester.tap(find.text('Cetak sekarang'));
    await tester.pumpAndSettle();
    final job =
        calls.singleWhere((c) => c.method == 'printText').arguments as Map;
    expect(job['paperMm'], 80);
    expect(job['copies'], 2);
    expect(job['text'], sampleReceipt);
    expect(job['address'], '00:11:22:33:44:55');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bluetooth failure remains visible in print dialog', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getState') return state;
          if (call.method == 'printText') {
            throw PlatformException(
              code: 'print_failed',
              message: 'Printer tidak merespons.',
            );
          }
          return null;
        });
    await tester.pumpWidget(const PrintServiceApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tes printer'));
    await tester.tap(find.text('Tes printer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cetak sekarang'));
    await tester.tap(find.text('Cetak sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Printer tidak merespons.'), findsOneWidget);
    expect(find.text('Tes cetak printer'), findsOneWidget);
  });

  test('invalid website URL is rejected before native navigation', () async {
    final controller = PrintController();
    await expectLater(
      controller.openWebsite('javascript:alert(1)'),
      throwsFormatException,
    );
    await expectLater(
      controller.openWebsite('file:///kasir.html'),
      throwsFormatException,
    );
    expect(calls, isEmpty);
    controller.dispose();
  });

  test('website is passed to the external browser channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PrintController();
    await controller.openWebsite('http://192.168.1.10/kasir');
    final call = calls.singleWhere(
      (item) => item.method == 'openExternalWebsite',
    );
    expect(call.arguments, {'url': 'http://192.168.1.10/kasir'});
    expect(calls.any((item) => item.method == 'openWebsite'), isFalse);
    controller.dispose();
  });

  testWidgets('home explains external printing and opens system settings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const PrintServiceApp());
    await tester.pumpAndSettle();
    expect(find.text('Chrome & browser lain'), findsOneWidget);
    await tester.ensureVisible(find.text('Buka pengaturan cetak →'));
    await tester.tap(find.text('Buka pengaturan cetak →'));
    await tester.pumpAndSettle();
    expect(calls.any((item) => item.method == 'openPrintSettings'), isTrue);
    expect(find.text('Coba halaman contoh'), findsNothing);
  });

  test(
    'a second print is rejected while the first job is still sending',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final pending = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getState') return state;
            if (call.method == 'printText') await pending.future;
            return null;
          });
      final controller = PrintController();
      await controller.refresh();
      final first = controller.printText('Uji', 58, 1);
      await expectLater(
        controller.printText('Duplikat', 58, 1),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'printer_busy',
          ),
        ),
      );
      pending.complete();
      await first;
      expect(controller.working, isFalse);
      controller.dispose();
    },
  );

  testWidgets('print dialog fits landscape while the keyboard is open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PrintServiceApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cetak teks'));
    await tester.tap(find.text('Cetak teks'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
