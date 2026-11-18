import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import 'add_transaction_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'target_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _clockTimer;
  late DateTime _lastClock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastClock = _hourKey();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkClock(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Penanda jam saat ini (sampai satuan jam). Berubah tiap jam, termasuk
  /// saat pergantian hari dan bulan.
  DateTime _hourKey() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  void _checkClock() {
    final key = _hourKey();
    if (key != _lastClock) {
      _lastClock = key;
      context.read<FinanceProvider>().refreshClock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClock();
  }

  void _openAddForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onSeeAll: () => setState(() => _index = 1)),
      const TransactionsScreen(),
      const ReportScreen(),
      const TargetScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      // Tombol + hanya di Beranda dan Transaksi.
      floatingActionButton: _index <= 1
          ? FloatingActionButton(
              onPressed: _openAddForm,
              tooltip: 'Tambah transaksi',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Target',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
