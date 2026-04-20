import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _performDailyUpdateCheck();
  }

  Future<void> _performDailyUpdateCheck() async {
    const storage = FlutterSecureStorage();
    final lastCheckStr = await storage.read(key: 'last_update_check');
    final now = DateTime.now();

    if (lastCheckStr != null) {
      final lastCheck = DateTime.parse(lastCheckStr);
      if (now.difference(lastCheck).inHours < 24) return;
    }

    try {
      final updateService = ref.read(updateServiceProvider);
      final link = await updateService.checkForUpdates();
      if (link != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('A new update is available.'),
            action: SnackBarAction(
              label: 'Download',
              onPressed: () => updateService.launchDownload(link),
            ),
          ),
        );
      }
      await storage.write(key: 'last_update_check', value: now.toIso8601String());
    } catch (_) {
      // Silent fail — background check
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStore = ref.watch(currentStoreProvider);
    final companyAsync = ref.watch(companyProvider);

    // Redirect to onboarding if authenticated but no company
    ref.listen(companyProvider, (previous, next) {
      if (!next.isLoading && next.hasValue && next.value == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/onboarding');
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lux'),
        actions: [
          // Manual update check button
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Check for Updates',
            onPressed: () async {
              final updateService = ref.read(updateServiceProvider);
              final link = await updateService.checkForUpdates();
              if (!mounted) return;
              if (link != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Update available.'),
                    action: SnackBarAction(
                      label: 'Download',
                      onPressed: () => updateService.launchDownload(link),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App is up to date.')),
                );
              }
            },
          ),
          // Sign out
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(supabaseServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome header
            companyAsync.when(
              data: (company) => Text(
                company != null ? company.name : 'Welcome',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Text(
              currentStore != null
                  ? 'Active store: ${currentStore.name}'
                  : 'No store selected — go to Stores to choose one.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            // Profit split card — only when a store is selected
            if (currentStore != null) _ProfitSplitCard(store: currentStore),

            const SizedBox(height: 24),

            // Navigation grid — only top-level sections here
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _NavCard(
                  title: 'Stores',
                  icon: Icons.storefront,
                  color: AppTheme.palePink,
                  onTap: () => context.push('/stores'),
                ),
                _NavCard(
                  title: 'Catalogue',
                  icon: Icons.inventory_2,
                  color: AppTheme.mintGreen,
                  onTap: () => context.push('/catalogue'),
                ),
                _NavCard(
                  title: 'Settings',
                  icon: Icons.settings,
                  color: Colors.grey.shade300,
                  onTap: () => context.push('/company-settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Profit Split Card ---

class _ProfitSplitCard extends ConsumerWidget {
  final Store store;
  const _ProfitSplitCard({required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(storeSalesProvider);
    final personnelAsync = ref.watch(personnelProvider);

    return salesAsync.when(
      data: (lines) {
        return personnelAsync.when(
          data: (personnel) {
            final Map<String, double> grossProfits = {
              for (var p in personnel) p.id: 0.0
            };
            double otherGross = 0.0;

            for (var line in lines) {
              final profit = line.profitBeforeRent(store.commissionRate);
              bool matched = false;
              for (var p in personnel) {
                if (line.itemCode.startsWith(p.codePrefix)) {
                  grossProfits[p.id] = (grossProfits[p.id] ?? 0.0) + profit;
                  matched = true;
                  break;
                }
              }
              if (!matched) {
                otherGross += profit;
              }
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.babyBlue.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.babyBlue.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Profit Split',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Spacer(),
                      Text(
                        'Rent/person: R${store.rent.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (personnel.isEmpty)
                    const Text('No personnel configured. Go to Company Settings.', style: TextStyle(color: Colors.grey)),
                  ...personnel.map((p) {
                    final gross = grossProfits[p.id] ?? 0.0;
                    final net = gross - store.rent;
                    // Cycle colors
                    final colorIndex = personnel.indexOf(p) % 3;
                    final rowColor = colorIndex == 0 ? AppTheme.mintGreen : colorIndex == 1 ? AppTheme.palePink : AppTheme.babyBlue;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SplitRow(
                          label: '${p.name} (${p.codePrefix})',
                          gross: gross,
                          net: net,
                          color: rowColor),
                    );
                  }).toList(),
                  if (otherGross > 0)
                    _SplitRow(
                        label: 'Other/Unknown',
                        gross: otherGross,
                        net: null,
                        color: Colors.grey.shade300),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading personnel: $e'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load profit data: $e'),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String label;
  final double gross;
  final double? net;
  final Color color;

  const _SplitRow(
      {required this.label,
      required this.gross,
      required this.net,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.35),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Gross: R${gross.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12)),
              if (net != null)
                Text(
                  'Net: R${net!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net! >= 0 ? Colors.green.shade700 : Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Nav Card ---

class _NavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppTheme.darkText),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
