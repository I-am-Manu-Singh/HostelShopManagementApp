import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/pos_hardware_service.dart';
import '../../services/pos_sync_service.dart';
import '../../models/shop.dart';

class PosPaymentDialog extends StatefulWidget {
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double cgst;
  final double sgst;
  final double total;
  final Map<String, dynamic>? selectedStudent;

  const PosPaymentDialog({
    super.key,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.cgst,
    required this.sgst,
    required this.total,
    this.selectedStudent,
  });

  @override
  State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  String _selectedMode = 'cash';
  final _tenderedCtrl = TextEditingController();
  double _changeReturn = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tenderedCtrl.text = widget.total.toStringAsFixed(2);
    _tenderedCtrl.addListener(_calcChange);
  }

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    super.dispose();
  }

  void _calcChange() {
    final tendered = double.tryParse(_tenderedCtrl.text.trim()) ?? 0.0;
    setState(() {
      _changeReturn = (tendered - widget.total).clamp(0.0, 999999.0);
    });
  }

  Future<void> _completeCheckout() async {
    if ((_selectedMode == 'wallet' || _selectedMode == 'khata') && widget.selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a student account first for $_selectedMode payment!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final tendered = double.tryParse(_tenderedCtrl.text.trim()) ?? widget.total;
    final result = await PosSyncService().completePosCheckout(
      items: widget.items,
      subtotal: widget.subtotal,
      discount: widget.discount,
      cgst: widget.cgst,
      sgst: widget.sgst,
      total: widget.total,
      paymentMode: _selectedMode,
      customerId: widget.selectedStudent?['id'],
      customerName: widget.selectedStudent?['full_name'],
      tenderedAmount: _selectedMode == 'cash' ? tendered : null,
      changeAmount: _selectedMode == 'cash' ? _changeReturn : null,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result.success && result.receiptData != null) {
        final receiptData = result.receiptData!;
        
        // Attempt direct Bluetooth thermal print or fallback to OS print spooler/PDF
        bool printedOrSaved = false;
        try {
          printedOrSaved = await PosHardwareService().printThermalReceipt(receiptData);
        } catch (_) {
          // Fallback to saving/sharing PDF if printing fails
          await PosHardwareService().shareReceiptPdf(receiptData);
        }

        if (mounted) {
          Navigator.pop(context, result);
          _showPostCheckoutSheet(context, receiptData, printedOrSaved);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Checkout failed. Please retry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPostCheckoutSheet(BuildContext context, PosReceiptData data, bool success) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(success ? Icons.check_circle : Icons.picture_as_pdf, color: Colors.greenAccent, size: 24),
                      const SizedBox(width: 8),
                      Text("Order #${data.invoiceNumber}", style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text("₹ ${data.total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Receipt processed successfully. Choose an action below:",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        PosHardwareService().shareReceiptImage(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text("Save PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        PosHardwareService().shareReceiptPdf(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                    icon: const Icon(Icons.print, color: Colors.amber),
                    tooltip: "Retry Print",
                    onPressed: () {
                      Navigator.pop(ctx);
                      PosHardwareService().printThermalReceipt(data);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
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
        width: 620,
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
                  Text("Terminal Tender & Checkout", style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor.withOpacity(0.7)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF0D9488)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TOTAL AMOUNT DUE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("Incl. All GST & Discounts", style: TextStyle(color: Colors.white60, fontSize: 10)),
                      ],
                    ),
                    Text("₹ ${widget.total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text("Select Payment Method", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _modeCard('cash', 'Cash', Icons.payments, Colors.greenAccent, isDark, textColor),
                  const SizedBox(width: 6),
                  _modeCard('upi', 'UPI', Icons.qr_code_2, Colors.lightBlueAccent, isDark, textColor),
                  const SizedBox(width: 6),
                  _modeCard('wallet', 'Wallet', Icons.account_balance_wallet, Colors.tealAccent, isDark, textColor),
                  const SizedBox(width: 6),
                  _modeCard('khata', 'Khata', Icons.menu_book, Colors.amber, isDark, textColor),
                  const SizedBox(width: 6),
                  _modeCard('card', 'Card', Icons.credit_card, Colors.purpleAccent, isDark, textColor),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedMode == 'cash') _buildCashTenderView(isDark, textColor, containerBg),
              if (_selectedMode == 'upi') _buildUpiQrView(isDark, textColor, containerBg),
              if (_selectedMode == 'wallet') _buildStudentWalletView(isDark, textColor, containerBg),
              if (_selectedMode == 'khata') _buildStudentKhataView(isDark, textColor, containerBg),
              if (_selectedMode == 'card') _buildCardSwipeView(isDark, textColor, containerBg),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.print),
                  label: Text(
                    _isProcessing ? "Finalizing Order..." : "Confirm & Print / Save PDF (₹ ${widget.total.toStringAsFixed(2)})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isProcessing ? null : _completeCheckout,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(String mode, String title, IconData icon, Color color, bool isDark, Color textColor) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12), width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : textColor.withOpacity(0.6), size: 20),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: isSelected ? textColor : textColor.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashTenderView(bool isDark, Color textColor, Color containerBg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tenderedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Cash Tendered (₹)",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Change Return:", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
                      Text("₹ ${_changeReturn.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [100, 200, 500, 2000].map((denom) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  label: Text("₹ $denom", style: TextStyle(color: textColor, fontSize: 11)),
                  onPressed: () {
                    _tenderedCtrl.text = denom.toDouble().toStringAsFixed(2);
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiQrView(bool isDark, Color textColor, Color containerBg) {
    final hardware = PosHardwareService();
    final vpa = hardware.merchantUpiVpa.trim().isNotEmpty ? hardware.merchantUpiVpa.trim() : "campusshop@upi";
    final payeeName = Uri.encodeComponent(hardware.merchantName.trim().isNotEmpty ? hardware.merchantName.trim() : hardware.storeName);
    final upiUri = "upi://pay?pa=$vpa&pn=$payeeName&am=${widget.total.toStringAsFixed(2)}&cu=INR&tn=POSOrder";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(6),
            child: QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 110,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Scan with UPI App", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Pay to: $vpa", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text("Scan via GPay, PhonePe, Paytm, or BHIM. Press confirm once successful.", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentWalletView(bool isDark, Color textColor, Color containerBg) {
    final studentName = widget.selectedStudent?['full_name'] ?? 'No Student Selected';
    final balance = (widget.selectedStudent?['balance'] as num?)?.toDouble() ?? 0.0;
    final hasSufficientBal = balance >= widget.total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Student Wallet: $studentName", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Bal: ₹ ${balance.toStringAsFixed(2)}", style: TextStyle(color: hasSufficientBal ? Colors.tealAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.selectedStudent == null)
            const Text("⚠️ Please select a student account from the top bar to deduct from their wallet.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
          else if (!hasSufficientBal)
            Text("⚠️ Insufficient Wallet Balance! Needs ₹ ${widget.total.toStringAsFixed(2)} (Short by ₹ ${(widget.total - balance).toStringAsFixed(2)}). Use Khata, Cash, or UPI instead.", style: const TextStyle(color: Colors.redAccent, fontSize: 12))
          else
            Text("Wallet after deduction: ₹ ${(balance - widget.total).toStringAsFixed(2)}", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStudentKhataView(bool isDark, Color textColor, Color containerBg) {
    final studentName = widget.selectedStudent?['full_name'] ?? 'No Student Selected';
    final balance = (widget.selectedStudent?['balance'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Khata Ledger: $studentName", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Bal: ₹ ${balance.toStringAsFixed(2)}", style: TextStyle(color: balance >= widget.total ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.selectedStudent == null)
            const Text("⚠️ Please select a student account from the top bar to charge to their Khata.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
          else
            Text("Balance after purchase: ₹ ${(balance - widget.total).toStringAsFixed(2)}", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCardSwipeView(bool isDark, Color textColor, Color containerBg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 36, color: Colors.purpleAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Text("Swipe, Tap, or Insert card on the EDC machine. Confirm once authorized.", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}