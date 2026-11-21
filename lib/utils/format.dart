import 'package:intl/intl.dart';

String _locale() => Intl.defaultLocale == 'en_US' ? 'en_US' : 'id_ID';

String rupiah(int value) => NumberFormat.currency(
  locale: _locale(),
  symbol: Intl.defaultLocale == 'en_US' ? 'Rp ' : 'Rp ',
  decimalDigits: 0,
).format(value);

String tanggal(DateTime date) =>
    DateFormat('d MMM yyyy', _locale()).format(date);

String tanggalLengkap(DateTime date) =>
    DateFormat('EEEE, d MMMM yyyy', _locale()).format(date);

String bulanTahun(DateTime date) =>
    DateFormat('MMMM yyyy', _locale()).format(date);

String bulanSingkat(DateTime date) => DateFormat('MMM', _locale()).format(date);
