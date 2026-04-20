import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/models.dart';

class PdfParseException implements Exception {
  final String message;
  final List<String> anomalyCodes;
  PdfParseException(this.message, this.anomalyCodes);

  @override
  String toString() => 'PdfParseException: $message';
}

class ParsedItem {
  final String itemCode;
  final String itemName;
  final int qty;
  final double salesValue;

  ParsedItem({required this.itemCode, required this.itemName, required this.qty, required this.salesValue});
}

class PdfService {
  /// Parses a Longbeach Craft Market "Item Sold Summary - Per Department" PDF.
  /// Even if the PDF text is jumbled together without spaces (e.g. LHDLHDE006Rustic Bag7.000133.00)
  /// this extracts the Code, Qty, and Sales Value.
  Future<List<ParsedItem>> parseLongbeachReport(List<int> bytes, List<CompanyPersonnel> personnel) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }
    document.dispose();

    final String fullText = buffer.toString();

    // Regex explanation:
    // 1. ([A-Z]{2,}[A-Z0-9]*?\d+) -> Matches the item code (which might have department prefix attached, e.g. LHDLHDE006)
    // 2. ([a-zA-Z\s\(\)0-9\-]*?)    -> Matches the description non-greedily
    // 3. (\d+)\.(\d{3})           -> Matches Qty (always 3 decimal places e.g. 7.000)
    // 4. (\d+)\.(\d{2})           -> Matches Sales Value (always 2 decimal places e.g. 133.00)
    final RegExp rowRegex = RegExp(r'([A-Z]{2,}[A-Z0-9]*?\d+)([a-zA-Z\s\(\)0-9\-]*?)(\d+)\.(\d{3})(\d+)\.(\d{2})');
    
    final matches = rowRegex.allMatches(fullText);

    final Map<String, ParsedItem> merged = {};

    for (final match in matches) {
      String codeRaw = match.group(1)!;
      String descRaw = match.group(2)?.trim() ?? '';
      final int qtyInt = int.parse(match.group(3)!);
      final double qtyDec = double.parse('0.${match.group(4)!}');
      final int priceInt = int.parse(match.group(5)!);
      final double priceDec = double.parse('0.${match.group(6)!}');

      final double qtyFloat = qtyInt + qtyDec;
      final int qty = qtyFloat.round();
      final double salesValue = priceInt + priceDec;

      if (qty == 0) continue; // Skip zero-qty lines

      // Clean the codeRaw: The PDF might prepend the department code (e.g., LHD -> LHDLHDE006).
      // We check our known personnel prefixes to strip the department code if possible.
      String? cleanCode;
      for (var p in personnel) {
        final prefix = p.codePrefix;
        final idx = codeRaw.indexOf(prefix);
        if (idx != -1) {
          cleanCode = codeRaw.substring(idx); // Extract only from the personnel prefix onwards
          break;
        }
      }
      
      // If none of our personnel prefixes matched, we just use the raw code.
      // (The user can "Ignore" these anomalies in the UI).
      final finalCode = cleanCode ?? codeRaw;

      if (merged.containsKey(finalCode)) {
        merged[finalCode] = ParsedItem(
          itemCode: finalCode,
          itemName: merged[finalCode]!.itemName.isEmpty ? descRaw : merged[finalCode]!.itemName,
          qty: merged[finalCode]!.qty + qty,
          salesValue: merged[finalCode]!.salesValue + salesValue,
        );
      } else {
        merged[finalCode] = ParsedItem(itemCode: finalCode, itemName: descRaw, qty: qty, salesValue: salesValue);
      }
    }

    return merged.values.toList();
  }
}
