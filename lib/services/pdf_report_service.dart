import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_model.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import 'finance_calculator.dart';

/// Builds the transactions PDF.
///
/// The built-in PDF font (Helvetica) only covers Latin characters, so amounts
/// use the currency code ("INR 1,250.00") instead of a symbol like ₹, and
/// non-Latin text in notes is drawn as placeholder boxes.
class PdfReportService {
  PdfReportService._();

  static Future<Uint8List> build({
    required List<TransactionModel> transactions,
    required Currency currency,
    required String periodLabel,
    DateTime? generatedAt,
  }) {
    final txs = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    final summary = FinanceCalculator.summarize(txs);
    final now = generatedAt ?? DateTime.now();

    String money(int minor) {
      final code = Currency(
        currency.code,
        '${currency.code} ',
        '',
        currency.grouping,
      );
      return Money.format(minor, code);
    }

    final doc = pw.Document(
      title: 'Expense Tracker – $periodLabel',
      creator: 'Expense Tracker',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Expense Tracker – Transactions',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Period: $periodLabel'),
          pw.Text(
            'Generated: ${formatDate(now)} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _stat('Income', money(summary.incomeMinor)),
              _stat('Expenses', money(summary.expenseMinor)),
              _stat('Net', money(summary.netMinor)),
              _stat('Transactions', '${summary.count}'),
            ],
          ),
          pw.SizedBox(height: 16),
          if (txs.isEmpty)
            pw.Text('No transactions in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Note',
                'Category',
                'Payment',
                'Type',
                'Amount',
              ],
              data: [
                for (final t in txs)
                  [
                    formatDate(t.date),
                    t.note,
                    t.category,
                    t.paymentType,
                    t.isIncome ? 'Income' : 'Expense',
                    money(t.amountMinor),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {5: pw.Alignment.centerRight},
            ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _stat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
