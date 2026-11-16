class PrinterDevice {
  const PrinterDevice({
    required this.address,
    required this.name,
    this.lastUsed,
  });

  final String address;
  final String name;
  final DateTime? lastUsed;

  factory PrinterDevice.fromMap(Map<String, dynamic> map) => PrinterDevice(
    address: map['address'] as String,
    name: map['name'] as String? ?? 'Printer Bluetooth',
    lastUsed: DateTime.tryParse(map['lastUsed'] as String? ?? ''),
  );
}

class PrintRecord {
  const PrintRecord({
    required this.id,
    required this.title,
    required this.printer,
    required this.paperMm,
    required this.status,
    required this.time,
    this.error,
  });

  final String id;
  final String title;
  final String printer;
  final int paperMm;
  final String status;
  final DateTime time;
  final String? error;

  factory PrintRecord.fromMap(Map<String, dynamic> map) => PrintRecord(
    id: map['id'] as String,
    title: map['title'] as String,
    printer: map['printer'] as String,
    paperMm: (map['paperMm'] as num).toInt(),
    status: map['status'] as String,
    time: DateTime.parse(map['time'] as String).toLocal(),
    error: map['error'] as String?,
  );
}

String friendlyTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (date == today) return 'Hari ini, $clock';
  if (date == today.subtract(const Duration(days: 1))) return 'Kemarin, $clock';
  return '${local.day}/${local.month}/${local.year}, $clock';
}
