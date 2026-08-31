import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/security/crypto/encrypted_file_service.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/finance_transaction.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseRepositoryProvider),
  ),
);

class ReceiptDraft {
  const ReceiptDraft({
    required this.id,
    required this.imagePath,
    required this.merchant,
    required this.total,
    required this.purchasedAt,
    required this.rawText,
    required this.status,
    required this.documentType,
    this.dueAt,
    this.referenceNumber,
    this.units,
  });
  final int id;
  final String imagePath;
  final String merchant;
  final double total;
  final DateTime purchasedAt;
  final String rawText;
  final String status;
  final ReceiptDocumentType documentType;
  final DateTime? dueAt;
  final String? referenceNumber;
  final double? units;
}

class ReceiptRepository {
  ReceiptRepository(
    this._database,
    this._expenses, {
    EncryptedFileService? files,
  }) : _files = files ?? EncryptedFileService();
  final AppDatabase _database;
  final ExpenseRepository _expenses;
  final EncryptedFileService _files;

  Future<ReceiptDraft> scan(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final receiptDirectory = Directory(p.join(directory.path, 'receipts'));
    await receiptDirectory.create(recursive: true);
    final destination = p.join(
      receiptDirectory.path,
      '${const Uuid().v4()}.mmr',
    );
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String rawText = '';
    try {
      rawText = (await recognizer.processImage(
        InputImage.fromFilePath(sourcePath),
      )).text;
    } finally {
      await recognizer.close();
    }
    final parsed = ReceiptTextParser.parse(rawText);
    await _files.encryptBytesToFile(
      bytes: await File(sourcePath).readAsBytes(),
      destination: File(destination),
      purpose: 'blob',
    );
    final id = await _database.database.insert('receipt_drafts', {
      'image_path': destination,
      'merchant': parsed.merchant,
      'total': parsed.total,
      'purchased_at': parsed.date.toIso8601String(),
      'raw_text': rawText,
      'document_type': parsed.documentType.name,
      'due_at': parsed.dueDate?.toIso8601String(),
      'reference_number': parsed.referenceNumber,
      'units': parsed.units,
      'status': 'draft',
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': _database.ownerId,
    });
    return ReceiptDraft(
      id: id,
      imagePath: destination,
      merchant: parsed.merchant,
      total: parsed.total,
      purchasedAt: parsed.date,
      rawText: rawText,
      status: 'draft',
      documentType: parsed.documentType,
      dueAt: parsed.dueDate,
      referenceNumber: parsed.referenceNumber,
      units: parsed.units,
    );
  }

  Future<List<ReceiptDraft>> drafts() async {
    final rows = await _database.database.query(
      'receipt_drafts',
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Uint8List> imageBytes(ReceiptDraft draft) =>
      _files.decryptFile(File(draft.imagePath), purpose: 'blob');

  Future<int> confirm({
    required int id,
    required String merchant,
    required double total,
    required DateTime purchasedAt,
    required int categoryId,
  }) async {
    if (merchant.trim().isEmpty || total <= 0) {
      throw const FormatException('Confirm a merchant and positive total.');
    }
    final transactionId = await _expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: total,
        categoryId: categoryId,
        categoryName: '',
        occurredAt: purchasedAt,
        description: merchant.trim(),
        source: TransactionSource.receipt,
        sourceRecordId: '$id',
        note: 'Created from reviewed receipt',
      ),
    );
    await _database.database.update(
      'receipt_drafts',
      {
        'merchant': merchant.trim(),
        'total': total,
        'purchased_at': purchasedAt.toIso8601String(),
        'status': 'confirmed',
        'linked_transaction_id': transactionId,
      },
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return transactionId;
  }

  ReceiptDraft _fromRow(Map<String, Object?> row) => ReceiptDraft(
    id: row['id'] as int,
    imagePath: row['image_path'] as String,
    merchant: row['merchant'] as String? ?? '',
    total: (row['total'] as num?)?.toDouble() ?? 0,
    purchasedAt: row['purchased_at'] == null
        ? DateTime.now()
        : DateTime.parse(row['purchased_at'] as String),
    rawText: row['raw_text'] as String? ?? '',
    status: row['status'] as String,
    documentType: ReceiptDocumentType.values.byName(
      row['document_type'] as String? ?? 'receipt',
    ),
    dueAt: row['due_at'] == null
        ? null
        : DateTime.parse(row['due_at'] as String),
    referenceNumber: row['reference_number'] as String?,
    units: (row['units'] as num?)?.toDouble(),
  );
}

enum ReceiptDocumentType { receipt, fuelReceipt, electricityBill, otherBill }

class ReceiptFileMigrationService {
  ReceiptFileMigrationService(this._database, {EncryptedFileService? files})
    : _files = files ?? EncryptedFileService();

