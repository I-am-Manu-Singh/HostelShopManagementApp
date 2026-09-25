import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../services/pos_hardware_service.dart';

class PosHardwareSettingsDialog extends StatefulWidget {
  const PosHardwareSettingsDialog({super.key});

  @override
  State<PosHardwareSettingsDialog> createState() => _PosHardwareSettingsDialogState();
}

class _PosHardwareSettingsDialogState extends State<PosHardwareSettingsDialog> {
  final _service = PosHardwareService();
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _upiVpaCtrl;
  late TextEditingController _merchNameCtrl;
  late int _paperWidth;
  late bool _autoPrint;
  late ReceiptTemplateStyle _templateStyle;
  late bool _printBarcode;
  late bool _cashDrawerPulse;

  List<BluetoothInfo> _pairedPrinters = [];
  bool _scanningBt = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _service.storeName);
    _addrCtrl = TextEditingController(text: _service.storeAddress);
    _gstCtrl = TextEditingController(text: _service.storeGstin);
    _phoneCtrl = TextEditingController(text: _service.storePhone);
    _footerCtrl = TextEditingController(text: _service.footerNote);
    _upiVpaCtrl = TextEditingController(text: _service.merchantUpiVpa);
    _merchNameCtrl = TextEditingController(text: _service.merchantName);
    _paperWidth = _service.paperWidthMm;
    _autoPrint = _service.autoPrint;
    _templateStyle = _service.templateStyle;
    _printBarcode = _service.printBarcode;
    _cashDrawerPulse = _service.cashDrawerPulse;

    _scanBtPrinters();
  }

  String? _btStatusMessage;
  bool _isBtOff = false;

  Future<void> _scanBtPrinters() async {
    if (!mounted) return;
    setState(() {
      _scanningBt = true;
      _btStatusMessage = null;
      _isBtOff = false;
    });

    final check = await _service.checkAndRequestBluetoothState();
    if (!check['granted']) {
      if (mounted) {
        setState(() {
          _scanningBt = false;
          _btStatusMessage = check['message'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(check['message'] ?? 'Bluetooth permission required'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!check['bluetoothOn']) {
      if (mounted) {
        setState(() {
          _scanningBt = false;
          _isBtOff = true;
          _btStatusMessage = 'Bluetooth adapter is turned OFF on this device.';
        });
      }
      return;
    }

    final list = await _service.getPairedBluetoothPrinters();
    if (mounted) {
      setState(() {
        _pairedPrinters = list;
        _scanningBt = false;
        if (list.isEmpty) {
          _btStatusMessage = 'No paired Bluetooth thermal printers found. Please pair printer first in Android/iOS Bluetooth settings.';
        }
      });
    }
  }

  Future<void> _connectBt(String mac, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _service.connectBluetoothPrinter(mac, name);
    if (mounted) {
      setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? "Connected to $name" : "Failed to connect to $name. Check printer power & distance."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _gstCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    _upiVpaCtrl.dispose();
    _merchNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _testPrint() async {
    final sampleReceipt = PosReceiptData(
      storeName: _nameCtrl.text,
      storeAddress: _addrCtrl.text,
      storeGstin: _gstCtrl.text,
      storePhone: _phoneCtrl.text,
      invoiceNumber: "TEST-0001",
      dateTime: DateTime.now(),
      cashierName: "Admin",
      customerName: "Sample Customer",
      templateStyle: _templateStyle,
      items: [
        PosReceiptItem(name: "Amul Milk 500ml", quantity: 2, unitPrice: 32.0, totalPrice: 64.0, hsn: "0401"),
        PosReceiptItem(name: "Maggi 2-Min Noodles", quantity: 4, unitPrice: 14.0, totalPrice: 56.0, hsn: "1902"),
      ],
      subtotal: 120.0,
      discount: 10.0,
      cgst: 2.75,
      sgst: 2.75,
      total: 115.50,
      paymentMode: "cash",
      tenderedAmount: 200.0,
      changeAmount: 84.50,
      footerNote: _footerCtrl.text,
    );

    final success = await _service.printThermalReceipt(sampleReceipt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Test Receipt sent to printer / PDF spooler' : 'Test print canceled or error'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF121418) : Colors.white;
    final containerBg = isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text("Printer & Template Settings", style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor.withOpacity(0.7)),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bluetooth,
                              color: _service.connectedMacAddress != null ? Colors.greenAccent : Colors.blueAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Bluetooth Thermal Hardware (ESC/POS)",
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _scanBtPrinters,
                          icon: _scanningBt
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                              : const Icon(Icons.refresh, size: 16, color: Colors.blueAccent),
                          label: Text(_scanningBt ? "Scanning..." : "Scan Paired", style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (_service.connectedMacAddress != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Connected: ${_service.connectedDeviceName ?? 'Printer'} (${_service.connectedMacAddress})",
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final sample = PosReceiptData(
                                  storeName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : _service.storeName,
                                  storeAddress: _addrCtrl.text.trim().isNotEmpty ? _addrCtrl.text.trim() : _service.storeAddress,
                                  storeGstin: _gstCtrl.text.trim(),
                                  storePhone: _phoneCtrl.text.trim(),
                                  invoiceNumber: "TEST-001",
                                  dateTime: DateTime.now(),
                                  items: [
                                    PosReceiptItem(name: "Sample Product A", quantity: 1, unitPrice: 50.0, totalPrice: 50.0),
                                    PosReceiptItem(name: "Sample Product B", quantity: 2, unitPrice: 25.0, totalPrice: 50.0),
                                  ],
                                  subtotal: 100.0,
                                  total: 100.0,
                                  paymentMode: "CASH",
                                  footerNote: _footerCtrl.text.trim(),
                                );
                                final ok = await _service.printThermalReceipt(sample);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Test receipt printed via Bluetooth ESC/POS!' : 'Print failed. Check printer feed & battery.'),
                                    backgroundColor: ok ? Colors.green : Colors.redAccent,
                                  ),
                                );
                              },
                              child: const Text("Test Print", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                await _service.disconnectBluetoothPrinter();
                                setState(() {});
                              },
                              child: const Text("Disconnect", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_btStatusMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isBtOff ? Colors.redAccent.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _isBtOff ? Colors.redAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_isBtOff ? Icons.bluetooth_disabled_rounded : Icons.info_outline, color: _isBtOff ? Colors.redAccent : Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_btStatusMessage!, style: TextStyle(color: _isBtOff ? Colors.redAccent : Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            if (_isBtOff) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.bluetooth, size: 16),
                                  label: const Text('Turn ON Bluetooth & Scan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    // Trigger bluetooth adapter request
                                    try {
                                      await PrintBluetoothThermal.bluetoothEnabled;
                                    } catch (_) {}
                                    _scanBtPrinters();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_service.connectedMacAddress == null && _pairedPrinters.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        "No Bluetooth printer connected. Direct USB OTG printers or system PDF print spooler will be used as fallback.",
                        style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                    if (_pairedPrinters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text("Select Paired Device:", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ..._pairedPrinters.map((device) {
                        final isConnected = _service.connectedMacAddress == device.macAdress;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.blue.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            leading: Icon(Icons.print, size: 18, color: textColor),
                            title: Text(device.name.isNotEmpty ? device.name : 'Unknown Printer', style: TextStyle(color: textColor, fontSize: 12)),
                            subtitle: Text(device.macAdress, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10)),
                            trailing: isConnected
                                ? const Chip(
                                    label: Text("Connected", style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                                    backgroundColor: Colors.transparent,
                                    visualDensity: VisualDensity.compact,
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => _connectBt(device.macAdress, device.name),
                                    child: const Text("Connect", style: TextStyle(fontSize: 11)),
                                  ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text("Print Template Layout Style", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _templateChip("Standard Retail", ReceiptTemplateStyle.retailStandard, Icons.receipt_long, isDark, textColor, containerBg),
                  _templateChip("GST Detailed", ReceiptTemplateStyle.gstDetailed, Icons.account_balance, isDark, textColor, containerBg),
                  _templateChip("Compact 58mm", ReceiptTemplateStyle.compactRoll, Icons.compress, isDark, textColor, containerBg),
                  _templateChip("Kitchen KOT", ReceiptTemplateStyle.kitchenKot, Icons.restaurant, isDark, textColor, containerBg),
                ],
              ),
              const SizedBox(height: 16),
              Text("Page & Roll Width Specifications", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      selected: _paperWidth == 58,
                      selectedColor: Colors.amber,
                      backgroundColor: containerBg,
                      label: Center(child: Text("58mm Roll", style: TextStyle(color: _paperWidth == 58 ? Colors.black : textColor))),
                      onSelected: (val) => setState(() => _paperWidth = 58),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      selected: _paperWidth == 80,
                      selectedColor: Colors.amber,
                      backgroundColor: containerBg,
                      label: Center(child: Text("80mm Roll", style: TextStyle(color: _paperWidth == 80 ? Colors.black : textColor))),
                      onSelected: (val) => setState(() => _paperWidth = 80),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Auto-Print on Checkout", style: TextStyle(color: textColor, fontSize: 13)),
                subtitle: Text("Trigger thermal print spooler upon checkout completion", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
                value: _autoPrint,
                activeColor: Colors.amber,
                onChanged: (val) => setState(() => _autoPrint = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Print Code128 Invoice Barcode", style: TextStyle(color: textColor, fontSize: 13)),
                subtitle: Text("Appends scannable barcode at the ticket bottom", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
                value: _printBarcode,
                activeColor: Colors.amber,
                onChanged: (val) => setState(() => _printBarcode = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Cash Drawer Kick Pulse", style: TextStyle(color: textColor, fontSize: 13)),
                subtitle: Text("Sends 24V drawer trigger during cash checkout", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)),
                value: _cashDrawerPulse,
                activeColor: Colors.amber,
                onChanged: (val) => setState(() => _cashDrawerPulse = val),
              ),
              const SizedBox(height: 16),
              const Text("Store Header & Tax Identity", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInput("Store / Hostel Name", _nameCtrl, isDark, textColor, containerBg),
              const SizedBox(height: 10),
              _buildInput("Address", _addrCtrl, isDark, textColor, containerBg),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildInput("GSTIN", _gstCtrl, isDark, textColor, containerBg)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Store Phone", _phoneCtrl, isDark, textColor, containerBg)),
                ],
              ),
              const SizedBox(height: 10),
              _buildInput("Receipt Footer Note", _footerCtrl, isDark, textColor, containerBg),
              const SizedBox(height: 16),
              const Text("Digital Payments & Dynamic UPI", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildInput("Merchant UPI VPA (e.g. shop@upi)", _upiVpaCtrl, isDark, textColor, containerBg)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Payee Business Name", _merchNameCtrl, isDark, textColor, containerBg)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text("Print Test Ticket"),
                    onPressed: _testPrint,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      await _service.saveSettings(
                        paperWidth: _paperWidth,
                        autoPrintReceipts: _autoPrint,
                        style: _templateStyle,
                        name: _nameCtrl.text.trim(),
                        address: _addrCtrl.text.trim(),
                        gstin: _gstCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                        footer: _footerCtrl.text.trim(),
                        printBarcodeOnBill: _printBarcode,
                        kickDrawer: _cashDrawerPulse,
                        merchantVpa: _upiVpaCtrl.text.trim(),
                        merchName: _merchNameCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('POS & Printer Configuration Saved'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    child: const Text("Save Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String title, ReceiptTemplateStyle style, IconData icon, bool isDark, Color textColor, Color containerBg) {
    final isSel = _templateStyle == style;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSel ? Colors.black : Colors.amber),
      selected: isSel,
      selectedColor: Colors.amber,
      backgroundColor: containerBg,
      label: Text(title, style: TextStyle(color: isSel ? Colors.black : textColor, fontSize: 11, fontWeight: FontWeight.bold)),
      onSelected: (val) {
        if (val) setState(() => _templateStyle = style);
      },
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, bool isDark, Color textColor, Color containerBg) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: textColor, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
        filled: true,
        fillColor: containerBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}