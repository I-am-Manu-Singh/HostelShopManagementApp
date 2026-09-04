import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';

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
  static const String _prefPrintBarcodeKey = 'pos_print_barcode_enabled';
  static const String _prefCashDrawerPulseKey = 'pos_cash_drawer_pulse_enabled';

  int paperWidthMm = 58; // 58mm or 80mm
  bool autoPrint = true;
  ReceiptTemplateStyle templateStyle = ReceiptTemplateStyle.retailStandard;
  String storeName = "Hostel SuperMart & POS";
  String storeAddress = "Campus Block B, Ground Floor";
  String storeGstin = "07AAAAA0000A1Z5";
  String storePhone = "+91 9876543210";
  String footerNote = "Thank you for shopping with us!\nVisit again.";
  bool printBarcode = true;
  bool cashDrawerPulse = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    paperWidthMm = prefs.getInt(_prefPaperWidthKey) ?? 58;
    autoPrint = prefs.getBool(_prefAutoPrintKey) ?? true;
    final styleIndex = prefs.getInt(_prefTemplateStyleKey) ?? 0;
    templateStyle = ReceiptTemplateStyle.values[styleIndex.clamp(0, ReceiptTemplateStyle.values.length - 1)];
    storeName = prefs.getString(_prefStoreNameKey) ?? "Hostel SuperMart & POS";
    storeAddress = prefs.getString(_prefStoreAddressKey) ?? "Campus Block B, Ground Floor";
    storeGstin = prefs.getString(_prefStoreGstinKey) ?? "07AAAAA0000A1Z5";
    storePhone = prefs.getString(_prefStorePhoneKey) ?? "+91 9876543210";
    footerNote = prefs.getString(_prefFooterNoteKey) ?? "Thank you for shopping with us!\nVisit again.";
    printBarcode = prefs.getBool(_prefPrintBarcodeKey) ?? true;
    cashDrawerPulse = prefs.getBool(_prefCashDrawerPulseKey) ?? true;
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

    await prefs.setInt(_prefPaperWidthKey, paperWidthMm);
    await prefs.setBool(_prefAutoPrintKey, autoPrint);
    await prefs.setInt(_prefTemplateStyleKey, templateStyle.index);
    await prefs.setString(_prefStoreNameKey, storeName);
    await prefs.setString(_prefStoreAddressKey, storeAddress);
    await prefs.setString(_prefStoreGstinKey, storeGstin);
    await prefs.setString(_prefStorePhoneKey, storePhone);
    await prefs.setString(_prefFooterNoteKey, footerNote);
    await prefs.setBool(_prefPrintBarcodeKey, printBarcode);
    await prefs.setBool(_prefCashDrawerPulseKey, cashDrawerPulse);
  }

  /// Generate raw ESC/POS bytes for 58mm or 80mm thermal printers
  Future<List<int>> generateEscPosBytes(PosReceiptData receipt) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    List<int> bytes = [];

    // Header
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

    // Items
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

      // Summary
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

  /// High-reliability Printing supporting Direct Bluetooth ESC/POS hardware or OS Print Spooler / PDF roll layout (58mm / 80mm)
  Future<bool> printThermalReceipt(PosReceiptData data) async {
    try {
      // 1. If direct Bluetooth printer is connected, send ESC/POS raw bytes directly
      final bool btConnected = await isBluetoothConnected();
      if (btConnected) {
        final bytes = await generateEscPosBytes(data);
        final bool sent = await printBytesDirectBluetooth(bytes);
        if (sent) return true;
      }

      // 2. Fallback / default OS print spooler via PDF roll layout
      final doc = await buildReceiptPdfDocument(data);

      return await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'POS_${data.invoiceNumber}',
      );
    } catch (e) {
      return false;
    }
  }

  /// Build standard printable PDF document for receipt
  Future<pw.Document> buildReceiptPdfDocument(PosReceiptData data) async {
    final doc = pw.Document();
    final pageFormat = paperWidthMm == 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final isKot = data.templateStyle == ReceiptTemplateStyle.kitchenKot;
    final isGst = data.templateStyle == ReceiptTemplateStyle.gstDetailed;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(6),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(data.storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              if (data.storeAddress.isNotEmpty)
                pw.Text(data.storeAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              if (data.storePhone != null && data.storePhone!.isNotEmpty)
                pw.Text("Tel: ${data.storePhone}", style: const pw.TextStyle(fontSize: 8)),
              if (data.storeGstin != null && data.storeGstin!.isNotEmpty)
                pw.Text("GSTIN: ${data.storeGstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 1),
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

              // Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: isGst ? 4 : 5, child: pw.Text("Item", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  if (isGst) pw.Expanded(flex: 2, child: pw.Text("HSN", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  if (!isKot) pw.Expanded(flex: 3, child: pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items
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

  /// Share thermal receipt as PDF file via WhatsApp, Gmail or any app
  Future<void> shareReceiptPdf(PosReceiptData data) async {
    final doc = await buildReceiptPdfDocument(data);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'RECEIPT_${data.invoiceNumber}.pdf',
    );
  }

  /// Share thermal receipt as PNG rasterized image (ideal for WhatsApp direct messaging)
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
      break; // share first receipt page
    }
  }

  // ── Bluetooth Thermal Direct ESC/POS Wireless Hardware Layer ───────────────
  String? connectedMacAddress;
  String? connectedDeviceName;

  /// Get list of paired Bluetooth devices
  Future<List<BluetoothInfo>> getPairedBluetoothPrinters() async {
    try {
      final List<BluetoothInfo> listResult = await PrintBluetoothThermal.pairedBluetooths;
      return listResult;
    } catch (e) {
      return [];
    }
  }

  /// Connect to Bluetooth Thermal Printer using MAC address
  Future<bool> connectBluetoothPrinter(String macAddress, String name) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (result) {
        connectedMacAddress = macAddress;
        connectedDeviceName = name;
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect current Bluetooth printer
  Future<bool> disconnectBluetoothPrinter() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      connectedMacAddress = null;
      connectedDeviceName = null;
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Check connection status
  Future<bool> isBluetoothConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      return false;
    }
  }

  /// Send raw ESC/POS bytes directly over Bluetooth socket
  Future<bool> printBytesDirectBluetooth(List<int> bytes) async {
    try {
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) return false;
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      return false;
    }
  }
}
