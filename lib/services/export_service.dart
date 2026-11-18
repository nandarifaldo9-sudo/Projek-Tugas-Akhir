import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import 'backup_service.dart';

class ExportService {
  ExportService._();

  static String buildCsv(FinanceProvider f) {
    final data = <_CsvRow>[];

    for (final t in f.transactions) {
      final isTransfer = t.type == TxType.transfer;
      data.add(
        _CsvRow([
          dateKey(t.date),
          isTransfer
              ? 'Transfer'
              : t.type == TxType.income
              ? 'Masuk'
              : 'Keluar',
          isTransfer ? '' : f.categoryName(t.categoryId),
          isTransfer
              ? '${f.accountName(t.accountId)} → '
                    '${f.accountName(t.toAccountId)}'
              : f.accountName(t.accountId),
          t.amount.toString(),
          t.note,
        ], data.length),
      );
    }
    for (final d in f.deposits) {
      data.add(
        _CsvRow([
          dateKey(d.date),
          'Setoran target',
          f.goalName(d.goalId),
          f.accountName(d.accountId),
          d.amount.toString(),
          d.note,
        ], data.length),
      );
    }

    data.sort((a, b) {
      final byDate = b.cells[0].compareTo(a.cells[0]);
      return byDate != 0 ? byDate : a.order.compareTo(b.order);
    });

    final rows = <List<String>>[
      ['Tanggal', 'Jenis', 'Kategori', 'Akun', 'Nominal', 'Catatan'],
      for (final row in data) row.cells,
    ];
    return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
  }

  static String _cell(String v) {
    final formulaCandidate = RegExp(r'^[\u0000-\u0020]*[=+\-@]').hasMatch(v);
    final startsWithControl = v.startsWith('\t') || v.startsWith('\r');
    final safeValue = formulaCandidate || startsWithControl ? "'$v" : v;
    if (safeValue.contains(',') ||
        safeValue.contains('"') ||
        safeValue.contains('\n') ||
        safeValue.contains('\r')) {
      return '"${safeValue.replaceAll('"', '""')}"';
    }
    return safeValue;
  }

  /// Membuka menu bagikan Android agar file bisa disimpan atau dikirim.
  static Future<void> shareCsv(FinanceProvider f) async {
    final csv = buildCsv(f);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(
        directory.path,
        'flowly-${DateTime.now().microsecondsSinceEpoch}.csv',
      ),
    );
    await file.writeAsString(csv, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Ekspor data Flowly',
      ),
    );
  }

  static Future<void> shareBackupCsv(FinanceProvider f) async {
    final csv = BackupService.buildCsv(f);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(
        directory.path,
        'flowly-backup-${DateTime.now().microsecondsSinceEpoch}.csv',
      ),
    );
    await file.writeAsString(csv, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Backup data Flowly',
      ),
    );
  }
}

class _CsvRow {
  const _CsvRow(this.cells, this.order);

  final List<String> cells;
  final int order;
}
