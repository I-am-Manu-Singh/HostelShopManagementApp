import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'organization_settings_service.dart';

enum ReceiptTemplateStyle {
  retailStandard,   // Standard detailed itemized tax invoice
  compactRoll,      // Super minimal font for quick counter checkouts
  gstDetailed,      // Full B2B / GST compliant with HSN, SGST/CGST columns
  kitchenKot,       // Kitchen Order Ticket for mess/canteen orders without prices
}

enum PrinterConnectionType { bluetooth, usb, network, pdfOnly }

class PosReceiptItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? hsn;
  final double taxPercent;

  PosReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.hsn,
    this.taxPercent = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'hsn': hsn,
    'taxPercent': taxPercent,
  };
}

class PosReceiptData {
  final String storeName;
  final String storeAddress;
  final String? storeGstin;
  final String? storePhone;
  final String invoiceNumber;
  final DateTime dateTime;
  final String? cashierName;
  final String? customerName;
  final String? customerPhone;
  final List<PosReceiptItem> items;
  final double subtotal;
  final double discount;
  final double cgst;
  final double sgst;
  final double total;
  final String paymentMode;
  final double? tenderedAmount;
  final double? changeAmount;
  final String? footerNote;
  final ReceiptTemplateStyle templateStyle;

  PosReceiptData({
    required this.storeName,
    required this.storeAddress,
    this.storeGstin,
    this.storePhone,
    required this.invoiceNumber,
    required this.dateTime,
    this.cashierName,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    required this.total,
    required this.paymentMode,
    this.tenderedAmount,
    this.changeAmount,
    this.footerNote,
    this.templateStyle = ReceiptTemplateStyle.retailStandard,
  });
}

class PosHardwareService {
  static final PosHardwareService _instance = PosHardwareService._internal();
  factory PosHardwareService() => _instance;
  PosHardwareService._internal();

  static const String _prefPaperWidthKey = 'pos_printer_paper_width'; // 58 or 80
  static const String _prefAutoPrintKey = 'pos_auto_print_enabled';
  static const String _prefTemplateStyleKey = 'pos_receipt_template_style';
  static const String _prefStoreNameKey = 'pos_store_name';
  static const String _prefStoreAddressKey = 'pos_store_address';
  static const String _prefStoreGstinKey = 'pos_store_gstin';
  static const String _prefStorePhoneKey = 'pos_store_phone';
  static const String _prefFooterNoteKey = 'pos_receipt_footer_note';
  static const String _prefStoreFooterKey = 'pos_store_footer_note'; // Fixed missing constant key
  static const String _prefPrintBarcodeKey = 'pos_print_barcode_enabled';
  static const String _prefCashDrawerPulseKey = 'pos_cash_drawer_pulse_enabled';
  static const String _prefConnectedMacKey = 'pos_connected_printer_mac';
  static const String _prefConnectedNameKey = 'pos_connected_printer_name';
  static const String _prefMerchantUpiVpaKey = 'pos_merchant_upi_vpa';
  static const String _prefMerchantNameKey = 'pos_merchant_name';

  int paperWidthMm = 58; 
  bool autoPrint = true;
  ReceiptTemplateStyle templateStyle = ReceiptTemplateStyle.retailStandard;
  String storeName = "Hostel SuperMart & POS";
  String storeAddress = "Campus Block B, Ground Floor";
  String storeGstin = "07AAAAA0000A1Z5";
  String storePhone = "+91 7976287989";
  String footerNote = "Thank you for shopping with us!\nVisit again.";
  bool printBarcode = true;
  bool cashDrawerPulse = true;
  String merchantUpiVpa = "campusshop@upi";
  String merchantName = "Hostel SuperMart";

  String? connectedMacAddress;
  String? connectedDeviceName;
  bool _isConnectingOrReconnecting = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    paperWidthMm = prefs.getInt(_prefPaperWidthKey) ?? 58;
    autoPrint = prefs.getBool(_prefAutoPrintKey) ?? true;
    final styleIndex = prefs.getInt(_prefTemplateStyleKey) ?? 0;
    templateStyle = ReceiptTemplateStyle.values[styleIndex.clamp(0, ReceiptTemplateStyle.values.length - 1)];

    // Fetch dynamic store/org info from Supabase
    final org = OrganizationSettingsService();
    try {
      await org.fetchSettings();
    } catch (_) {}

