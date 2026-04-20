import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class StoreDetailScreen extends ConsumerWidget {
  final Store store;
  const StoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentStoreProvider)?.id != store.id) {
        ref.read(currentStoreProvider.notifier).setStore(store);
      }
    });

    final salesAsync = ref.watch(storeSalesProvider);
    final personnelAsync = ref.watch(storePersonnelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Qty Sold',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Store info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mintGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    'Commission: ${store.commissionRate.toStringAsFixed(0)}%   '
                    'Rent/person: R${store.rent.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  // Show assigned personnel
                  personnelAsync.when(
                    data: (people) {
                      if (people.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: people
                              .map((p) => Chip(
                                    label: Text('${p.name} (${p.codePrefix})'),
                                    backgroundColor:
                                        AppTheme.palePink.withOpacity(0.5),
                                    labelStyle:
                                        const TextStyle(fontSize: 12),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Dynamic profit split based on store personnel
            personnelAsync.when(
              data: (personnel) => salesAsync.when(
                data: (lines) => _buildProfitSplit(context, lines, personnel),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Action tiles
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    title: 'Store Sales',
                    subtitle: 'View all items sold',
                    icon: Icons.bar_chart,
                    color: AppTheme.mutedLavender,
                    onTap: () => context.push('/inventory'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionTile(
                    title: 'Upload PDF',
                    subtitle: 'Import monthly report',
                    icon: Icons.upload_file,
                    color: AppTheme.babyBlue,
                    onTap: () => context.push('/upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSplit(
    BuildContext context,
    List<SaleLineItem> lines,
    List<CompanyPersonnel> personnel,
  ) {
    if (personnel.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No personnel assigned to this store. Edit the store to add people.',
          style: TextStyle(color: Colors.deepOrange, fontSize: 13),
        ),
      );
    }

    // Calculate profit per person based on their code prefix
    final Map<String, double> grossByPrefix = {};
    for (var p in personnel) {
      grossByPrefix[p.codePrefix] = 0;
    }
    for (var line in lines) {
      for (var p in personnel) {
        if (line.itemCode.startsWith(p.codePrefix)) {
          grossByPrefix[p.codePrefix] =
              (grossByPrefix[p.codePrefix] ?? 0) +
                  line.profitBeforeRent(store.commissionRate);
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.babyBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.babyBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Profit Split',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('Rent/person: R${store.rent.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const Divider(height: 20),
          ...personnel.asMap().entries.map((entry) {
            final p = entry.value;
            final colors = [AppTheme.mintGreen, AppTheme.palePink, AppTheme.mutedLavender, AppTheme.babyBlue];
            final color = colors[entry.key % colors.length];
            final gross = grossByPrefix[p.codePrefix] ?? 0;
            final net = gross - store.rent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(p.codePrefix,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.black54)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Gross: R${gross.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                        Text(
                          'Net: R${net.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: net >= 0
                                ? Colors.green.shade700
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Sales Data'),
        content: Text(
          'Reset all "Quantity Sold" for ${store.name}?\n\n'
          'Catalogue items and prices are not affected.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).clearStoreSales(store.id);
        ref.invalidate(storeSalesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sales quantities cleared.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppTheme.darkText),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkText.withOpacity(0.6)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
