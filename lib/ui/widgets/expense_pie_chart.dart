import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExpensePieChart extends StatelessWidget {
  final double expense;
  final double income;

  const ExpensePieChart({super.key, required this.expense, required this.income});

  @override
  Widget build(BuildContext context) {
    final total = (expense + income).clamp(1, double.infinity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('توزيع التدفق المالي', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.redAccent,
                      value: expense / total,
                      title: 'مصروف',
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: income / total,
                      title: 'دخل',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
