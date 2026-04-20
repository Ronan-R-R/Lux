import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  void _showStoreDialog({Store? storeToEdit}) async {
    final company = await ref.read(companyProvider.future);
    if (company == null || !mounted) return;

    final allPersonnel = await ref.read(supabaseServiceProvider).getPersonnel(company.id);

    // Pre-load current personnel assignments if editing
    List<String> selectedIds = [];
    if (storeToEdit != null) {
      final existing = await ref.read(supabaseServiceProvider).getStorePersonnel(storeToEdit.id);
      selectedIds = existing.map((p) => p.id).toList();
    } else {
      // Default: all personnel selected
      selectedIds = allPersonnel.map((p) => p.id).toList();
    }

    final nameCtrl = TextEditingController(text: storeToEdit?.name ?? '');
    final commCtrl = TextEditingController(
      text: storeToEdit != null ? storeToEdit.commissionRate.toStringAsFixed(0) : '18',
    );
    final rentCtrl = TextEditingController(
      text: storeToEdit != null ? storeToEdit.rent.toStringAsFixed(2) : '221.50',
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(storeToEdit == null ? 'Add Store' : 'Edit Store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commission Rate (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rent per person (R)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Personnel at this store:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select who participates in this store. Each person\'s rent deduction is applied individually.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (allPersonnel.isEmpty)
                  const Text(
                    'No personnel found. Add people in Company Setup.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  )
                else ...[
                  // Select All toggle
                  CheckboxListTile(
                    value: selectedIds.length == allPersonnel.length,
                    tristate: false,
                    title: const Text('Select All',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onChanged: (val) {
                      setDlgState(() {
                        if (val == true) {
                          selectedIds = allPersonnel.map((p) => p.id).toList();
                        } else {
                          selectedIds = [];
                        }
                      });
                    },
                  ),
                  const Divider(height: 4),
                  ...allPersonnel.map((person) => CheckboxListTile(
                        value: selectedIds.contains(person.id),
                        title: Text(person.name),
                        subtitle: Text(person.codePrefix,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold)),
                        onChanged: (val) {
                          setDlgState(() {
                            if (val == true) {
                              selectedIds.add(person.id);
                            } else {
                              selectedIds.remove(person.id);
                            }
                          });
                        },
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintGreen),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final commission = double.tryParse(commCtrl.text) ?? 18;
                final rent = double.tryParse(rentCtrl.text) ?? 221.50;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Store name is required.')));
                  return;
                }

                try {
                  String storeId;
                  if (storeToEdit == null) {
                    final newStore = Store(
                      id: '',
                      companyId: company.id,
                      name: name,
                      commissionRate: commission,
                      rent: rent,
                    );
                    final created = await ref.read(supabaseServiceProvider).addStore(newStore);
                    storeId = created.id;
                  } else {
                    await ref.read(supabaseServiceProvider).updateStore(
                      storeToEdit.copyWith(name: name, commissionRate: commission, rent: rent),
                    );
                    storeId = storeToEdit.id;
                  }

                  // Save personnel assignments
                  await ref.read(supabaseServiceProvider).setStorePersonnel(storeId, selectedIds);

                  ref.invalidate(storeListProvider);
                  ref.invalidate(storePersonnelProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: AppTheme.darkText)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Store store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text(
          'Delete "${store.name}"?\n\nAll sales records for this store will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).deleteStore(store.id);
        if (ref.read(currentStoreProvider)?.id == store.id) {
          ref.read(currentStoreProvider.notifier).setStore(null);
        }
        ref.invalidate(storeListProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(storeListProvider);
    final currentStore = ref.watch(currentStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Stores')),
      body: storesAsync.when(
        data: (stores) {
          if (stores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No stores yet.',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first store.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (context, i) {
              final store = stores[i];
              final isActive = currentStore?.id == store.id;

              return Card(
                color: isActive ? AppTheme.babyBlue.withOpacity(0.3) : Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isActive
                      ? const BorderSide(color: AppTheme.mintGreen, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    ref.read(currentStoreProvider.notifier).setStore(store);
                    context.push('/store-detail', extra: store);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.storefront_outlined,
                          color: isActive ? AppTheme.mintGreen : Colors.grey,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(store.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                'Commission: ${store.commissionRate.toStringAsFixed(0)}%   '
                                'Rent/person: R${store.rent.toStringAsFixed(2)}',
                                style:
                                    TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => _showStoreDialog(storeToEdit: store),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(store),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.palePink,
        tooltip: 'Add Store',
        onPressed: () => _showStoreDialog(),
        child: const Icon(Icons.add, color: AppTheme.darkText),
      ),
    );
  }
}
