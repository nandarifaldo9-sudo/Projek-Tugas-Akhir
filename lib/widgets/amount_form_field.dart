import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class AmountFormField extends StatelessWidget {
  const AmountFormField({
    super.key,
    required this.controller,
    required this.label,
    this.allowEmpty = false,
  });

  final TextEditingController controller;
  final String label;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: appInput(label, prefixText: 'Rp '),
      validator: (value) {
        if (allowEmpty && (value == null || value.isEmpty)) return null;
        final amount = int.tryParse(value ?? '');
        if (amount == null || (!allowEmpty && amount <= 0)) {
          return 'Nominal harus lebih dari 0';
        }
        return null;
      },
    );
  }
}
