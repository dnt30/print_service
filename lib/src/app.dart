import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'print_controller.dart';

const ink = Color(0xFF183C3A);
const teal = Color(0xFF087F72);
const muted = Color(0xFF6F7E7B);
const canvas = Color(0xFFF5F7F5);
const line = Color(0xFFE1E8E4);

const sampleReceipt = '''TOKO ANDA
Struk uji printer
--------------------------------
Kopi susu              Rp 18.000
Roti panggang          Rp 15.000
--------------------------------
TOTAL                  Rp 33.000

Terima kasih!
Printer siap digunakan.''';

class PrintServiceApp extends StatelessWidget {
  const PrintServiceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Print Service',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: Colors.white),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFDDF1EA),
      ),
    ),
    home: const PrintHome(),
  );
}

class PrintHome extends StatefulWidget {
  const PrintHome({super.key});

  @override
  State<PrintHome> createState() => _PrintHomeState();
}

class _PrintHomeState extends State<PrintHome> with WidgetsBindingObserver {
  final controller = PrintController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is PlatformException
                ? e.message ?? 'Proses gagal. Coba kembali.'
                : e.toString().replaceFirst('FormatException: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> choosePrinter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => PrinterPicker(controller: controller),
    );
    await controller.refresh();
  }

  Future<void> showPrint({bool test = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => PrintSheet(
        controller: controller,
        test: test,
        choosePrinter: choosePrinter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        const destinations = [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            label: 'Printer',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Pengaturan',
          ),
        ];
        final content = SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? 40 : 20,
                24,
                wide ? 40 : 20,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 30),
                      if (!controller.supported) ...[
                        const Notice(
                          icon: Icons.phone_android_rounded,
                          text: 'Mode pratinjau. Koneksi Bluetooth dan layanan cetak berjalan di aplikasi Android.',
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (controller.error != null) ...[
                        Notice(
                          icon: Icons.error_outline,
                          text: controller.error!,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (controller.loading) const LinearProgressIndicator(),
                      switch (tab) {
                        0 => _dashboard(),
                        1 => _printers(),
                        2 => _history(),
                        _ => _settings(),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: tab,
                      onDestinationSelected: (value) =>
                          setState(() => tab = value),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.white,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: BrandMark(),
                      ),
                      destinations: destinations
                          .map(
                            (d) => NavigationRailDestination(
                              icon: d.icon,
                              label: Text(d.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (value) => setState(() => tab = value),
                  destinations: destinations,
                ),
        );
      },
    ),
  );

  Widget _header() => Row(
    children: [
      const BrandMark(),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Print Service',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'BLUETOOTH · POS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Panduan cetak',
        onPressed: _help,
        icon: const Icon(Icons.help_outline_rounded, color: muted),
      ),
    ],
  );

  Widget _dashboard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Cetak dari browser Anda.',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Kirim struk dari Chrome atau browser lain ke printer Bluetooth melalui dialog cetak Android.',
        style: TextStyle(color: muted, fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 26),
      _serviceCard(),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, box) {
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _websiteCard(),
              const SizedBox(height: 20),
              _primaryPrinter(),
              const SizedBox(height: 20),
              _quickActions(),
            ],
          );
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_paperCard()],
          );
          if (box.maxWidth < 760) {
            return Column(children: [left, const SizedBox(height: 20), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: right),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Aktivitas terakhir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => tab = 2),
            child: const Text('Lihat semua'),
          ),
        ],
      ),
      if (controller.records.isEmpty)
        const Panel(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada cetakan',
            subtitle: 'Riwayat akan muncul setelah Anda mengirim cetakan.',
          ),
        )
      else
        Panel(
          child: Column(
            children: controller.records.take(3).map(_recordTile).toList(),
          ),
        ),
    ],
  );

  Widget _primaryPrinter() {
    final printer = controller.selectedPrinter;
    return Panel(
      color: ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bluetooth_rounded,
                color: Color(0xFF91DFCF),
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PRINTER UTAMA',
                  style: TextStyle(
                    color: Color(0xFFB1CCC5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (printer != null)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF91DFCF),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer?.name ?? 'Hubungkan printer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      printer?.address ?? 'Pilih printer Bluetooth POS Anda',
                      style: const TextStyle(
                        color: Color(0xFFB1CCC5),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    if (printer != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Koneksi dibuat saat mencetak',
                          style: TextStyle(
                            color: Color(0xFF91DFCF),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD5F3E8),
                foregroundColor: ink,
              ),
              onPressed: controller.working ? null : choosePrinter,
              icon: Icon(
                printer == null ? Icons.add_rounded : Icons.swap_horiz_rounded,
                size: 20,
              ),
              label: Text(printer == null ? 'Pilih printer' : 'Ganti printer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() => Row(
    children: [
      Expanded(
        child: ActionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Cetak teks',
          subtitle: 'Tulis & pratinjau',
          onTap: () => showPrint(),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ActionCard(
          icon: Icons.fact_check_outlined,
          title: 'Tes printer',
          subtitle: 'Cetak struk uji',
          onTap: () => showPrint(test: true),
        ),
      ),
    ],
  );

  Widget _websiteCard() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.language_rounded, color: teal, size: 21),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chrome & browser lain',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '1. Tekan Cetak di website Anda.\n2. Pilih printer dari Print Service.\n3. Pilih kertas 58 / 80 mm, lalu cetak.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 13),
        ),
        const SizedBox(height: 18),
        const Text(
          'Jika tombol website tidak membuka dialog, gunakan menu browser → Bagikan → Cetak.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 12),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openWebsite,
            icon: const Icon(Icons.open_in_browser_rounded, size: 19),
            label: const Text('Buka browser'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _help,
          child: const Text('Petunjuk cetak dari browser'),
        ),
      ],
    ),
  );

  Widget _paperCard() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ukuran kertas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${controller.paperMm} mm',
              style: const TextStyle(
                color: teal,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PaperSelector(
          value: controller.paperMm,
          onChanged: (value) =>
              run(() => controller.setPreferences(paper: value)),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: ReceiptPreview(
              text: sampleReceipt,
              paperMm: controller.paperMm,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Bisa diubah lagi sebelum mencetak.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _serviceCard() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              controller.serviceEnabled
                  ? Icons.check_circle_outline_rounded
                  : Icons.settings_suggest_outlined,
              color: teal,
              size: 23,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.serviceEnabled
                    ? 'Layanan cetak aktif'
                    : 'Aktifkan layanan cetak',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Aktifkan Print Service · Bluetooth POS agar printer tersimpan dapat dipilih dari dialog cetak Chrome dan aplikasi lain. Aplikasi ini tidak perlu dibuka saat mencetak.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => run(controller.openPrintSettings),
          child: const Text('Buka pengaturan cetak →'),
        ),
      ],
    ),
  );

  Widget _printers() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        title: 'Printer Anda',
        subtitle: 'Tersimpan di perangkat. Siap untuk cetakan berikutnya.',
      ),
      const SizedBox(height: 22),
      _primaryPrinter(),
      const SizedBox(height: 24),
      const Text(
        'Riwayat printer',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      if (controller.printers.isEmpty)
        const Panel(
          child: EmptyState(
            icon: Icons.bluetooth_searching_rounded,
            title: 'Belum ada printer tersimpan',
            subtitle:
                'Pasangkan printer melalui Bluetooth, lalu pilih di aplikasi.',
          ),
        )
      else
        ...controller.printers.map(
          (printer) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print_outlined, color: teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              printer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              printer.address,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Opsi printer',
                        onSelected: (value) => run(
                          () => controller.forgetPrinter(printer.address),
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'forget',
                            child: Text('Lupakan printer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (printer.lastUsed != null)
                    Text(
                      'Terakhir dikirim: ${friendlyTime(printer.lastUsed!)}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.working
                        ? null
                        : () => run(() => controller.selectPrinter(printer)),
                    icon: Icon(
                      printer.address == controller.selectedAddress
                          ? Icons.check_rounded
                          : Icons.touch_app_outlined,
                      size: 18,
                    ),
                    label: Text(
                      printer.address == controller.selectedAddress
                          ? 'Printer utama'
                          : 'Jadikan utama',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => run(controller.openBluetoothSettings),
        icon: const Icon(Icons.bluetooth_rounded),
        label: const Text('Pasangkan printer baru'),
      ),
    ],
  );

  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        title: 'Riwayat cetak',
        subtitle: 'Catatan pengiriman dari aplikasi dan layanan cetak Android.',
      ),
      const SizedBox(height: 20),
      const Notice(
        icon: Icons.info_outline_rounded,
        text: 'Status “Terkirim” berarti data diterima koneksi Bluetooth. Periksa kertas dan hasil fisik pada printer.',
      ),
      const SizedBox(height: 20),
      if (controller.records.isEmpty)
        const Panel(
          child: EmptyState(
            icon: Icons.history_rounded,
            title: 'Masih kosong',
            subtitle: 'Cetak struk uji untuk memeriksa printer Anda.',
          ),
        )
      else ...[
        Panel(
          child: Column(children: controller.records.map(_recordTile).toList()),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _clearHistory,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Hapus riwayat cetak'),
        ),
      ],
    ],
  );

  Widget _recordTile(PrintRecord record) {
    final success = record.status == 'sent';
    final cancelled = record.status == 'cancelled';
    final color = success
        ? teal
        : cancelled
        ? muted
        : const Color(0xFFB74E36);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              success
                  ? Icons.receipt_long_outlined
                  : Icons.error_outline_rounded,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${record.printer} · ${record.paperMm} mm',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  friendlyTime(record.time),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                if (record.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      record.error!,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 7),
                Text(
                  success
                      ? 'Terkirim'
                      : cancelled
                      ? 'Dibatalkan'
                      : 'Gagal',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        title: 'Pengaturan',
        subtitle: 'Sesuaikan layanan dengan printer dan alur kerja Anda.',
      ),
      const SizedBox(height: 22),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kertas default',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            PaperSelector(
              value: controller.paperMm,
              onChanged: (value) =>
                  run(() => controller.setPreferences(paper: value)),
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Potong kertas otomatis',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Aktifkan jika printer memiliki pemotong.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: controller.cutPaper,
              onChanged: (value) =>
                  run(() => controller.setPreferences(cut: value)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _serviceCard(),
      const SizedBox(height: 18),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Perangkat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _statusRow(
              'Bluetooth',
              controller.bluetoothEnabled
                  ? 'Aktif'
                  : 'Nonaktif / belum diizinkan',
            ),
            _statusRow(
              'Akses perangkat terdekat',
              controller.permissionGranted ? 'Diizinkan' : 'Belum diizinkan',
            ),
            _statusRow('Protokol printer', 'Bluetooth Classic · ESC/POS'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => run(controller.openBluetoothSettings),
              icon: const Icon(Icons.bluetooth_rounded),
              label: const Text('Pengaturan Bluetooth'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Notice(
        icon: Icons.lock_outline_rounded,
        text: 'Riwayat printer dan cetakan tersimpan lokal di perangkat. Aplikasi tidak mengunggah dokumen cetak.',
      ),
      const SizedBox(height: 24),
      const Text(
        'PRINT SERVICE / 1.1.0',
        style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.6),
      ),
    ],
  );

  Widget _statusRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Wrap(
      spacing: 12,
      runSpacing: 5,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    ),
  );

  Future<void> _openWebsite() async {
    final input = TextEditingController(text: controller.website);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka di browser luar'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alamat ini akan dibuka di browser bawaan ponsel, seperti Chrome.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'https://kasir.anda.id',
                  labelText: 'Alamat website',
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Buka'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating after its result completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (url != null && mounted) await run(() => controller.openWebsite(url));
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mulai mencetak'),
      content: const SingleChildScrollView(
        child: Text(
          '1. Pasangkan printer melalui pengaturan Bluetooth Android.\n\n2. Tambahkan printer di aplikasi, izinkan akses Bluetooth, dan cetak struk uji.\n\n3. Aktifkan Print Service · Bluetooth POS melalui pengaturan cetak Android.\n\n4. Buka website di Chrome atau browser lain. Gunakan tombol Cetak di website. Jika browser tidak merespons window.print(), gunakan menu browser → Bagikan → Cetak.\n\n5. Pada dialog Android, pilih Semua printer jika perlu, pilih printer POS Anda, lalu pilih kertas 58 atau 80 mm dan cetak.\n\nAplikasi ini menerima pekerjaan dari sistem Android. Dukungan window.print() ditentukan browser; aplikasi tidak dapat mengganti perilaku JavaScript browser lain. Printer harus mendukung Bluetooth Classic SPP dan ESC/POS. BLE dan iOS belum didukung.',
          style: TextStyle(height: 1.6, fontSize: 14),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );

  Future<void> _clearHistory() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus riwayat cetak?'),
        content: const Text('Catatan cetakan akan dihapus dari perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (clear == true) await run(controller.clearRecords);
  }
}

class PrinterPicker extends StatefulWidget {
  const PrinterPicker({super.key, required this.controller});
  final PrintController controller;
  @override
  State<PrinterPicker> createState() => _PrinterPickerState();
}

class _PrinterPickerState extends State<PrinterPicker>
    with WidgetsBindingObserver {
  List<PrinterDevice> devices = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.controller.pairedPrinters();
      if (mounted) setState(() => devices = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlatformException ? e.message : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih printer Bluetooth',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Muat ulang',
                  onPressed: loading ? null : load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Perangkat yang sudah dipasangkan dengan ponsel. Pilih printer POS, lalu coba cetak struk uji.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Notice(icon: Icons.info_outline, text: error!)
            else if (devices.isEmpty)
              const EmptyState(
                icon: Icons.bluetooth_searching_rounded,
                title: 'Printer belum ditemukan',
                subtitle: 'Pasangkan printer lewat pengaturan Bluetooth, lalu muat ulang daftar ini.',
              )
            else
              ...devices.map(
                (printer) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: const Icon(Icons.print_outlined, color: teal),
                  title: Text(
                    printer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    printer.address,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  trailing: Icon(
                    printer.address == widget.controller.selectedAddress
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: teal,
                  ),
                  onTap: () async {
                    try {
                      await widget.controller.selectPrinter(printer);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        setState(
                          () => error = e is PlatformException
                              ? e.message
                              : e.toString(),
                        );
                      }
                    }
                  },
                ),
              ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await widget.controller.openBluetoothSettings();
                } catch (e) {
                  if (mounted) {
                    setState(
                      () => error = e is PlatformException
                          ? e.message
                          : e.toString(),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pasangkan printer baru'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrintSheet extends StatefulWidget {
  const PrintSheet({
    super.key,
    required this.controller,
    required this.test,
    required this.choosePrinter,
  });
  final PrintController controller;
  final bool test;
  final Future<void> Function() choosePrinter;
  @override
  State<PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<PrintSheet> {
  late final text = TextEditingController(
    text: widget.test ? sampleReceipt : '',
  );
  late int paper = widget.controller.paperMm;
  int copies = 1;
  bool printing = false;
  bool preview = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.sizeOf(context).height * 0.88 -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(80.0, double.infinity),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.test ? 'Tes cetak printer' : 'Cetak teks',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: printing ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print_outlined, color: teal),
                title: Text(
                  widget.controller.selectedPrinter?.name ??
                      'Pilih printer dahulu',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  widget.controller.selectedPrinter?.address ??
                      'Belum ada printer utama',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: printing
                    ? null
                    : () async {
                        await widget.choosePrinter();
                        if (mounted) setState(() {});
                      },
              ),
              const SizedBox(height: 16),
              PaperSelector(
                value: paper,
                onChanged: printing
                    ? null
                    : (value) => setState(() => paper = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Isi cetakan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => preview = !preview),
                    icon: Icon(
                      preview ? Icons.edit_outlined : Icons.visibility_outlined,
                      size: 17,
                    ),
                    label: Text(preview ? 'Edit teks' : 'Pratinjau'),
                  ),
                ],
              ),
              if (preview)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: ReceiptPreview(
                      text: text.text.isEmpty ? 'Teks cetakan Anda' : text.text,
                      paperMm: paper,
                    ),
                  ),
                )
              else
                TextField(
                  controller: text,
                  enabled: !printing,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 12000,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Tulis atau tempel teks struk di sini…',
                    alignLabelWithHint: true,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Jumlah salinan',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kurangi salinan',
                    onPressed: printing || copies == 1
                        ? null
                        : () => setState(() => copies--),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    '$copies',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: 'Tambah salinan',
                    onPressed: printing || copies == 5
                        ? null
                        : () => setState(() => copies++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Notice(icon: Icons.error_outline, text: error!),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: printing ? null : _print,
                icon: printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  printing ? 'Mengirim ke printer…' : 'Cetak sekarang',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pastikan printer menyala dan kertas terpasang.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _print() async {
    if (widget.controller.selectedPrinter == null) {
      await widget.choosePrinter();
      if (mounted) setState(() {});
      return;
    }
    if (text.text.trim().isEmpty) {
      setState(() => error = 'Isi teks cetakan terlebih dahulu.');
      return;
    }
    setState(() {
      printing = true;
      error = null;
    });
    try {
      await widget.controller.printText(text.text, paper, copies);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data cetak terkirim. Periksa hasil pada printer.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlatformException
              ? e.message ?? 'Gagal mengirim cetakan.'
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }
}

class PaperSelector extends StatelessWidget {
  const PaperSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [58, 80]
        .map(
          (paper) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: paper == 58 ? 5 : 0,
                left: paper == 80 ? 5 : 0,
              ),
              child: Semantics(
                selected: value == paper,
                button: true,
                child: Material(
                  color: value == paper
                      ? const Color(0xFFE8F4EE)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: value == paper ? teal : line,
                      width: value == paper ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onChanged == null ? null : () => onChanged!(paper),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$paper mm',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: value == paper ? teal : ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            paper == 58 ? 'POS standar' : 'POS lebar',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({
    super.key,
    required this.text,
    required this.paperMm,
    this.compact = false,
  });
  final String text;
  final int paperMm;
  final bool compact;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    width: paperMm == 58 ? 240 : 310,
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: 0.07),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              text,
              maxLines: compact ? 11 : null,
              overflow: compact ? TextOverflow.fade : null,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: compact ? 9 : 11,
                height: 1.7,
                color: const Color(0xFF36443F),
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(double.infinity, 8),
          painter: _PaperEdge(),
        ),
      ],
    ),
  );
}

class _PaperEdge extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x < size.width; x += 12) {
      path.lineTo(x + 6, 0);
      path.lineTo(x + 12, size.height);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF5F7F5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: teal,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(Icons.print_rounded, color: Colors.white, size: 23),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: color == Colors.white ? line : color),
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    ),
  );
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: teal, size: 26),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        subtitle,
        style: const TextStyle(color: muted, fontSize: 13, height: 1.6),
      ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Icon(icon, color: muted.withValues(alpha: 0.6), size: 34),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEBF1ED),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: teal, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: ink, height: 1.6),
          ),
        ),
      ],
    ),
  );
}
