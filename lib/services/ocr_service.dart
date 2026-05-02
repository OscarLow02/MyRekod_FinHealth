import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// On-device OCR service for extracting structured data from Malaysian receipts.
///
/// Uses Google ML Kit's [TextRecognizer] for **local, offline** text recognition.
/// This service is stateless — each call to [extractReceiptData] opens and closes
/// the recognizer to avoid holding native resources.
///
/// ### Extraction Strategy
/// Malaysian receipts are highly variable. The parsing pipeline uses a
/// multi-fallback approach for each field:
///
/// | Field    | Primary Strategy                              | Fallback                                     |
/// |----------|-----------------------------------------------|----------------------------------------------|
/// | Amount   | Keyword match (TOTAL, AMT, JUMLAH) near "RM"  | Largest monetary value in the bottom third    |
/// | Date     | Regex for DD/MM/YYYY, DD-MM-YYYY, DD/MM/YY    | —                                            |
/// | Vendor   | First 1-3 non-empty, non-numeric lines         | —                                            |
class OcrService {
  OcrService._();

  // ── Public API ───────────────────────────────────────────────────────────

  /// Processes a receipt image at [imagePath] and returns a map of extracted
  /// fields. All values are **nullable** — a `null` value means the field
  /// could not be confidently extracted (e.g. blurry image).
  ///
  /// Returned keys:
  /// - `amount`  → `double?`  — The receipt total in MYR.
  /// - `date`    → `String?`  — ISO-8601 date string (YYYY-MM-DD).
  /// - `vendor`  → `String?`  — Best-guess vendor/merchant name.
  /// - `rawText` → `String`   — Full OCR dump for debugging / manual review.
  static Future<Map<String, dynamic>> extractReceiptData(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final String rawText = recognizedText.text;

      // If the recognizer returned nothing, bail out early.
      if (rawText.trim().isEmpty) {
        return {
          'amount': null,
          'date': null,
          'vendor': null,
          'rawText': '',
        };
      }

      // Build a flat list of lines for sequential parsing.
      final List<String> allLines = recognizedText.blocks
          .expand((block) => block.lines)
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final double? amount = _extractAmount(allLines);
      final String? date = _extractDate(allLines);
      final String? vendor = _extractVendor(allLines);

      return {
        'amount': amount,
        'date': date,
        'vendor': vendor,
        'rawText': rawText,
      };
    } catch (e) {
      // Graceful degradation — return nulls instead of crashing.
      return {
        'amount': null,
        'date': null,
        'vendor': null,
        'rawText': 'OCR Error: $e',
      };
    } finally {
      // Always release native resources.
      await textRecognizer.close();
    }
  }

  // Standard iOS/Android Image Persistence logic
  static Future<String> standardSecureCapturedImage(String tempPath) async {
    try {
      // Standard access to the standard application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final String permanentDir = p.join(appDir.path, 'receipts');

      // Standard HCI check for standard directory existence
      await Directory(permanentDir).create(recursive: true);

      // Standard file naming utilizing standardized timestamp to prevent standard collisions
      final String fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempPath)}';
      final String permanentPath = p.join(permanentDir, fileName);

      // Standard synchronous standard file copy procedure
      await File(tempPath).copy(permanentPath);

      return permanentPath; // Returns the standardized permanent file URI standard
    } catch (e) {
      debugPrint("CRITICAL Standard Exception during Standard Image Persistence: $e");
      return tempPath; // Fallback to standard temporary if standard failure occurs
    }
  }

  /// Dynamically resolves a stored image path, accounting for iOS Sandbox UUID changes.
  static Future<String?> resolveImagePath(String? originalPath) async {
    if (originalPath == null || originalPath.isEmpty) return null;

    final file = File(originalPath);
    if (await file.exists()) return originalPath;

    // Reconstruct for iOS Sandbox UUID change
    try {
      final fileName = originalPath.split('/').last;
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = p.join(appDir.path, 'receipts', fileName);
      if (await File(newPath).exists()) return newPath;
    } catch (_) {}

    return null;
  }

  // ── Amount Extraction ────────────────────────────────────────────────────

  /// Attempts to find the receipt total using two strategies:
  ///
  /// 1. **Keyword match**: Scans for lines containing "TOTAL", "AMT",
  ///    "JUMLAH", "GRAND TOTAL", or "NET" followed by a monetary value.
  /// 2. **Fallback**: If no keyword match is found, selects the largest
  ///    monetary value in the **bottom third** of the receipt. This heuristic
  ///    works because Malaysian receipts typically place the total near the
  ///    bottom, and it should be the largest number (sum of line items).
  static double? _extractAmount(List<String> lines) {
    try {
      // ── Strategy 1: Keyword-based extraction ──────────────────────────

      // Matches "RM 12.50", "RM12.50", "12.50", with optional thousands separator.
      final moneyPattern = RegExp(
        r'(?:RM\s*)?(\d{1,3}(?:[,]\d{3})*\.\d{2})',
        caseSensitive: false,
      );

      // Keywords that typically precede the total amount on Malaysian receipts.
      final totalKeywords = RegExp(
        r'\b(GRAND\s*TOTAL|TOTAL|JUMLAH|AMT|AMOUNT\s*DUE|NET\s*TOTAL|NET\s*AMT)\b',
        caseSensitive: false,
      );

      for (final line in lines) {
        if (totalKeywords.hasMatch(line)) {
          final match = moneyPattern.firstMatch(line);
          if (match != null) {
            final cleaned = match.group(1)!.replaceAll(',', '');
            final value = double.tryParse(cleaned);
            if (value != null && value > 0) return value;
          }

          // Sometimes the amount is on the *next* line after the keyword.
          final idx = lines.indexOf(line);
          if (idx + 1 < lines.length) {
            final nextMatch = moneyPattern.firstMatch(lines[idx + 1]);
            if (nextMatch != null) {
              final cleaned = nextMatch.group(1)!.replaceAll(',', '');
              final value = double.tryParse(cleaned);
              if (value != null && value > 0) return value;
            }
          }
        }
      }

      // ── Strategy 2: Largest value in bottom third ─────────────────────

      final bottomThirdStart = (lines.length * 2 / 3).floor();
      final bottomLines = lines.sublist(
        bottomThirdStart.clamp(0, lines.length),
      );

      double? largest;
      for (final line in bottomLines) {
        final matches = moneyPattern.allMatches(line);
        for (final m in matches) {
          final cleaned = m.group(1)!.replaceAll(',', '');
          final value = double.tryParse(cleaned);
          if (value != null && value > 0) {
            if (largest == null || value > largest) {
              largest = value;
            }
          }
        }
      }

      return largest;
    } catch (_) {
      return null;
    }
  }

  // ── Date Extraction ──────────────────────────────────────────────────────

  /// Extracts the first recognizable date from the receipt text.
  ///
  /// Supported formats (Malaysian standard):
  /// - `DD/MM/YYYY`  (e.g. 28/04/2026)
  /// - `DD-MM-YYYY`  (e.g. 28-04-2026)
  /// - `DD/MM/YY`    (e.g. 28/04/26)
  /// - `DD-MM-YY`    (e.g. 28-04-26)
  /// - `DD.MM.YYYY`  (e.g. 28.04.2026)
  ///
  /// Returns an ISO-8601 date string (YYYY-MM-DD) or `null`.
  static String? _extractDate(List<String> lines) {
    try {
      // Matches DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY and 2-digit year variants.
      final datePattern = RegExp(
        r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})',
      );

      for (final line in lines) {
        final match = datePattern.firstMatch(line);
        if (match != null) {
          final day = int.tryParse(match.group(1)!);
          final month = int.tryParse(match.group(2)!);
          var year = int.tryParse(match.group(3)!);

          if (day == null || month == null || year == null) continue;

          // Expand 2-digit year to 4-digit (assume 2000s).
          if (year < 100) year += 2000;

          // Basic sanity checks to avoid false positives (e.g. phone numbers).
          if (month < 1 || month > 12) continue;
          if (day < 1 || day > 31) continue;
          if (year < 2000 || year > 2099) continue;

          return '${year.toString().padLeft(4, '0')}-'
              '${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}';
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Vendor Extraction ────────────────────────────────────────────────────

  /// Extracts the vendor name from the receipt.
  ///
  /// Heuristic: The merchant name is almost always in the **first 3 lines**
  /// of a Malaysian receipt. We skip lines that look like:
  /// - Pure numbers (phone numbers, registration IDs)
  /// - Known non-vendor patterns (GST/SST IDs, timestamps, addresses with
  ///   postcodes)
  /// - Very short lines (< 3 chars, likely OCR noise)
  ///
  /// Returns the first qualifying line, or `null` if nothing passes the filter.
  static String? _extractVendor(List<String> lines) {
    try {
      // Patterns that indicate a line is NOT a vendor name.
      final skipPatterns = [
        RegExp(r'^\d+$'),                           // Pure numbers
        RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}'), // Dates
        RegExp(r'\d{5,}'),                           // Long digit sequences (phone, SST ID)
        RegExp(r'^(GST|SST|TAX)\s*(ID|NO|REG)', caseSensitive: false),
        RegExp(r'^\s*(tel|fax|phone|hp)', caseSensitive: false),
        RegExp(r'^\d{2}:\d{2}'),                     // Timestamps (HH:MM)
        RegExp(r'^[-=_*]+$'),                        // Separator lines
      ];

      // Only inspect the first 5 lines (generous) to find the vendor.
      final candidateLines = lines.take(5);

      for (final line in candidateLines) {
        if (line.length < 3) continue;

        bool skip = false;
        for (final pattern in skipPatterns) {
          if (pattern.hasMatch(line)) {
            skip = true;
            break;
          }
        }
        if (skip) continue;

        // Clean up common OCR artifacts and return.
        final cleaned = line
            .replaceAll(RegExp(r'[*=\-_]{2,}'), '') // Remove separator chars
            .trim();

        if (cleaned.length >= 3) {
          return _toTitleCase(cleaned);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Converts a string to Title Case for consistent vendor name formatting.
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Keep short words like "SDN", "BHD" uppercase (Malaysian business suffixes).
      if (word.length <= 3 && word == word.toUpperCase()) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