    storeName = prefs.getString(_prefStoreNameKey) ?? org.merchantName;
    storeAddress = prefs.getString(_prefStoreAddressKey) ?? org.companyAddress;
    storeGstin = prefs.getString(_prefStoreGstinKey) ?? org.storeGstin;
    storePhone = prefs.getString(_prefStorePhoneKey) ?? org.companyPhone;
    footerNote = prefs.getString(_prefFooterNoteKey) ?? prefs.getString(_prefStoreFooterKey) ?? org.receiptFooterNote;
    printBarcode = prefs.getBool(_prefPrintBarcodeKey) ?? true;
    cashDrawerPulse = prefs.getBool(_prefCashDrawerPulseKey) ?? true;
    merchantUpiVpa = prefs.getString(_prefMerchantUpiVpaKey) ?? org.merchantUpiVpa;
    merchantName = prefs.getString(_prefMerchantNameKey) ?? storeName;

    connectedMacAddress = prefs.getString(_prefConnectedMacKey);
    connectedDeviceName = prefs.getString(_prefConnectedNameKey);

    if (connectedMacAddress != null && connectedMacAddress!.isNotEmpty) {
      _verifyAndAutoReconnect();
    }
  }

  Future<void> _verifyAndAutoReconnect() async {
    if (_isConnectingOrReconnecting || connectedMacAddress == null) return;
    _isConnectingOrReconnecting = true;

    try {
      final bool isBtEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBtEnabled) {
        _isConnectingOrReconnecting = false;
        return;
      }

      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        final bool reconnected = await PrintBluetoothThermal.connect(macPrinterAddress: connectedMacAddress!);
        if (!reconnected) {
          connectedMacAddress = null;
          connectedDeviceName = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_prefConnectedMacKey);
          await prefs.remove(_prefConnectedNameKey);
        }
      }
    } catch (_) {
    } finally {
      _isConnectingOrReconnecting = false;
    }
  }

  Future<void> saveSettings({
    required int paperWidth,
    required bool autoPrintReceipts,
    required ReceiptTemplateStyle style,
    required String name,
    required String address,
    required String gstin,
    required String phone,
    required String footer,
    required bool printBarcodeOnBill,
    required bool kickDrawer,
    String? merchantVpa,
    String? merchName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    paperWidthMm = paperWidth;
    autoPrint = autoPrintReceipts;
    templateStyle = style;
    storeName = name;
    storeAddress = address;
    storeGstin = gstin;
    storePhone = phone;
    footerNote = footer;
    printBarcode = printBarcodeOnBill;
    cashDrawerPulse = kickDrawer;
    if (merchantVpa != null && merchantVpa.isNotEmpty) {
      merchantUpiVpa = merchantVpa;
      await prefs.setString(_prefMerchantUpiVpaKey, merchantUpiVpa);
    }
    if (merchName != null && merchName.isNotEmpty) {
      merchantName = merchName;
      await prefs.setString(_prefMerchantNameKey, merchantName);
    }

    await prefs.setInt(_prefPaperWidthKey, paperWidthMm);
    await prefs.setBool(_prefAutoPrintKey, autoPrint);
    await prefs.setInt(_prefTemplateStyleKey, templateStyle.index);
    await prefs.setString(_prefStoreNameKey, storeName);
    await prefs.setString(_prefStoreAddressKey, storeAddress);
    await prefs.setString(_prefStoreGstinKey, storeGstin);
    await prefs.setString(_prefStorePhoneKey, storePhone);
    await prefs.setString(_prefFooterNoteKey, footerNote);
    await prefs.setString(_prefStoreFooterKey, footerNote);
    await prefs.setBool(_prefPrintBarcodeKey, printBarcode);
    await prefs.setBool(_prefCashDrawerPulseKey, cashDrawerPulse);
  }

  Future<List<int>> generateEscPosBytes(PosReceiptData receipt) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      receipt.storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (receipt.storeAddress.isNotEmpty) {
      bytes += generator.text(
        receipt.storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (receipt.storePhone != null && receipt.storePhone!.isNotEmpty) {
      bytes += generator.text(
        "Tel: ${receipt.storePhone}",
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (receipt.storeGstin != null && receipt.storeGstin!.isNotEmpty) {
      bytes += generator.text(
        "GSTIN: ${receipt.storeGstin}",
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.hr(ch: '=');
    final title = receipt.templateStyle == ReceiptTemplateStyle.kitchenKot
        ? "KITCHEN ORDER TICKET (KOT)"
        : (receipt.templateStyle == ReceiptTemplateStyle.gstDetailed ? "TAX INVOICE (GST COMPLIANT)" : "RETAIL SALE RECEIPT");
    bytes += generator.text(
      title,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text("Inv: ${receipt.invoiceNumber}");
    bytes += generator.text("Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(receipt.dateTime)}");
    if (receipt.cashierName != null) {
      bytes += generator.text("Cashier: ${receipt.cashierName}");
    }
    if (receipt.customerName != null) {
      bytes += generator.text("Customer: ${receipt.customerName}");
    }
    bytes += generator.hr();

    if (receipt.templateStyle == ReceiptTemplateStyle.kitchenKot) {
      for (var item in receipt.items) {
        bytes += generator.text("${item.quantity}x ${item.name}", styles: const PosStyles(bold: true, height: PosTextSize.size2));
      }
    } else {
      if (paperWidthMm == 80) {
        bytes += generator.row([
          PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
          PosColumn(text: 'Rate', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
          PosColumn(text: 'Total', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      } else {
        bytes += generator.row([
          PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center, bold: true)),
          PosColumn(text: 'Amt', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }
      bytes += generator.hr();

      for (var item in receipt.items) {
        if (paperWidthMm == 80) {
          bytes += generator.row([
            PosColumn(text: item.name, width: 6),
            PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
            PosColumn(text: item.unitPrice.toStringAsFixed(1), width: 2, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: item.totalPrice.toStringAsFixed(1), width: 2, styles: const PosStyles(align: PosAlign.right)),
          ]);
        } else {
          bytes += generator.row([
            PosColumn(text: item.name, width: 6),
            PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
            PosColumn(text: item.totalPrice.toStringAsFixed(1), width: 4, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }
      }
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Subtotal:', width: 6),
        PosColumn(text: "Rs ${receipt.subtotal.toStringAsFixed(2)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (receipt.discount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Discount:', width: 6),
          PosColumn(text: "-Rs ${receipt.discount.toStringAsFixed(2)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      if (receipt.cgst > 0 || receipt.sgst > 0) {
        bytes += generator.row([
          PosColumn(text: 'CGST:', width: 6),
          PosColumn(text: "Rs ${receipt.cgst.toStringAsFixed(2)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
        bytes += generator.row([
          PosColumn(text: 'SGST:', width: 6),
          PosColumn(text: "Rs ${receipt.sgst.toStringAsFixed(2)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr(ch: '=');
      bytes += generator.row([
        PosColumn(
          text: 'GRAND TOTAL:',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: "Rs ${receipt.total.toStringAsFixed(2)}",
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
        ),
      ]);
      bytes += generator.hr(ch: '=');

      bytes += generator.text("Payment Mode: ${receipt.paymentMode.toUpperCase()}");
      if (receipt.tenderedAmount != null && receipt.tenderedAmount! > 0) {
        bytes += generator.text("Tendered: Rs ${receipt.tenderedAmount!.toStringAsFixed(2)}");
        if (receipt.changeAmount != null) {
          bytes += generator.text("Change Return: Rs ${receipt.changeAmount!.toStringAsFixed(2)}");
        }
      }
    }

    if (printBarcode) {
      bytes += generator.feed(1);
      bytes += generator.qrcode(receipt.invoiceNumber, size: QRSize.size4);
      bytes += generator.feed(1);
    }

    bytes += generator.text(
      receipt.footerNote ?? footerNote,
      styles: const PosStyles(align: PosAlign.center),
    );

    if (cashDrawerPulse) {
      bytes += [0x1B, 0x70, 0x00, 0x19, 0xFA];
    }

    bytes += generator.cut();
    return bytes;
  }

  Future<bool> printThermalReceipt(PosReceiptData data) async {
    try {
      if (connectedMacAddress != null) {
        await _verifyAndAutoReconnect();
        final bool btConnected = await isBluetoothConnected();
        if (btConnected) {
          final bytes = await generateEscPosBytes(data);
          final bool sent = await printBytesDirectBluetooth(bytes);
          if (sent) return true;
        }
      }

      final pageFormat = paperWidthMm == 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
      final doc = await buildReceiptPdfDocument(data);
      return await Printing.layoutPdf(
        format: pageFormat,
        onLayout: (format) async => doc.save(),
        name: 'POS_${data.invoiceNumber}',
      );
    } catch (_) {
      return false;
    }
  }

  Future<pw.Document> buildReceiptPdfDocument(PosReceiptData data) async {
    final doc = pw.Document();
    final pageFormat = paperWidthMm == 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final isKot = data.templateStyle == ReceiptTemplateStyle.kitchenKot;
    final isGst = data.templateStyle == ReceiptTemplateStyle.gstDetailed;

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(6),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 32,
                  height: 32,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Text(data.storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.black)),
              if (data.storeAddress.isNotEmpty)
                pw.Text(data.storeAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black), textAlign: pw.TextAlign.center),
              if (data.storePhone != null && data.storePhone!.isNotEmpty)
                pw.Text("Tel: ${data.storePhone}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
              if (data.storeGstin != null && data.storeGstin!.isNotEmpty)
                pw.Text("GSTIN: ${data.storeGstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.Divider(thickness: 1, color: PdfColors.black),

              pw.Text(
                isKot ? "KITCHEN ORDER TICKET (KOT)" : (isGst ? "TAX INVOICE (GST COMPLIANT)" : "RETAIL SALES RECEIPT"),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Inv: ${data.invoiceNumber}", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(DateFormat('dd/MM/yy HH:mm').format(data.dateTime), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (data.customerName != null)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text("Customer: ${data.customerName}", style: const pw.TextStyle(fontSize: 8)),
                ),
              pw.Divider(thickness: 0.5),

              pw.Row(
                children: [
                  pw.Expanded(flex: isGst ? 4 : 5, child: pw.Text("Item", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  if (isGst) pw.Expanded(flex: 2, child: pw.Text("HSN", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  if (!isKot) pw.Expanded(flex: 3, child: pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              ...data.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: isGst ? 4 : 5, child: pw.Text(item.name, style: pw.TextStyle(fontSize: isKot ? 9 : 7.5, fontWeight: isKot ? pw.FontWeight.bold : pw.FontWeight.normal))),
                    if (isGst) pw.Expanded(flex: 2, child: pw.Text(item.hsn ?? '—', style: const pw.TextStyle(fontSize: 7))),
                    pw.Expanded(flex: 2, child: pw.Text("${item.quantity}", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: isKot ? 9 : 7.5, fontWeight: pw.FontWeight.bold))),
                    if (!isKot) pw.Expanded(flex: 3, child: pw.Text("Rs ${item.totalPrice.toStringAsFixed(1)}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                  ],
                ),
              )),

              if (!isKot) ...[
                pw.Divider(thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Subtotal:", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Rs ${data.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                if (data.discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Discount:", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("-Rs ${data.discount.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                if (data.cgst > 0 || data.sgst > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("CGST:", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Rs ${data.cgst.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("SGST:", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Rs ${data.sgst.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("NET TOTAL:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Rs ${data.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text("Mode: ${data.paymentMode.toUpperCase()}", style: const pw.TextStyle(fontSize: 8)),
                ),
                if (data.tenderedAmount != null && data.tenderedAmount! > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Cash Tendered:", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Rs ${data.tenderedAmount!.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Change Returned:", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Rs ${data.changeAmount?.toStringAsFixed(2) ?? '0.00'}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ],

              if (printBarcode) ...[
                pw.SizedBox(height: 6),
                pw.BarcodeWidget(
                  data: data.invoiceNumber,
                  barcode: pw.Barcode.code128(),
                  width: 120,
                  height: 25,
                  drawText: false,
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Text(data.footerNote ?? footerNote, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );
    return doc;
  }

  Future<void> shareReceiptPdf(PosReceiptData data) async {
    final doc = await buildReceiptPdfDocument(data);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'RECEIPT_${data.invoiceNumber}.pdf',
    );
  }

  Future<void> shareReceiptImage(PosReceiptData data) async {
    final doc = await buildReceiptPdfDocument(data);
    final bytes = await doc.save();
    await for (final page in Printing.raster(bytes, dpi: 200)) {
      final pngBytes = await page.toPng();
      final xFile = XFile.fromData(
        pngBytes,
        name: 'RECEIPT_${data.invoiceNumber}.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        [xFile],
        text: 'Thermal Receipt #${data.invoiceNumber} - Total Rs ${data.total.toStringAsFixed(2)}',
      );
      break;
    }
  }

  Future<bool> requestBluetoothPermissions() async {
    try {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Return true if connect & scan or bluetooth is granted
      final bool connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final bool scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      return connectOk && scanOk;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime Android/iOS Bluetooth & Location permissions and checks if Bluetooth adapter is powered on
  Future<Map<String, dynamic>> checkAndRequestBluetoothState() async {
    try {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final bool connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final bool scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? true;

      if (!connectOk || !scanOk) {
        return {
          'granted': false,
          'bluetoothOn': false,
          'message': 'Bluetooth Scan/Connect permissions were not granted. Please enable them in App Settings.',
        };
      }

      final bool isBtOn = await PrintBluetoothThermal.bluetoothEnabled;
      return {
        'granted': true,
        'bluetoothOn': isBtOn,
        'message': isBtOn ? 'Bluetooth is active' : 'Bluetooth adapter is turned OFF on this device.',
      };
    } catch (e) {
      return {
        'granted': false,
        'bluetoothOn': false,
        'message': 'Permission check error: $e',
      };
    }
  }

  Future<List<BluetoothInfo>> getPairedBluetoothPrinters() async {
    try {
      final check = await checkAndRequestBluetoothState();
      if (!check['granted'] || !check['bluetoothOn']) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  Future<bool> connectBluetoothPrinter(String macAddress, String name) async {
    try {
      await PrintBluetoothThermal.disconnect;
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (result) {
        connectedMacAddress = macAddress;
        connectedDeviceName = name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefConnectedMacKey, macAddress);
        await prefs.setString(_prefConnectedNameKey, name);
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnectBluetoothPrinter() async {
    try {
      await PrintBluetoothThermal.disconnect;
      connectedMacAddress = null;
      connectedDeviceName = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefConnectedMacKey);
      await prefs.remove(_prefConnectedNameKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBluetoothConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printBytesDirectBluetooth(List<int> bytes) async {
    try {
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) return false;
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Print Day-End Financial Z-Report / Shift Closeout to thermal printer or system spooler
  Future<bool> printZReport({
    required String timeframe,
    required double totalSales,
    required int orderCount,
    required double avgOrderValue,
    required double taxCollected,
    required double totalPurchases,
    required double grossProfit,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final paper = paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(paper, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.text(
        storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      if (storeAddress.isNotEmpty) {
        bytes += generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.hr(ch: '=');
      bytes += generator.text(
        "DAY-END Z-REPORT (FINANCIAL)",
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
      );
      bytes += generator.text("Timeframe: ${timeframe.toUpperCase()}");
      bytes += generator.text("Generated: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}");
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: "Total Revenue:", width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: "Rs ${totalSales.toStringAsFixed(2)}", width: 5, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: "Order Count:", width: 7),
        PosColumn(text: "$orderCount", width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: "Avg Order Value:", width: 7),
        PosColumn(text: "Rs ${avgOrderValue.toStringAsFixed(2)}", width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: "GST Collected:", width: 7),
        PosColumn(text: "Rs ${taxCollected.toStringAsFixed(2)}", width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: "Stock Procured:", width: 7),
        PosColumn(text: "Rs ${totalPurchases.toStringAsFixed(2)}", width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: "Gross Profit:", width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: "Rs ${grossProfit.toStringAsFixed(2)}", width: 5, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.hr();

      if (topProducts.isNotEmpty) {
        bytes += generator.text("TOP FAST-MOVING ITEMS", styles: const PosStyles(bold: true));
        for (var p in topProducts.take(5)) {
          bytes += generator.text("${p['name']} (Qty: ${p['quantity']}) - Rs ${(p['revenue'] as num).toStringAsFixed(1)}");
        }
        bytes += generator.hr();
      }

      bytes += generator.text("Shift Cashier Sign: ____________", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      if (connectedMacAddress != null) {
        await _verifyAndAutoReconnect();
        if (await isBluetoothConnected()) {
          final sent = await printBytesDirectBluetooth(bytes);
          if (sent) return true;
        }
      }

      // Fallback to PDF spooler
      final doc = pw.Document();
      final pageFormat = paperWidthMm == 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(6),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.Divider(thickness: 1),
              pw.Text("DAY-END FINANCIAL Z-REPORT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text("Generated: ${DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 0.5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Total Sales:", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Rs ${totalSales.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Total Orders:", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("$orderCount", style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Tax Collected:", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Rs ${taxCollected.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Gross Profit:", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Rs ${grossProfit.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Divider(thickness: 0.5),
              pw.Text("Cashier Sign: ____________", style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      );

      return await Printing.layoutPdf(
        onLayout: (fmt) async => doc.save(),
        name: 'Z_REPORT_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (_) {
      return false;
    }
  }

  /// Print standard 50x30mm or 58mm roll Product Barcode & Price Tag Sticker
  /// Sends direct ESC/POS command to connected Bluetooth/USB thermal printer or falls back to PDF printing spooler.
  Future<bool> printProductBarcodeLabel({
    required String name,
    required String barcode,
    required double price,
    String? brand,
    String? hsn,
    int copies = 1,
  }) async {
    try {
      final cleanBarcode = barcode.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').trim();
      final displayName = name.length > 28 ? '${name.substring(0, 25)}...' : name;

      // 1. Direct ESC/POS printing if Bluetooth thermal printer is paired & connected
      if (connectedMacAddress != null) {
        await _verifyAndAutoReconnect();
        if (await isBluetoothConnected()) {
          final profile = await CapabilityProfile.load();
          final paper = paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
          final generator = Generator(paper, profile);
          List<int> bytes = [];

          for (int c = 0; c < copies; c++) {
            bytes += generator.reset();
            // Store / Brand Header
            bytes += generator.text(
              brand != null && brand.isNotEmpty ? brand.toUpperCase() : storeName,
              styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
            );
            // Product Title
            bytes += generator.text(
              displayName,
              styles: const PosStyles(align: PosAlign.center, bold: true),
            );
            // Price Tag
            bytes += generator.text(
              "MRP: Rs ${price.toStringAsFixed(2)}",
              styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
            );
            if (hsn != null && hsn.isNotEmpty) {
              bytes += generator.text("HSN: $hsn  (Incl. of all taxes)", styles: const PosStyles(align: PosAlign.center));
            } else {
              bytes += generator.text("(Inclusive of all taxes)", styles: const PosStyles(align: PosAlign.center));
            }
            bytes += generator.feed(1);

            // Barcode printing: QR code fallback or 1D barcode
            if (cleanBarcode.length == 13 && RegExp(r'^[0-9]{13}$').hasMatch(cleanBarcode)) {
              // Standard EAN-13
              final List<int> eanBytes = cleanBarcode.split('').map((e) => int.parse(e)).toList();
              bytes += generator.barcode(Barcode.ean13(eanBytes));
            } else {
              // Code128 or QR
              bytes += generator.qrcode(cleanBarcode, size: QRSize.size4);
            }

            bytes += generator.text(cleanBarcode, styles: const PosStyles(align: PosAlign.center, bold: true));
            bytes += generator.feed(2);
            bytes += generator.cut();
          }

          final sent = await printBytesDirectBluetooth(bytes);
          if (sent) return true;
        }
      }

      // 2. Fallback to System PDF Spooler (Roll/Sticker 50x30mm or 58mm format)
      final doc = pw.Document();
      // Standard retail sticker format: 50mm width x 35mm height
      const labelFormat = PdfPageFormat(
        50 * PdfPageFormat.mm,
        35 * PdfPageFormat.mm,
        marginAll: 2 * PdfPageFormat.mm,
      );

      for (int c = 0; c < copies; c++) {
        doc.addPage(
          pw.Page(
            pageFormat: labelFormat,
            build: (pw.Context ctx) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    brand != null && brand.isNotEmpty ? brand.toUpperCase() : storeName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
                    maxLines: 1,
                  ),
                  pw.Text(
                    displayName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                  ),
                  pw.SizedBox(height: 2),
                  pw.BarcodeWidget(
                    data: cleanBarcode,
                    barcode: cleanBarcode.length == 13 && RegExp(r'^[0-9]{13}$').hasMatch(cleanBarcode)
                        ? pw.Barcode.ean13()
                        : pw.Barcode.code128(),
                    width: 100,
                    height: 24,
                    drawText: false,
                  ),
                  pw.Text(cleanBarcode, style: const pw.TextStyle(fontSize: 6.5)),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "MRP: Rs ${price.toStringAsFixed(2)}",
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      if (hsn != null && hsn.isNotEmpty)
                        pw.Text("  HSN: $hsn", style: const pw.TextStyle(fontSize: 6)),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      return await Printing.layoutPdf(
        onLayout: (fmt) async => doc.save(),
        name: 'LABEL_${cleanBarcode}_x$copies',
      );
    } catch (_) {
      return false;
    }
  }

  /// Batch Barcode Label Printing on Sheet (e.g. A4 3x8 = 24 labels/sheet, or 4x10) or Thermal Roll
  /// Packs multiple items in tight sequence to eliminate paper wastage and maximize page utilization
  Future<bool> printBatchBarcodeSheet({
    required List<Map<String, dynamic>> itemsWithCounts, // [{'name': ..., 'barcode': ..., 'price': ..., 'brand': ..., 'hsn': ..., 'count': ...}]
    bool isA4Sheet = true,
  }) async {
    try {
      final doc = pw.Document();

      // Expand items into flat sequence of individual labels
      final List<Map<String, dynamic>> flatLabels = [];
      for (final item in itemsWithCounts) {
        final int count = (item['count'] as num?)?.toInt() ?? 1;
        for (int c = 0; c < count; c++) {
          flatLabels.add(item);
        }
      }

      if (flatLabels.isEmpty) return false;

      if (!isA4Sheet && connectedMacAddress != null) {
        // If Bluetooth thermal printer connected, print in roll sequence
        await _verifyAndAutoReconnect();
        if (await isBluetoothConnected()) {
          for (final item in flatLabels) {
            await printProductBarcodeLabel(
              name: item['name'] ?? '',
              barcode: item['barcode'] ?? '',
              price: (item['price'] as num?)?.toDouble() ?? 0.0,
              brand: item['brand'],
              hsn: item['hsn'],
              copies: 1,
            );
          }
          return true;
        }
      }

      // Multi-column Sheet Spooler (Default: A4 sheet with 3 columns x 8 rows = 24 labels per sheet)
      const int colsPerPage = 3;
      const int rowsPerPage = 8;
      const int labelsPerPage = colsPerPage * rowsPerPage;

      final int totalPages = (flatLabels.length / labelsPerPage).ceil();

      for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
        final startIdx = pageIdx * labelsPerPage;
        final endIdx = (startIdx + labelsPerPage > flatLabels.length) ? flatLabels.length : startIdx + labelsPerPage;
        final pageLabels = flatLabels.sublist(startIdx, endIdx);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 10 * PdfPageFormat.mm, vertical: 12 * PdfPageFormat.mm),
            build: (pw.Context ctx) {
              return pw.GridView(
                crossAxisCount: colsPerPage,
                crossAxisSpacing: 6 * PdfPageFormat.mm,
                mainAxisSpacing: 5 * PdfPageFormat.mm,
                childAspectRatio: 1.8,
                children: pageLabels.map((lbl) {
                  final String name = lbl['name']?.toString() ?? 'Product';
                  final String barcode = (lbl['barcode']?.toString() ?? '').replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').trim();
                  final double price = (lbl['price'] as num?)?.toDouble() ?? 0.0;
                  final String? hsn = lbl['hsn']?.toString();
                  final String? brand = lbl['brand']?.toString();
                  final String displayName = name.length > 24 ? '${name.substring(0, 22)}...' : name;

                  return pw.Container(
                    padding: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          brand != null && brand.isNotEmpty ? brand.toUpperCase() : storeName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5),
                          maxLines: 1,
                        ),
                        pw.Text(
                          displayName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
                          maxLines: 1,
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2),
                        pw.BarcodeWidget(
                          data: barcode.isNotEmpty ? barcode : '1000000000000',
                          barcode: barcode.length == 13 && RegExp(r'^[0-9]{13}$').hasMatch(barcode)
                              ? pw.Barcode.ean13()
                              : pw.Barcode.code128(),
                          width: 130,
                          height: 22,
                          drawText: false,
                        ),
                        pw.Text(barcode, style: const pw.TextStyle(fontSize: 6.5)),
                        pw.SizedBox(height: 1),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('MRP: Rs ${price.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            if (hsn != null && hsn.isNotEmpty) pw.Text('HSN: $hsn', style: const pw.TextStyle(fontSize: 6)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      return await Printing.layoutPdf(
        onLayout: (fmt) async => doc.save(),
        name: 'BATCH_BARCODES_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      );
    } catch (_) {
      return false;
    }
  }
}