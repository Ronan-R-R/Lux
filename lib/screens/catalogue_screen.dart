import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showItemDialog({CatalogueItem? itemToEdit}) async {
    final company = await ref.read(companyProvider.future);
    if (company == null || !mounted) return;

    final codeCtrl = TextEditingController(text: itemToEdit?.itemCode ?? '');
    final nameCtrl = TextEditingController(text: itemToEdit?.itemName ?? '');
    final costCtrl = TextEditingController(
        text: itemToEdit != null ? itemToEdit.costPrice.toStringAsFixed(2) : '');
    final sellCtrl = TextEditingController(
        text: itemToEdit != null ? itemToEdit.sellPrice.toStringAsFixed(2) : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(itemToEdit == null ? 'Add Catalogue Item' : 'Edit Catalogue Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  hintText: 'e.g. TSTA001',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: itemToEdit == null, // Code cannot be changed once set
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cost Price (R)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sellCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sell Price (R)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintGreen),
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              final name = nameCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text) ?? 0;
              final sell = double.tryParse(sellCtrl.text) ?? 0;

              if (code.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Item code and name are required.')),
                );
                return;
              }

              final newItem = CatalogueItem(
                id: itemToEdit?.id ?? '',
                companyId: company.id,
                itemCode: code,
                itemName: name,
                costPrice: cost,
                sellPrice: sell,
              );

              try {
                await ref.read(supabaseServiceProvider).upsertCatalogueItem(newItem);
                ref.invalidate(catalogueProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e')),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.darkText)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CatalogueItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to remove "${item.itemName}" (${item.itemCode}) from the catalogue?\n\nThis will not delete any existing store sales records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
        await ref.read(supabaseServiceProvider).deleteCatalogueItem(item.id);
        ref.invalidate(catalogueProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Stock Catalogue'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Company-wide product list. Prices defined here apply across all stores.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: catalogueAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No items in catalogue yet.',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first item.'),
                ],
              ),
            );
          }

          // Filter and Sort Items
          final filteredItems = items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final lowerQuery = _searchQuery.toLowerCase();
            return item.itemCode.toLowerCase().contains(lowerQuery) ||
                item.itemName.toLowerCase().contains(lowerQuery);
          }).toList();

          // Sort alphabetically by code (which natively sorts letters then numbers if zero-padded e.g. LHDE006 vs LHDE012)
          filteredItems.sort((a, b) => a.itemCode.compareTo(b.itemCode));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Catalogue',
                    hintText: 'Search by item code or name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(child: Text('No items match your search.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppTheme.mintGreen.withOpacity(0.3),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Code')),
                                    DataColumn(label: Text('Item Name')),
                                    DataColumn(label: Text('Cost Price')),
                                    DataColumn(label: Text('Sell Price')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filteredItems.map((item) {
                                    return DataRow(cells: [
                                      DataCell(Text(item.itemCode,
                                          style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(item.itemName)),
                                      DataCell(Text('R${item.costPrice.toStringAsFixed(2)}')),
                                      DataCell(Text('R${item.sellPrice.toStringAsFixed(2)}')),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                              tooltip: 'Edit',
                                              onPressed: () => _showItemDialog(itemToEdit: item),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              tooltip: 'Delete',
                                              onPressed: () => _confirmDelete(item),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.palePink,
        tooltip: 'Add Item',
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add, color: AppTheme.darkText),
      ),
    );
  }
}
