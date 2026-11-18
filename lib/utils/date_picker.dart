import 'package:flutter/material.dart';

Future<DateTime?> pilihTanggal(BuildContext context, DateTime initialDate) {
  final firstDate = DateTime(2020);
  final lastDate = DateTime(2100);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: initialDate.isBefore(firstDate) ? initialDate : firstDate,
    lastDate: initialDate.isAfter(lastDate) ? initialDate : lastDate,
  );
}
