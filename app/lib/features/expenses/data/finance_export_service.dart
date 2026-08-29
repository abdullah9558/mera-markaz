import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/finance_transaction.dart';
import 'expense_repository.dart';

final financeExportServiceProvider = Provider<FinanceExportService>(
  (ref) => FinanceExportService(ref.watch(expenseRepositoryProvider)),
);

class FinanceExportService {
  const FinanceExportService(this.repository);
  final ExpenseRepository repository;
  String _escape(String value) => '"${value.replaceAll('"', '""')}"';
  Future<File> csv() async {
    final values = await repository.all();
    final lines = <String>[
      'Date,Type,Category,Description,Amount,Payment Method,Note',
    ];
    for (final item in values) {
      lines.add(
        [
          DateFormat('yyyy-MM-dd').format(item.occurredAt),
          item.type.name,
          item.categoryName,
          item.description,
          item.amount.toStringAsFixed(2),
          item.paymentMethod ?? '',
          item.note ?? '',
        ].map(_escape).join(','),
      );
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(
        directory.path,
        'pakpocket-transactions-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
      ),
    );
    await file.writeAsString(lines.join('\r\n'), flush: true);
    return file;
  }

  Future<File> pdfReport() async {
    final values = await repository.all();
    final summary = await repository.summary();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('MeraMarkaz Financial Report')),
          pw.Text(
            'Generated ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Monthly income: PKR ${summary.monthIncome.toStringAsFixed(2)}',
              ),
              pw.Text(
                'Monthly expenses: PKR ${summary.monthExpense.toStringAsFixed(2)}',
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Type',
              'Category',
              'Description',
              'Amount',
            ],
            data: values
                .map(
                  (item) => [
                    DateFormat('yyyy-MM-dd').format(item.occurredAt),
                    item.type == TransactionType.income ? 'Income' : 'Expense',
                    item.categoryName,
                    item.description,
                    item.amount.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Records are exported from local device storage.'),
        ],
      ),
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(
        directory.path,
        'pakpocket-report-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf',
      ),
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }
}

class PlaintextExportCleaner {
  static Future<void> removeTemporaryExports() async {
    final directory = await getTemporaryDirectory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if ((name.startsWith('pakpocket-transactions-') &&
              name.endsWith('.csv')) ||
          (name.startsWith('pakpocket-report-') && name.endsWith('.pdf'))) {
        await entity.delete();
      }
    }
  }
}
