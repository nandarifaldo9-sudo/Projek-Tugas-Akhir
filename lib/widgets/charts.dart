import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Warna irisan diagram lingkaran (berulang bila kategori lebih dari 8).
const chartPalette = <Color>[
  Color(0xFF142D4E),
  Color(0xFF20B8A6),
  Color(0xFFF2A541),
  Color(0xFFE45B64),
  Color(0xFF6C8EBF),
  Color(0xFF8E7CC3),
  Color(0xFF7BC47F),
  Color(0xFFB0B8C4),
];

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    this.size = 170,
    this.center,
  });

  final List<int> values;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(values),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      paint.color = chartPalette[i % chartPalette.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

/// Diagram batang: pemasukan (hijau) dan pengeluaran (merah) per bulan.
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({super.key, required this.data});

  final List<MonthTotal> data;

  static const double _barArea = 140;

  @override
  Widget build(BuildContext context) {
    var maxValue = 0;
    for (final m in data) {
      if (m.income > maxValue) maxValue = m.income;
      if (m.expense > maxValue) maxValue = m.expense;
    }

    double heightOf(int v) {
      if (maxValue == 0 || v == 0) return 0;
      return math.max(3.0, _barArea * v / maxValue);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _barArea,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(heightOf(data[i].income), AppColors.income),
                            const SizedBox(width: 4),
                            _Bar(heightOf(data[i].expense), AppColors.expense),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bulanSingkat(data[i].month),
                      style: TextStyle(
                        fontSize: 11,
                        color: i == data.length - 1
                            ? AppColors.navy
                            : AppColors.textSecondary,
                        fontWeight: i == data.length - 1
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            _LegendDot(AppColors.income, 'Masuk'),
            SizedBox(width: 16),
            _LegendDot(AppColors.expense, 'Keluar'),
          ],
        ),
        if (maxValue > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Batang tertinggi: ${rupiah(maxValue)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.height, this.color);

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}