import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';

class ExportService {
  ExportService._();

  static String buildCsv(FinanceProvider f) {
    final data = <List<String>>[];

    for (final t in f.transactions) {
      data.add([
        dateKey(t.date),
        t.type == TxType.income ? 'Masuk' : 'Keluar',
        f.categoryName(t.categoryId),
        f.accountName(t.accountId),
        t.amount.toString(),
        t.note,
      ]);
    }
    for (final d in f.deposits) {
      data.add([
        dateKey(d.date),
        'Setoran target',
        f.goalName(d.goalId),
        f.accountName(d.accountId),
        d.amount.toString(),
        d.note,
      ]);
    }

    // Tanggal berformat yyyy-MM-dd, jadi bisa diurutkan sebagai teks.
    data.sort((a, b) => b[0].compareTo(a[0]));

    final rows = <List<String>>[
      ['Tanggal', 'Jenis', 'Kategori', 'Akun', 'Nominal', 'Catatan'],
      ...data,
    ];
    return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
  }

  static String _cell(String v) {
    if (v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// Membuka menu bagikan Android agar file bisa disimpan atau dikirim.
  static Future<void> shareCsv(FinanceProvider f) async {
    final csv = buildCsv(f);
    await Share.share(csv, subject: 'Ekspor data Flowly');
  }
}
