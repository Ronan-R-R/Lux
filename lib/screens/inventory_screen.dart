import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(currentStoreProvider);
    final salesAsync = ref.watch(storeSalesProvider);

    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Store Sales')),
        body: const Center(child: Text('No store selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${store.name} — Sales'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Commission: ${store.commissionRate.toStringAsFixed(0)}%   Rent per person: R${store.rent.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ),
      body: salesAsync.when(
        data: (lines) {
          if (lines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No sales recorded yet for this store.',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  const Text('Upload a PDF report to populate this view.'),
                ],
              ),
            );
          }

          double totalSalesSum = 0;
          double totalProfit = 0;
          for (var l in lines) {
            totalSalesSum += l.totalSales;
            totalProfit += l.profitBeforeRent(store.commissionRate);
          }
          final netProfit = totalProfit - store.rent;

          return Column(
            children: [
              // Summary bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.mintGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryChip(
                      label: 'Total Sales',
                      value: 'R${totalSalesSum.toStringAsFixed(2)}',
                    ),
                    _SummaryChip(
                      label: 'Gross Profit',
                      value: 'R${totalProfit.toStringAsFixed(2)}',
                    ),
                    _SummaryChip(
                      label: 'Rent',
                      value: '-R${store.rent.toStringAsFixed(2)}',
                      valueColor: Colors.redAccent,
                    ),
                    _SummaryChip(
                      label: 'Net Profit',
                      value: 'R${netProfit.toStringAsFixed(2)}',
                      valueColor: netProfit >= 0 ? Colors.green.shade700 : Colors.red,
                    ),
                  ],
                ),
              ),
              // Table
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppTheme.babyBlue.withOpacity(0.3),
                          ),
                          columns: const [
                            DataColumn(label: Text('Code')),
                            DataColumn(label: Text('Item Name')),
                            DataColumn(label: Text('Cost')),
                            DataColumn(label: Text('Sell')),
                            DataColumn(label: Text('Qty Sold')),
                            DataColumn(label: Text('Total Sales')),
                            DataColumn(label: Text('Profit')),
                          ],
                          rows: lines.map((line) {
                            final profit = line.profitBeforeRent(store.commissionRate);
                            return DataRow(cells: [
                              DataCell(Text(line.itemCode,
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(line.itemName)),
                              DataCell(Text('R${line.costPrice.toStringAsFixed(2)}')),
                              DataCell(Text('R${line.sellPrice.toStringAsFixed(2)}')),
                              DataCell(Text(line.quantitySold.toString())),
                              DataCell(Text('R${line.totalSales.toStringAsFixed(2)}')),
                              DataCell(Text(
                                'R${profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: profit >= 0 ? Colors.green.shade700 : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: valueColor ?? AppTheme.darkText)),
      ],
    );
  }
}
