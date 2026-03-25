import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  static Future<void> generateAndShareReceipt(dynamic order) async {
    final pdf = pw.Document();
    final items = order['items'] as List;
    final date = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(order['created_at']));
    final orderId = order['id'].toString().substring(0, 8).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DAILY NEEDS STORE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                    pw.Text('ORDER #$orderId', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('DATE: $date'),
              pw.Text('STATUS: ${order['order_status']}'),
              pw.Text('DELIVERY: ${order['delivery_type'] ?? 'Pickup'}'),
              if (order['delivery_address'] != null) pw.Text('ADDRESS: ${order['delivery_address']}'),
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['ITEM', 'QTY', 'UNIT PRICE', 'TOTAL'],
                data: items.map((it) {
                  final price = (it['price'] as num).toDouble();
                  final qty = (it['qty'] as num).toInt();
                  return [
                    it['name'],
                    qty.toString(),
                    'Rs. ${price.toStringAsFixed(2)}',
                    'Rs. ${(price * qty).toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('GRAND TOTAL: Rs. ${(order['total_price'] as num).toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ],
              ),
              pw.SizedBox(height: 50),
              pw.Center(child: pw.Text('THANK YOU FOR YOUR MISSION CONTINUATION.', style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_$orderId.pdf');
  }

  static Future<void> generateFiscalReceipt(dynamic col, String? studentName) async {
    final pdf = pw.Document();
    final date = DateFormat('MMM dd, yyyy').format(DateTime.parse(col['created_at']));
    final receiptId = col['id'].toString().substring(0, 8).toUpperCase();
    final type = col['collection_type'] ?? 'PAYMENT';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CAMPUS $type RECEIPT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                    pw.Text('REF #$receiptId', style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('RESIDENT: ${studentName?.toUpperCase() ?? 'CAMPUS RESIDENT'}'),
              pw.Text('DATE: $date'),
              pw.Text('PAYMENT METHOD: ${col['payment_method'] ?? 'UPI/CASH'}'),
              pw.SizedBox(height: 40),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['DESCRIPTION', 'AMOUNT'],
                data: [
                  [
                    '$type - ${DateFormat('MMMM yyyy').format(DateTime.parse(col['created_at']))}',
                    'Rs. ${(col['amount'] as num).toStringAsFixed(2)}',
                  ],
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                   pw.Text('TOTAL PAID: Rs. ${(col['amount'] as num).toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ],
              ),
              if (col['remark'] != null) ...[
                pw.SizedBox(height: 20),
                pw.Text('REMARKS: ${col['remark']}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
              pw.Spacer(),
              pw.Center(child: pw.Text('ELECTRONICALLY GENERATED OFFICIAL CAMPUS RECEIPT.', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_$type\_$receiptId.pdf');
  }
}
