import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Regex match', () {
    final text = File('raw_pdf_text.txt').readAsStringSync();
    
    // We want to capture the actual item code (e.g. LHDE006). The department prefix (LHD) sits right in front of it.
    // LHDLHDE006 -> item code is LHDE006. So we look for something ending in digits.
    // This matches 2+ uppercase letters followed by 1+ digits.
    final RegExp regex = RegExp(r'([A-Z]{2,}[A-Z0-9]*?\d+)[a-zA-Z\s\(\)0-9\-]*?(\d+)\.(\d{3})(\d+)\.(\d{2})');
    
    // Let's also split by LHD just to make it easier to separate records on the same line
    // Or just global match over the string!
    final matches = regex.allMatches(text);
    print('Found \${matches.length} matches');
    
    for (final match in matches) {
      final codeRaw = match.group(1)!;
      // If code raw is LHDLHDE006, we can strip the preceeding LHD if we want, or just take the last part.
      final qtyInt = match.group(2)!;
      final qtyDec = match.group(3)!;
      final priceInt = match.group(4)!;
      final priceDec = match.group(5)!;
      
      print('Code: $codeRaw | Qty: $qtyInt.$qtyDec | Price: $priceInt.$priceDec');
    }
  });
}
