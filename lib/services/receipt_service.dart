import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'organization_settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Organization info with robust fallback
// ─────────────────────────────────────────────────────────────────────────────
String get _kOrgName => OrganizationSettingsService().companyName;
const _kTagline = 'Smart Campus ERP & Commercial Ecosystem';
String get _kAddress => OrganizationSettingsService().companyAddress;
String get _kPhone => OrganizationSettingsService().companyPhone;
String get _kGst => 'GSTIN: ${OrganizationSettingsService().storeGstin}';
String get _kEmail => OrganizationSettingsService().supportEmail;
String get _kWebsite => OrganizationSettingsService().website;

// Cached logo image for PDF rendering
pw.MemoryImage? _cachedPdfLogo;

Future<pw.MemoryImage?> _getPdfLogo() async {
  if (_cachedPdfLogo != null) return _cachedPdfLogo;
  try {
    final bytes = await rootBundle.load('assets/images/app_logo.png');
    _cachedPdfLogo = pw.MemoryImage(bytes.buffer.asUint8List());
    return _cachedPdfLogo;
  } catch (_) {
    return null;
  }
}


/// Builds the shared header that appears at the top of every PDF receipt.
pw.Widget _buildHeader({
  required String documentTitle,
  required String refId,
  String? subtitle,
  pw.MemoryImage? logoImage,
}) {
  final logo = logoImage ?? _cachedPdfLogo;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // ── Brand bar ──────────────────────────────────────────────────────────
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [PdfColor.fromInt(0xFF1E1B4B), PdfColor.fromInt(0xFF4338CA)],
            begin: pw.Alignment.centerLeft,
            end: pw.Alignment.centerRight,
          ),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Logo emblem + block
            pw.Row(
              children: [
                pw.Container(
                  width: 38,
                  height: 38,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: logo != null
                      ? pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        )
                      : pw.Center(
                          child: pw.Text(
                            'HC',
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFF4338CA),
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
                pw.SizedBox(width: 12),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _kOrgName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _kTagline,
                      style: const pw.TextStyle(color: PdfColor.fromInt(0xFFE0E7FF), fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
            // Document type badge
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    documentTitle,
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xFF3730A3),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'REF: #$refId',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      // ── Contact ribbon ────────────────────────────────────────────────────
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF5F3FF),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_kAddress, style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF6B7280))),
            pw.Row(
              children: [
                pw.Text('$_kPhone  |  $_kEmail  |  $_kGst',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF6B7280))),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
    ],
  );
}

/// Builds the shared footer line.
pw.Widget _buildFooter(String note) {
  return pw.Column(
    children: [
      pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB), thickness: 0.5),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(note, style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF9CA3AF))),
          pw.Text(_kWebsite, style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF9CA3AF))),
        ],
      ),
    ],
  );
}

/// Builds a labelled info cell for the details grid.
pw.Widget _infoCell(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF9CA3AF))),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1F2937))),
    ],
  );
}

class ReceiptService {

