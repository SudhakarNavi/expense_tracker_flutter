import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../providers/transaction_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final monthlyExpense = provider.lastSixMonthExpenses;
    final categoryTotals = provider.categoryTotals;
    final weeklyTotals = provider.weeklyExpenseTrend;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportSection(
              title: 'Monthly Expense',
              child: _BarChart(data: monthlyExpense),
            ),
            const SizedBox(height: 18),
            _ReportSection(
              title: 'Category Breakdown',
              child: _PieChart(data: categoryTotals),
            ),
            const SizedBox(height: 18),
            _ReportSection(
              title: 'Weekly Trends',
              child: _LineTrend(data: weeklyTotals),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = [...provider.transactions];
    transactions.sort((a, b) => a.date.compareTo(b.date));

    final pdf = pw.Document();

    final tableData = transactions.map((t) {
      return [
        t.note,
        t.category,
        t.paymentType,
        t.isIncome ? 'Income' : 'Expense',
        t.amount.toStringAsFixed(2),
        '${t.date.day}/${t.date.month}/${t.date.year}',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Expense Tracker - Transactions', style: pw.TextStyle(fontSize: 20))),
          pw.SizedBox(height: 8),
          pw.Text('Generated: ${DateTime.now()}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Note', 'Category', 'Payment', 'Type', 'Amount', 'Date'],
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export PDF'),
          content: const Text('Would you like to share the PDF or save it to device?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'share'), child: const Text('Share')),
            TextButton(onPressed: () => Navigator.pop(context, 'downloads'), child: const Text('Save to Downloads')),
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ],
        );
      },
    );

    if (action == 'share') {
      await Printing.sharePdf(bytes: bytes, filename: 'transactions.pdf');
      return;
    }

    if (action == 'downloads') {
      // Try public downloads or external storage, fall back to app documents
      try {
        String? savePath;
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final dir = await getDownloadsDirectory();
          if (dir != null) savePath = '${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
        } else if (Platform.isAndroid) {
          final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (dirs != null && dirs.isNotEmpty) {
            savePath = '${dirs.first.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
          }
        } else if (Platform.isIOS) {
          // iOS doesn't provide a public downloads directory; use app documents
          final dir = await getApplicationDocumentsDirectory();
          savePath = '${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        if (savePath == null) {
          final dir = await getApplicationDocumentsDirectory();
          savePath = '${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));
        }
      } catch (e) {
        // fallback to app documents
        try {
          final dir = await getApplicationDocumentsDirectory();
          final fallback = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await fallback.writeAsBytes(bytes);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${fallback.path}')));
          }
        } catch (e2) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e2')));
          }
        }
      }
    }
  }
}
class _ReportSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, double> data;

  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.entries.map((entry) {
        final value = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 72, child: Text(entry.key)),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Container(
                      height: 20,
                      width: (value / maxValue) * MediaQuery.of(context).size.width * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('₹${value.toStringAsFixed(0)}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PieChart extends StatelessWidget {
  final Map<String, double> data;

  const _PieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (sum, item) => sum + item);
    final entries = data.entries.toList();
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.brown, Colors.indigo];

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _PiePainter(entries, colors),
            child: Center(
              child: Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) {
          final percent = total == 0 ? 0 : (entry.value / total * 100);
          final index = entries.indexOf(entry);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 16, height: 16, color: colors[index % colors.length]),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text('${percent.toStringAsFixed(0)}%'),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final List<Color> colors;

  _PiePainter(this.entries, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    var startAngle = -3.14 / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < entries.length; i++) {
      final sweep = total == 0 ? 0.0 : (entries[i].value / total) * 3.14 * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2.8), startAngle, sweep, true, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineTrend extends StatelessWidget {
  final Map<String, double> data;

  const _LineTrend({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxValue = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _LinePainter(entries, maxValue),
          );
        },
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double maxValue;

  _LinePainter(this.entries, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < entries.length; i++) {
      final count = entries.length > 1 ? entries.length - 1 : 1;
      final x = (size.width / count.toDouble()) * i.toDouble();
      final y = size.height - (entries[i].value / maxValue) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.green);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
