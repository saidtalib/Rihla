import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/currencies.dart';

/// Result of scanning a receipt image: extracted amount, currency, and optional description.
class ReceiptScanResult {
  final double? amount;
  final String? currency;
  final String? description;
  final String rawText;

  const ReceiptScanResult({
    this.amount,
    this.currency,
    this.description,
    this.rawText = '',
  });

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasCurrency => currency != null && currency!.isNotEmpty;
}

/// Service to scan receipt images with ML Kit and parse amount/currency/description.
class ReceiptScanService {
  ReceiptScanService._();
  static final ReceiptScanService instance = ReceiptScanService._();

  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// All known currency codes for regex matching (e.g. SAR, USD, OMR).
  static final Set<String> _currencyCodes = {
    ...kTopCurrencyCodes,
    ...kGulfCurrencyCodes,
    'EUR', 'GBP', 'JPY', 'CNY', 'AUD', 'CAD', 'CHF', 'HKD', 'SGD',
    'INR', 'THB', 'MYR', 'IDR', 'PHP', 'VND', 'TRY', 'MXN', 'BRL',
  };

  /// Scan a receipt from a file path (e.g. from image_picker).
  /// Returns [ReceiptScanResult] with amount, currency, and description if detected.
  /// ML Kit runs on Android/iOS only; on web/desktop returns empty result.
  Future<ReceiptScanResult> scanFromFile(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _recognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      if (fullText.isEmpty) return ReceiptScanResult(rawText: fullText);

      return _parseReceiptText(fullText);
    } catch (e) {
      debugPrint('[ReceiptScanService] scanFromFile error: $e');
      return const ReceiptScanResult(rawText: '');
    }
  }

  /// Parse receipt text to find total amount, currency, and a short description.
  ReceiptScanResult _parseReceiptText(String text) {
    final lines = text.split(RegExp(r'[\n\r]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty) return ReceiptScanResult(rawText: text);

    double? amount;
    String? currency;

    // 1) Look for a line containing "total" / "TOTAL" / "sum" and then a number + optional currency
    final totalPattern = RegExp(
      r'(?:total|TOTAL|sum|grand\s+total)\s*:?\s*([\d\s,.]+)\s*([A-Z]{2,3})?',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = totalPattern.firstMatch(line);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(RegExp(r'[\s]'), '').replaceAll(',', '.');
        final parsed = double.tryParse(amountStr ?? '');
        if (parsed != null && parsed > 0) {
          amount = parsed;
          final code = match.group(2);
          if (code != null && _currencyCodes.contains(code.toUpperCase())) {
            currency = code.toUpperCase();
          }
          break;
        }
      }
    }

    // 2) If no total line, look for any line ending with amount + currency (e.g. "123.45 SAR")
    if (amount == null) {
      final amountCurrencyPattern = RegExp(
        r'([\d\s,.]+)\s*([A-Z]{2,3})\s*$',
        caseSensitive: false,
        multiLine: true,
      );
      for (final line in lines.reversed) {
        final match = amountCurrencyPattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1)?.replaceAll(RegExp(r'[\s]'), '').replaceAll(',', '.');
          final parsed = double.tryParse(amountStr ?? '');
          final code = match.group(2)?.toUpperCase();
          if (parsed != null && parsed > 0 && code != null && _currencyCodes.contains(code)) {
            amount = parsed;
            currency = code;
            break;
          }
        }
      }
    }

    // 3) If still no currency, try to find currency elsewhere in text
    if (currency == null) {
      for (final code in _currencyCodes) {
        if (text.toUpperCase().contains(code)) {
          currency = code;
          break;
        }
      }
    }

    // 4) Description: first non-empty line (often merchant name) or "Receipt"
    String? description;
    if (lines.isNotEmpty) {
      final first = lines.first;
      if (first.length <= 60 && !RegExp(r'^[\d\s,.\$€£¥]+$').hasMatch(first)) {
        description = first;
      }
    }
    if (description == null || description.isEmpty) {
      description = 'Receipt';
    }

    return ReceiptScanResult(
      amount: amount,
      currency: currency,
      description: description,
      rawText: text,
    );
  }

  void dispose() {
    _recognizer.close();
  }
}