  final AppDatabase _database;
  final EncryptedFileService _files;

  Future<void> migrateLegacyFiles() async {
    final rows = await _database.database.query(
      'receipt_drafts',
      columns: ['id', 'image_path'],
    );
    for (final row in rows) {
      final oldFile = File(row['image_path']! as String);
      if (p.extension(oldFile.path) == '.mmr' || !await oldFile.exists()) {
        continue;
      }
      final destination = File(
        p.join(oldFile.parent.path, '${const Uuid().v4()}.mmr'),
      );
      await _files.encryptBytesToFile(
        bytes: await oldFile.readAsBytes(),
        destination: destination,
        purpose: 'blob',
      );
      await _database.database.update(
        'receipt_drafts',
        {'image_path': destination.path},
        where: 'id = ? AND image_path = ?',
        whereArgs: [row['id'], oldFile.path],
      );
      await oldFile.delete();
    }
  }
}

class ParsedReceipt {
  const ParsedReceipt({
    required this.merchant,
    required this.total,
    required this.date,
    required this.documentType,
    this.dueDate,
    this.referenceNumber,
    this.units,
  });
  final String merchant;
  final double total;
  final DateTime date;
  final ReceiptDocumentType documentType;
  final DateTime? dueDate;
  final String? referenceNumber;
  final double? units;
}

abstract final class ReceiptTextParser {
  static ParsedReceipt parse(String text, {DateTime? now}) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final totalPattern = RegExp(
      r'(?:total|amount|net)\D{0,12}(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double total = 0;
    for (final line in lines.reversed) {
      final match = totalPattern.firstMatch(line);
      if (match != null) {
        total = double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
        if (total > 0) break;
      }
    }
    if (total == 0) {
      final numbers = RegExp(r'\b\d[\d,]*\.\d{2}\b')
          .allMatches(text)
          .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0);
      if (numbers.isNotEmpty) total = numbers.reduce((a, b) => a > b ? a : b);
    }
    final merchant = lines.firstWhere(
      (line) => RegExp(r'[A-Za-z]{3}').hasMatch(line),
      orElse: () => 'Receipt expense',
    );
    final lower = text.toLowerCase();
    final documentType = lower.contains('kwh') || lower.contains('meter')
        ? ReceiptDocumentType.electricityBill
        : lower.contains('fuel') ||
              lower.contains('petrol') ||
              lower.contains('diesel')
        ? ReceiptDocumentType.fuelReceipt
        : lower.contains('due date') || lower.contains('invoice')
        ? ReceiptDocumentType.otherBill
        : ReceiptDocumentType.receipt;
    final unitsMatch = RegExp(
      r'(?:units?|kwh)\D{0,10}(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    final referenceMatch = RegExp(
      r'(?:reference|ref|consumer|account)\s*(?:no|number)?\s*[:#-]?\s*([a-z0-9-]{5,})',
      caseSensitive: false,
    ).firstMatch(text);
    final dueMatch = RegExp(
      r'(?:due\s*date)\D{0,8}(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    DateTime? dueDate;
    if (dueMatch != null) {
      final year = int.parse(dueMatch.group(3)!);
      dueDate = DateTime(
        year < 100 ? 2000 + year : year,
        int.parse(dueMatch.group(2)!),
        int.parse(dueMatch.group(1)!),
      );
    }
    return ParsedReceipt(
      merchant: merchant,
      total: total,
      date: now ?? DateTime.now(),
      documentType: documentType,
      dueDate: dueDate,
      referenceNumber: referenceMatch?.group(1),
      units: unitsMatch == null ? null : double.tryParse(unitsMatch.group(1)!),
    );
  }
}
