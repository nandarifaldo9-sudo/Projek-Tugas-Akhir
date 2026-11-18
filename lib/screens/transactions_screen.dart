import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  TxType? _filter; // null = semua
  DateTimeRange? _dateRange;
  int? _accountId;
  int? _categoryId;

  void _openForm(AppTransaction t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)),
    );
  }

  Future<void> _openFilters(FinanceProvider finance) async {
    var dateRange = _dateRange;
    var accountId = finance.accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    var categoryId = finance.categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter transaksi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tanggal',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final now = DateTime.now();
                            setSheetState(() {
                              dateRange = DateTimeRange(
                                start: DateTime(now.year, now.month),
                                end: DateTime(now.year, now.month + 1, 0),
                              );
                            });
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text(
                            'Bulan ini',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDateRange: dateRange,
                            );
                            if (picked != null) {
                              setSheetState(() => dateRange = picked);
                            }
                          },
                          icon: const Icon(Icons.date_range_outlined),
                          label: const Text(
                            'Pilih rentang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.tealTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_outlined,
                            size: 19,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateRange == null
                                ? 'Semua tanggal'
                                : '${tanggal(dateRange!.start)} – '
                                      '${tanggal(dateRange!.end)}',
                            style: TextStyle(
                              color: dateRange == null
                                  ? AppColors.textSecondary
                                  : AppColors.navy,
                              fontSize: 13,
                              fontWeight: dateRange == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (dateRange != null)
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'Hapus rentang tanggal',
                            onPressed: () =>
                                setSheetState(() => dateRange = null),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: accountId,
                    isExpanded: true,
                    decoration: appInput('Akun'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Semua akun'),
                      ),
                      for (final account in finance.accounts)
                        DropdownMenuItem<int?>(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => accountId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: categoryId,
                    isExpanded: true,
                    decoration: appInput('Kategori'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Semua kategori'),
                      ),
                      for (final category in finance.categories)
                        DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(
                            '${category.name} · '
                            '${category.type == TxType.income ? 'Masuk' : 'Keluar'}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => categoryId = value),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _dateRange = null;
                              _accountId = null;
                              _categoryId = null;
                              _filter = null;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Hapus filter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: AppColors.navy,
                            minimumSize: const Size.fromHeight(52),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _dateRange = dateRange;
                              _accountId = accountId;
                              _categoryId = categoryId;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, TxType? value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final q = _query.trim().toLowerCase();
    final accountId = f.accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    final categoryId = f.categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final activeFilterCount = _activeFilterCount(accountId, categoryId);

    final list = f.transactions.where((t) {
      if (_filter != null && t.type != _filter) return false;
      if (accountId != null && t.accountId != accountId) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (_dateRange != null) {
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        );
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      if (q.isNotEmpty &&
          !t.note.toLowerCase().contains(q) &&
          !f.categoryName(t.categoryId).toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    // Daftar dikelompokkan per tanggal (data sudah urut dari terbaru).
    final items = <Widget>[];
    DateTime? lastDate;
    for (final t in list) {
      if (lastDate == null || lastDate != t.date) {
        lastDate = t.date;
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              tanggal(t.date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      items.add(
        TransactionTile(
          t: t,
          onTap: () => _openForm(t),
          onLongPress: () async {
            if (await confirmDelete(context)) {
              await f.deleteTransaction(t.id!);
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Filter transaksi',
            onPressed: () => _openFilters(f),
            icon: Badge(
              backgroundColor: AppColors.teal,
              textColor: AppColors.navy,
              isLabelVisible: activeFilterCount > 0,
              label: Text('$activeFilterCount'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: appInput(
                null,
                hint: 'Cari transaksi',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  _chip('Semua', null),
                  _chip('Keluar', TxType.expense),
                  _chip('Masuk', TxType.income),
                ],
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: f.transactions.isEmpty
                        ? 'Belum ada transaksi'
                        : 'Tidak ada yang cocok',
                    message: f.transactions.isEmpty
                        ? 'Tekan tombol + untuk mencatat transaksi.'
                        : 'Coba ubah kata kunci atau filter.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: items,
                  ),
          ),
        ],
      ),
    );
  }

  int _activeFilterCount(int? accountId, int? categoryId) =>
      (_dateRange == null ? 0 : 1) +
      (accountId == null ? 0 : 1) +
      (categoryId == null ? 0 : 1);
}
