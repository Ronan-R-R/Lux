import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import '../theme.dart';

class PdfUploadScreen extends ConsumerStatefulWidget {
  const PdfUploadScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends ConsumerState<PdfUploadScreen> {
  bool _isProcessing = false;
  List<ParsedItem> _previewItems = [];
  String? _errorMessage;
  List<String> _anomalies = [];

  Future<void> _pickAndParse() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _anomalies = [];
      _previewItems = [];
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final currentStore = ref.read(currentStoreProvider);
        if (currentStore == null) return;
        final bytes = await File(result.files.single.path!).readAsBytes();
        
        final personnel = await ref.read(supabaseServiceProvider).getStorePersonnel(currentStore.id);
        final items = await ref.read(pdfServiceProvider).parseLongbeachReport(bytes, personnel);
        
        setState(() => _previewItems = items);
      }
    } on PdfParseException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _anomalies = e.anomalyCodes;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyToDatabase() async {
    final currentStore = ref.read(currentStoreProvider);
    if (currentStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a store before applying.')),
      );
      return;
    }

    final company = await ref.read(companyProvider.future);
    if (company == null) return;

    setState(() => _isProcessing = true);

    try {
      // Load existing catalogue for this company to check membership
      final catalogue = await ref.read(supabaseServiceProvider).getCatalogueItems(company.id);
      final catalogueMap = {for (var c in catalogue) c.itemCode: c};

      final List<Map<String, dynamic>> salesBatch = [];
      bool applyAddAll = false;
      bool applyIgnoreAll = false;

      for (final parsedItem in _previewItems) {
        final code = parsedItem.itemCode;
        final unitPrice = parsedItem.qty > 0 ? parsedItem.salesValue / parsedItem.qty : 0.0;

        if (!catalogueMap.containsKey(code)) {
          // Unknown item — check global rules
          if (applyIgnoreAll) continue;

          if (!applyAddAll) {
            if (!mounted) break;
            final decision = await _showUnknownItemDialog(code, parsedItem);
            
            if (decision == 'ignore') continue;
            if (decision == 'ignore_all') {
              applyIgnoreAll = true;
              continue;
            }
            if (decision == 'add_all') {
              applyAddAll = true;
            }
            // else 'add' — proceed to add below
          }

          // Create a new catalogue entry with the PDF's unit price
          final newItem = CatalogueItem(
            id: '',
            companyId: company.id,
            itemCode: code,
            itemName: parsedItem.itemName.isNotEmpty ? parsedItem.itemName : 'Unknown Item ($code)',
            costPrice: 0.0,
            sellPrice: unitPrice,
          );
          await ref.read(supabaseServiceProvider).upsertCatalogueItem(newItem);
          ref.invalidate(catalogueProvider);
        } else {
          // Existing item — update its sell price based on the PDF
          final existingItem = catalogueMap[code]!;
          if (unitPrice > 0 && existingItem.sellPrice != unitPrice) {
            final updatedItem = existingItem.copyWith(sellPrice: unitPrice);
            await ref.read(supabaseServiceProvider).upsertCatalogueItem(updatedItem);
            ref.invalidate(catalogueProvider);
          }
        }

        salesBatch.add({
          'store_id': currentStore.id,
          'item_code': code,
          'quantity_sold': parsedItem.qty,
        });
      }

      if (salesBatch.isNotEmpty) {
        await ref.read(supabaseServiceProvider).syncStoreSalesBulk(
          currentStore.id,
          salesBatch,
        );
        ref.invalidate(storeSalesProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales data successfully applied to database!')),
        );
        setState(() => _previewItems = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Presents a dialog for an unrecognised item code. Returns string action:
  /// 'add', 'ignore', 'add_all', 'ignore_all'
  Future<String> _showUnknownItemDialog(String code, ParsedItem parsedItem) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help_outline, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Unknown Item Found',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              const Text(
                'This item from the PDF is missing from your catalogue. What would you like to do?',
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Item Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.babyBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.babyBlue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Qty: ${parsedItem.qty}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (parsedItem.itemName.isNotEmpty) ...[
                      Text(
                        parsedItem.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'Sales Value: R${parsedItem.salesValue.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              const Text('Just this item:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade700,
                      ),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Ignore'),
                      onPressed: () => Navigator.pop(ctx, 'ignore'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintGreen,
                        foregroundColor: AppTheme.darkText,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(ctx, 'add'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              const Text('For all remaining unknown items:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(ctx, 'ignore_all'),
                      child: const Text('Ignore All'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.darkText),
                      onPressed: () => Navigator.pop(ctx, 'add_all'),
                      child: const Text('Add All Automatically', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? 'ignore';
  }

  Future<void> _showClearDialog() async {
    final currentStore = ref.read(currentStoreProvider);
    if (currentStore == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Sales Data'),
        content: Text(
          'Are you sure you want to reset all "Quantity Sold" values for ${currentStore.name}?\n\n'
          'This only clears the monthly sales counts. Your stock catalogue and prices are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Sales'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(supabaseServiceProvider).clearStoreSales(currentStore.id);
        ref.invalidate(storeSalesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sales quantities cleared.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStore = ref.watch(currentStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload PDF Report')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentStore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.mintGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Applying to: ${currentStore.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No store selected. Go back and select a store first.',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Select PDF'),
                  onPressed: _isProcessing ? null : _pickAndParse,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Qty Sold'),
                  onPressed: _isProcessing ? null : _showClearDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isProcessing) const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Anomaly detected:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                    if (_anomalies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Codes: ${_anomalies.join(', ')}'),
                    ],
                  ],
                ),
              ),
            if (_previewItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${_previewItems.length} items parsed from PDF',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _previewItems.length,
                  itemBuilder: (context, index) {
                    final item = _previewItems[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.mintGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(item.itemCode,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text('Qty: ${item.qty}'),
                      subtitle: Text(
                          'Sales Value: R${item.salesValue.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.palePink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.cloud_upload_outlined,
                    color: AppTheme.darkText),
                label: const Text(
                  'Apply to Database',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkText),
                ),
                onPressed: _isProcessing ? null : _applyToDatabase,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