  // ── Shop / Mandi Order Receipt ─────────────────────────────────────────────
  static Future<void> generateAndShareReceipt(dynamic order) async {
    final pdf = pw.Document();
    final logo = await _getPdfLogo();
    final items = order['items'] as List;
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['created_at']));
    final orderId = order['id'].toString().substring(0, 8).toUpperCase();
    final profile = order['profiles'] ?? {};
    final bool isMandi = order['is_booking'] == true;

    // Compute breakdown
    double subTotal = 0;
    final itemRows = items.map((it) {
      final price = (it['price'] as num? ?? 0.0).toDouble();
      final qty = (it['qty'] as num? ?? 1).toInt();
      final wQty = it['weight_qty'] != null ? (it['weight_qty'] as num).toDouble() : null;
      final wUnit = it['weight_unit']?.toString() ?? 'kg';
      String qtyStr = '$qty';
      double multiplier = qty.toDouble();
      if (wQty != null && wQty != 1.0) {
        qtyStr = '$qty × $wQty $wUnit';
        multiplier = qty * wQty;
      }
      final lineTotal = price * multiplier;
      subTotal += lineTotal;
      return [
        it['name']?.toString().toUpperCase() ?? 'ITEM',
        qtyStr,
        'Rs. ${price.toStringAsFixed(2)}',
        'Rs. ${lineTotal.toStringAsFixed(2)}',
      ];
    }).toList();

    final discount = (order['discount'] as num? ?? 0.0).toDouble();
    final deliveryFee = (order['delivery_fee'] as num? ?? 0.0).toDouble();
    final tax = (order['tax'] as num? ?? 0.0).toDouble();
    final grandTotal = (order['total_price'] as num? ?? (subTotal - discount + deliveryFee + tax)).toDouble();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              _buildHeader(
                documentTitle: isMandi ? 'MANDI INVOICE' : 'SHOP RECEIPT',
                refId: orderId,
                logoImage: logo,
              ),

              // ── Bill To / Order Info grid ─────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL TO',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                          pw.SizedBox(height: 6),
                          _infoCell('Customer Name', profile['full_name']?.toString().toUpperCase() ?? 'CAMPUS MEMBER'),
                          pw.SizedBox(height: 6),
                          _infoCell('Email', profile['email']?.toString() ?? 'N/A'),
                          pw.SizedBox(height: 6),
                          _infoCell('Phone', profile['phone_no']?.toString() ?? 'N/A'),
                          if (order['delivery_address'] != null) ...[
                            pw.SizedBox(height: 6),
                            _infoCell('Delivery Address', order['delivery_address'].toString()),
                          ],
                        ],
                      ),
                    ),
                    pw.Container(width: 0.5, height: 80, color: PdfColor.fromInt(0xFFE5E7EB)),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ORDER INFO',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                            pw.SizedBox(height: 6),
                            _infoCell('Date & Time', date),
                            pw.SizedBox(height: 6),
                            _infoCell('Payment Method', order['payment_method']?.toString() ?? 'UPI / Wallet'),
                            pw.SizedBox(height: 6),
                            _infoCell('Delivery Type', order['delivery_type']?.toString() ?? 'Pickup'),
                            pw.SizedBox(height: 6),
                            _infoCell('Order Status', (order['status']?.toString() ?? 'Completed').toUpperCase()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ── Items table ────────────────────────────────────────────────
              pw.Text('ITEMS BREAKDOWN',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3730A3)),
                cellStyle: const pw.TextStyle(fontSize: 9),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6), width: 0.6)),
                ),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
                headers: ['ITEM DESCRIPTION', 'QTY / WEIGHT', 'UNIT RATE', 'LINE TOTAL'],
                data: itemRows,
              ),
              pw.SizedBox(height: 12),

              // ── Totals block ──────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F3FF),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFDDD6FE), width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        _totalRow('Sub-Total', 'Rs. ${subTotal.toStringAsFixed(2)}'),
                        if (discount > 0) _totalRow('Discount', '- Rs. ${discount.toStringAsFixed(2)}', isGreen: true),
                        if (deliveryFee > 0) _totalRow('Delivery Fee', 'Rs. ${deliveryFee.toStringAsFixed(2)}'),
                        if (tax > 0) _totalRow('Tax / GST', 'Rs. ${tax.toStringAsFixed(2)}'),
                        pw.Divider(color: PdfColor.fromInt(0xFFDDD6FE), thickness: 0.5),
                        _totalRow('GRAND TOTAL', 'Rs. ${grandTotal.toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'THANK YOU FOR YOUR PURCHASE! KEEP THIS RECEIPT FOR YOUR RECORDS.',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1),
                ),
              ),
              pw.SizedBox(height: 6),
              _buildFooter('Tax inclusive where applicable. This is a computer-generated invoice.'),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_$orderId.pdf');
    }
  }

  // ── Hostel / Mess Rent & Electricity Receipt ─────────────────────────────
  static Future<void> generateFiscalReceipt(
    dynamic col,
    String? studentName, {
    String? roomNumber,
    String? buildingName,
    String? phone,
    String? roomPlan,
    List<dynamic>? addOns,
    DateTime? cycleStart,
    DateTime? cycleEnd,
    int? daysBilled,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMM yyyy').format(DateTime.parse(col['created_at']));
    final receiptId = col['id'].toString().substring(0, 8).toUpperCase();
    final type = col['collection_type'] ?? 'PAYMENT';

    final baseRent = (col['base_rent'] as num? ?? (col['room_rent'] as num?) ?? 6500.0).toDouble();
    final electricityCharges = (col['electricity_charges'] as num? ?? 0.0).toDouble();
    final serviceFees = (col['service_fees'] as num? ?? 0.0).toDouble();
    final totalAmount = (col['amount'] as num? ?? (baseRent + electricityCharges + serviceFees)).toDouble();

    String cycleStr = DateFormat('MMMM yyyy').format(DateTime.parse(col['created_at']));
    if (cycleStart != null && cycleEnd != null) {
      cycleStr = '${DateFormat('dd MMM yyyy').format(cycleStart)} – ${DateFormat('dd MMM yyyy').format(cycleEnd)} (${daysBilled ?? cycleEnd.difference(cycleStart).inDays} days)';
    } else if (col['billing_start_date'] != null && col['billing_end_date'] != null) {
      final s = DateTime.tryParse(col['billing_start_date'].toString());
      final e = DateTime.tryParse(col['billing_end_date'].toString());
      if (s != null && e != null) {
        cycleStr = '${DateFormat('dd MMM yyyy').format(s)} – ${DateFormat('dd MMM yyyy').format(e)} (${col['days_billed'] ?? e.difference(s).inDays} days)';
      }
    }

    final List<List<String>> tableData = [
      ['Base Accommodation', roomPlan ?? 'Standard Plan', 'Rs. ${baseRent.toStringAsFixed(2)}', 'Rs. 0.00', 'Rs. ${baseRent.toStringAsFixed(2)}'],
    ];

    if (addOns != null && addOns.isNotEmpty) {
      for (var add in addOns) {
        tableData.add(['Add-on Service', add.toString().toUpperCase(), 'Included', '—', '—']);
      }
    }

    if (electricityCharges > 0) {
      tableData.add(['Electricity Surcharge', 'Delta Consumption', 'Rs. 0.00', 'Rs. ${electricityCharges.toStringAsFixed(2)}', 'Rs. ${electricityCharges.toStringAsFixed(2)}']);
    }

    if (serviceFees > 0) {
      tableData.add(['Service & Facility Dues', 'Maintenance', 'Rs. 0.00', 'Rs. ${serviceFees.toStringAsFixed(2)}', 'Rs. ${serviceFees.toStringAsFixed(2)}']);
    }

    final logo = await _getPdfLogo();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              _buildHeader(
                documentTitle: 'ACCOMMODATION RECEIPT',
                refId: receiptId,
                subtitle: 'Monthly Room Rent & Utilities Statement',
                logoImage: logo,
              ),

              // ── Resident / Billing info grid ───────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RESIDENT DETAILS',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                          pw.SizedBox(height: 6),
                          _infoCell('Name', studentName?.toUpperCase() ?? 'CAMPUS RESIDENT'),
                          if (phone != null && phone.isNotEmpty) ...[
                            pw.SizedBox(height: 6),
                            _infoCell('Contact', phone),
                          ],
                          if (roomNumber != null && roomNumber.isNotEmpty) ...[
                            pw.SizedBox(height: 6),
                            _infoCell('Allocated Room', 'Room $roomNumber${buildingName != null ? " ($buildingName)" : ""}'),
                          ],
                          pw.SizedBox(height: 6),
                          _infoCell('Tenant Status', 'Verified Resident'),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.5, height: 80, color: PdfColor.fromInt(0xFFE5E7EB)),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('BILLING CYCLE',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                            pw.SizedBox(height: 6),
                            _infoCell('Period', cycleStr),
                            pw.SizedBox(height: 6),
                            _infoCell('Date Issued', date),
                            pw.SizedBox(height: 6),
                            _infoCell('Payment Mode', col['payment_method']?.toString() ?? 'Digital Wallet / UPI'),
                            pw.SizedBox(height: 6),
                            _infoCell('Collection Type', type.toUpperCase()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ── Itemized breakdown ─────────────────────────────────────────
              pw.Text('ITEMIZED BILLING BREAKDOWN',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3730A3)),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6), width: 0.6)),
                ),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
                headers: ['BILLING COMPONENT', 'PLAN / NOTE', 'BASE PRICE', 'EXTRA CHARGES', 'NET PAYABLE'],
                data: tableData,
              ),
              pw.SizedBox(height: 12),

              // ── Totals ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F3FF),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFDDD6FE), width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        _totalRow('Base Rent', 'Rs. ${baseRent.toStringAsFixed(2)}'),
                        if (electricityCharges > 0) _totalRow('Electricity', 'Rs. ${electricityCharges.toStringAsFixed(2)}'),
                        if (serviceFees > 0) _totalRow('Service Fees', 'Rs. ${serviceFees.toStringAsFixed(2)}'),
                        pw.Divider(color: PdfColor.fromInt(0xFFDDD6FE), thickness: 0.5),
                        _totalRow('TOTAL PAYABLE', 'Rs. ${totalAmount.toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),

              if (col['remark'] != null) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFFBEB),
                    border: pw.Border(left: pw.BorderSide(color: PdfColor.fromInt(0xFFF59E0B), width: 3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OFFICIAL REMARKS', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFF59E0B))),
                      pw.SizedBox(height: 3),
                      pw.Text(col['remark'].toString(), style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF374151))),
                    ],
                  ),
                ),
              ],
              pw.Spacer(),
              _buildFooter('Electronically certified accommodation statement. GST: $_kGst'),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'RECEIPT_${type.toUpperCase()}_$receiptId.pdf');
    }
  }

  // ── Employee Payslip ───────────────────────────────────────────────────────
  static Future<void> generateSalaryReceipt(dynamic record, String? employeeName) async {
    final pdf = pw.Document();
    final logo = await _getPdfLogo();
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());
    final slipId = record['id'].toString().substring(0, 8).toUpperCase();
    final month = record['month'] ?? DateFormat('MMMM yyyy').format(DateTime.now());

    final baseSalary = (record['salary_amount'] as num? ?? 0.0).toDouble();
    final allowance = (record['allowances'] as num? ?? 0.0).toDouble();
    final advances = (record['advances_taken'] as num? ?? 0.0).toDouble();
    final unpaidLeaveDeduction = (record['deductions'] as num? ?? 0.0).toDouble();
    final totalDeductions = advances + unpaidLeaveDeduction;
    final leavesTaken = (record['leaves_taken'] as num? ?? 0).toInt();
    final daysPresent = (record['days_present'] as num? ?? 0).toInt();
    final netPaid = baseSalary + allowance - totalDeductions;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              _buildHeader(
                documentTitle: 'PAYSLIP STATEMENT',
                refId: slipId,
                subtitle: 'Official Monthly Salary & Remuneration',
                logoImage: logo,
              ),

              // ── Employee & pay period info ──────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EMPLOYEE',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                          pw.SizedBox(height: 6),
                          _infoCell('Name', employeeName?.toUpperCase() ?? 'STAFF MEMBER'),
                          pw.SizedBox(height: 6),
                          _infoCell('Department', record['department']?.toString().toUpperCase() ?? 'CAMPUS OPERATIONS'),
                          pw.SizedBox(height: 6),
                          _infoCell('Designation', record['designation']?.toString() ?? 'Staff'),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.5, height: 80, color: PdfColor.fromInt(0xFFE5E7EB)),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PAY PERIOD',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
                            pw.SizedBox(height: 6),
                            _infoCell('Month', month.toString()),
                            pw.SizedBox(height: 6),
                            _infoCell('Date Issued', date),
                            pw.SizedBox(height: 6),
                            _infoCell('Days Present', daysPresent > 0 ? '$daysPresent days' : '—'),
                            pw.SizedBox(height: 6),
                            _infoCell('Leaves Logged', '$leavesTaken days'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ── Pay breakdown table ─────────────────────────────────────────
              pw.Text('COMPENSATION STRUCTURE',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.5)),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Earnings side
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3730A3)),
                          child: pw.Text('EARNINGS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                        _payRow('Base Salary', 'Rs. ${baseSalary.toStringAsFixed(2)}'),
                        _payRow('Allowances', 'Rs. ${allowance.toStringAsFixed(2)}'),
                        pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB), thickness: 0.5),
                        _payRow('Gross Earnings', 'Rs. ${(baseSalary + allowance).toStringAsFixed(2)}', bold: true),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Deductions side
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDC2626)),
                          child: pw.Text('DEDUCTIONS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                        _payRow('Advance Recovery', 'Rs. ${advances.toStringAsFixed(2)}'),
                        _payRow('Unpaid Leave Penalty', 'Rs. ${unpaidLeaveDeduction.toStringAsFixed(2)}'),
                        pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB), thickness: 0.5),
                        _payRow('Total Deductions', 'Rs. ${totalDeductions.toStringAsFixed(2)}', bold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // ── Net pay banner ──────────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [PdfColor.fromInt(0xFF3730A3), PdfColor.fromInt(0xFF6D28D9)],
                  ),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET AMOUNT DISBURSED',
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                    pw.Text('Rs. ${netPaid.toStringAsFixed(2)}',
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'AUTHORIZED DIGITAL PAYSLIP — H House PERSONNEL MANAGEMENT',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF6366F1), letterSpacing: 1.2),
                ),
              ),
              pw.SizedBox(height: 6),
              _buildFooter('Confidential payslip. Generated electronically. $_kGst'),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'PAYSLIP_$slipId.pdf');
    }
  }

  // ─────── Shared row builders ─────────────────────────────────────────────

  static pw.Widget _totalRow(String label, String value, {bool isTotal = false, bool isGreen = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(
            fontSize: isTotal ? 10 : 8.5,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isTotal ? PdfColor.fromInt(0xFF3730A3) : PdfColor.fromInt(0xFF374151),
          )),
          pw.Text(value, style: pw.TextStyle(
            fontSize: isTotal ? 12 : 9,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isGreen ? PdfColor.fromInt(0xFF059669) : (isTotal ? PdfColor.fromInt(0xFF3730A3) : PdfColor.fromInt(0xFF111827)),
          )),
        ],
      ),
    );
  }

  static pw.Widget _payRow(String label, String value, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF3F4F6), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColor.fromInt(0xFF374151),
          )),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColor.fromInt(0xFF111827),
          )),
        ],
      ),
    );
  }
}
