import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class ReceiptService {
  
  // ── Shop / Mandi Order Receipt ─────────────────────────────────────────────
  static Future<void> generateAndShareReceipt(dynamic order) async {
    final pdf = pw.Document();
    final items = order['items'] as List;
    final date = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(order['created_at']));
    final orderId = order['id'].toString().substring(0, 8).toUpperCase();
    final profile = order['profiles'] ?? {};
    final bool isMandi = order['is_booking'] == true;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Professional Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(isMandi ? 'MANDI MARKETPLACE DIRECT' : 'CAMPUS DAILY NEEDS STORE', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.indigo900)),
                      pw.Text('Official Transaction Invoice', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('ORDER RECEIPT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.indigo900)),
                      pw.Text('#$orderId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
              pw.SizedBox(height: 16),

              // Customer / Logistics Details Group
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(profile['full_name']?.toString().toUpperCase() ?? 'CAMPUS MEMBER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text(profile['email']?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Phone: ${profile['phone_no'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('LOGISTICS DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Method: ${order['payment_method'] ?? 'UPI'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Delivery: ${order['delivery_type'] ?? 'Pickup'}', style: const pw.TextStyle(fontSize: 10)),
                        if (order['delivery_address'] != null)
                          pw.Text('Address: ${order['delivery_address']}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Items Breakdown Table
              pw.Text('BREAKDOWN OF CHARGES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                headers: ['ITEM DESCRIPTION', 'QUANTITY / WEIGHT', 'UNIT RATE', 'TOTAL PRICE'],
                data: items.map((it) {
                  final price = (it['price'] as num? ?? 0.0).toDouble();
                  final qty = (it['qty'] as num? ?? 1).toInt();
                  final wQty = it['weight_qty'] != null ? (it['weight_qty'] as num).toDouble() : null;
                  final wUnit = it['weight_unit']?.toString();
                  
                  String qtyWeightStr = qty.toString();
                  double totalMultiplier = qty.toDouble();
                  if (wQty != null && wQty != 1.0) {
                    qtyWeightStr = '$qty x ${wQty} ${wUnit ?? 'kg'}';
                    totalMultiplier = qty * wQty;
                  }
                  return [
                    it['name']?.toString().toUpperCase() ?? 'ITEM',
                    qtyWeightStr,
                    'Rs. ${price.toStringAsFixed(2)}',
                    'Rs. ${(price * totalMultiplier).toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),

              // Totals block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('GRAND TOTAL: Rs. ${(order['total_price'] as num? ?? 0.0).toStringAsFixed(2)}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.indigo900)),
                      pw.Text('Tax inclusive. Powered by Campus Connect.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Center(child: pw.Text('THANK YOU FOR SUPPORTING SUSTAINABLE CAMPUS ECONOMIES.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_$orderId.pdf');
    }
  }

  // ── Hostel / Mess Rent & Electricity Receipt ────────────────────────────────
  static Future<void> generateFiscalReceipt(dynamic col, String? studentName) async {
    final pdf = pw.Document();
    final date = DateFormat('MMM dd, yyyy').format(DateTime.parse(col['created_at']));
    final receiptId = col['id'].toString().substring(0, 8).toUpperCase();
    final type = col['collection_type'] ?? 'PAYMENT';

    // Advanced detailed attributes
    final baseRent = (col['base_rent'] as num? ?? 6500.0).toDouble();
    final electricityCharges = (col['electricity_charges'] as num? ?? 0.0).toDouble();
    final totalAmount = (col['amount'] as num? ?? (baseRent + electricityCharges)).toDouble();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CAMPUS ACCOMMODATION SERVICES', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.indigo900)),
                      pw.Text('Monthly Room Rent & Utilities Statement', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FISCAL INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.indigo900)),
                      pw.Text('REF: #$receiptId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
              pw.SizedBox(height: 16),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RESIDENT MEMBER:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(studentName?.toUpperCase() ?? 'CAMPUS RESIDENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.Text('Status: Verified Tenant', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYMENT METRICS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Date Issued: $date', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Mode: ${col['payment_method'] ?? 'Digital Wallet/UPI'}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Breakdown Table
              pw.Text('ITEMIZED BILLING:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                headers: ['BILLING COMPONENT', 'BASE PRICE', 'CHARGES / EXTRA', 'NET PAYABLE'],
                data: [
                  [
                    'Base Rent (${DateFormat('MMMM yyyy').format(DateTime.parse(col['created_at']))})',
                    'Rs. ${baseRent.toStringAsFixed(2)}',
                    'Rs. 0.00',
                    'Rs. ${baseRent.toStringAsFixed(2)}'
                  ],
                  [
                    'Electricity Surcharge (Delta Consumption)',
                    'Rs. 0.00',
                    'Rs. ${electricityCharges.toStringAsFixed(2)}',
                    'Rs. ${electricityCharges.toStringAsFixed(2)}'
                  ]
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('TOTAL PAID: Rs. ${totalAmount.toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.indigo900)),
                ],
              ),
              if (col['remark'] != null) ...[
                pw.SizedBox(height: 24),
                pw.Text('OFFICIAL AUDIT NOTES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                pw.Text(col['remark'].toString(), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic)),
              ],
              pw.Spacer(),
              pw.Center(child: pw.Text('ELECTRONICALLY CERTIFIED STATEMENT OF ACCOMMODATION ACCOUNTS.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_${type.toUpperCase()}_$receiptId.pdf');
    }
  }

  // ── Employee Salary Slip Receipt ───────────────────────────────────────────
  static Future<void> generateSalaryReceipt(dynamic record, String? employeeName) async {
    final pdf = pw.Document();
    final date = DateFormat('MMM dd, yyyy').format(DateTime.now());
    final slipId = record['id'].toString().substring(0, 8).toUpperCase();
    final month = record['month'] ?? 'Current Month';

    // Detailed metrics
    final baseSalary = (record['salary_amount'] as num? ?? 0.0).toDouble();
    final allowance = (record['allowances'] as num? ?? 0.0).toDouble();
    final advances = (record['advances_taken'] as num? ?? 0.0).toDouble();
    final deductions = (record['deductions'] as num? ?? 0.0).toDouble() + advances;
    final leavesTaken = (record['leaves_taken'] as num? ?? 0).toInt();
    final netPaid = baseSalary + allowance - deductions;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CAMPUS PERSONNEL HUB', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.indigo900)),
                      pw.Text('Official Monthly Payslip & Remuneration', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYSLIP STATEMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.indigo900)),
                      pw.Text('PAYSLIP #$slipId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
              pw.SizedBox(height: 16),

              // Staff details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EMPLOYEE NAME:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(employeeName?.toUpperCase() ?? 'STAFF MEMBER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.Text('Pay Period: $month', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('DISPATCH METRICS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Leaves Logged: $leavesTaken', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Date Disbursed: $date', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Itemized Table
              pw.Text('PAY COMPONENT STRUCTURE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                headers: ['COMPENSATION EARNINGS', 'AMOUNT', 'DEDUCTIONS & ADVANCES', 'AMOUNT'],
                data: [
                  [
                    'Base Employee Salary',
                    'Rs. ${baseSalary.toStringAsFixed(2)}',
                    'Advances Deductions',
                    'Rs. ${advances.toStringAsFixed(2)}'
                  ],
                  [
                    'Professional Allowances',
                    'Rs. ${allowance.toStringAsFixed(2)}',
                    'Unpaid Leaves Penalty',
                    'Rs. ${(deductions - advances).toStringAsFixed(2)}'
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Earnings: Rs. ${(baseSalary + allowance).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Total Deductions: Rs. ${deductions.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Text('NET DISBURSED: Rs. ${netPaid.toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.indigo900)),
                ],
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text('CONFIDENTIAL PAYSLIP. GENERATED ELECTRONICALLY FOR STAFF DISPATCH RECORDS.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'PAYSLIP_$slipId.pdf');
    }
  }
}
