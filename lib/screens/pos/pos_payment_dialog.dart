import 'package:flutter/material.dart';
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
  String _selectedMode = 'cash'; // 'cash', 'upi', 'khata', 'card'
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
        // 1. Attempt thermal print
        bool printed = false;
        if (PosHardwareService().autoPrint) {
          printed = await PosHardwareService().printThermalReceipt(receiptData);
        }

        if (mounted) {
          Navigator.pop(context, result);
          _showPostCheckoutSheet(context, receiptData, printed);
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

  void _showPostCheckoutSheet(BuildContext context, PosReceiptData data, bool printed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
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
                      Icon(printed ? Icons.check_circle : Icons.receipt_long, color: printed ? Colors.greenAccent : Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      Text("Order #${data.invoiceNumber}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text("Rs ${data.total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                printed
                    ? "Receipt printed to hardware. You can also share digital copy with customer:"
                    : "No hardware printer connected. Share or view thermal bill via PDF / WhatsApp image:",
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("WhatsApp Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                      label: const Text("Share PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        PosHardwareService().shareReceiptPdf(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                    icon: const Icon(Icons.print, color: Colors.amberAccent),
                    tooltip: "Retry Thermal Print",
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
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Terminal Tender & Checkout", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Total Payable Box
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
                    Text("Rs ${widget.total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text("Select Payment Method", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Mode Selectors
              Row(
                children: [
                  _modeCard('cash', 'Cash Tender', Icons.payments, Colors.greenAccent),
                  const SizedBox(width: 8),
                  _modeCard('upi', 'Dynamic UPI', Icons.qr_code_2, Colors.lightBlueAccent),
                  const SizedBox(width: 8),
                  _modeCard('khata', 'Student Khata', Icons.account_balance_wallet, Colors.amberAccent),
                  const SizedBox(width: 8),
                  _modeCard('card', 'Debit / Credit', Icons.credit_card, Colors.purpleAccent),
                ],
              ),

              const SizedBox(height: 16),
              // Dynamic Content per mode
              if (_selectedMode == 'cash') _buildCashTenderView(),
              if (_selectedMode == 'upi') _buildUpiQrView(),
              if (_selectedMode == 'khata') _buildStudentKhataView(),
              if (_selectedMode == 'card') _buildCardSwipeView(),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.print),
                  label: Text(
                    _isProcessing ? "Finalizing Order..." : "Confirm & Print Receipt (Rs ${widget.total.toStringAsFixed(2)})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  Widget _modeCard(String mode, String title, IconData icon, Color color) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white60, size: 22),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashTenderView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tenderedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: "Cash Tendered by Customer (Rs)",
                    labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Change to Return:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text("Rs ${_changeReturn.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick denominations
          Row(
            children: [100, 200, 500, 2000].map((denom) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: const Color(0xFF334155),
                  label: Text("Rs $denom", style: const TextStyle(color: Colors.white, fontSize: 11)),
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

  Widget _buildUpiQrView() {
    final upiUri = "upi://pay?pa=campusshop@upi&pn=HostelShop&am=${widget.total.toStringAsFixed(2)}&cu=INR&tn=POSOrder";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 130,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Scan with any UPI App", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Customer can scan GooglePay, PhonePe, Paytm or BHIM to pay instantly. Press confirm once payment notification arrives.", style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentKhataView() {
    final studentName = widget.selectedStudent?['full_name'] ?? 'No Student Selected';
    final balance = (widget.selectedStudent?['balance'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Account: $studentName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text("Current Balance: Rs ${balance.toStringAsFixed(2)}", style: TextStyle(color: balance >= widget.total ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text("After this purchase, balance will be: Rs ${(balance - widget.total).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCardSwipeView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Icon(Icons.credit_card, size: 40, color: Colors.purpleAccent),
          SizedBox(width: 16),
          Expanded(
            child: Text("Swipe, Tap, or Insert card on EDC Pinpad machine. Once authorized, tap Confirm & Print.", style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
