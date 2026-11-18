import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _tanggal = DateFormat('d MMM yyyy', 'id_ID');
final _tanggalLengkap = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
final _bulanTahun = DateFormat('MMMM yyyy', 'id_ID');
final _bulanSingkat = DateFormat('MMM', 'id_ID');

String rupiah(int value) => _rupiah.format(value);

String tanggal(DateTime date) => _tanggal.format(date);

String tanggalLengkap(DateTime date) => _tanggalLengkap.format(date);

String bulanTahun(DateTime date) => _bulanTahun.format(date);

String bulanSingkat(DateTime date) => _bulanSingkat.format(date);