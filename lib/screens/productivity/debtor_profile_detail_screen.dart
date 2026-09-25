import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DebtorProfileDetailScreen extends StatefulWidget {
  final String debtorName;
  final String? debtorPhone;
  final String? photoUrl;
  final String? debtorUserId;
  final List<dynamic> transactions;
  final VoidCallback onDataChanged;

  const DebtorProfileDetailScreen({
    super.key,
    required this.debtorName,
    this.debtorPhone,
    this.photoUrl,
    this.debtorUserId,
    required this.transactions,
    required this.onDataChanged,
  });

  @override
  State<DebtorProfileDetailScreen> createState() => _DebtorProfileDetailScreenState();
}

class _DebtorProfileDetailScreenState extends State<DebtorProfileDetailScreen> {
  final _client = Supabase.instance.client;
  late List<dynamic> _txList;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _txList = List<dynamic>.from(widget.transactions);
  }

  double get _totalLent {
    double sum = 0;
    for (var t in _txList) {
      if (t['type'] != 'return') {
        sum += (t['amount'] as num? ?? 0).toDouble();
      }
    }
    return sum;
  }

  double get _totalReturned {
    double sum = 0;
    for (var t in _txList) {
      if (t['type'] == 'return') {
        sum += (t['amount'] as num? ?? 0).toDouble();
      }
    }
    return sum;
  }

  double get _pendingBalance => _totalLent - _totalReturned;

  Future<void> _makePhoneCall() async {
    final phone = widget.debtorPhone?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid contact number registered for this person.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.debtorPhone?.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone number for WhatsApp.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    // Pre-fill polite payment reminder message
    final msg = Uri.encodeComponent(
      'Hello ${widget.debtorName}, this is a gentle reminder regarding your outstanding Khata/Udhar balance of ₹${_pendingBalance.toInt()}. Kindly clear or make partial payment at your convenience. Thank you!',
    );
    final waUri = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showRecordPaymentModal({bool isFull = false}) {
    final amtCtrl = TextEditingController(text: isFull ? _pendingBalance.toInt().toString() : '');
    final notesCtrl = TextEditingController(text: isFull ? 'Full settlement payment' : 'Partial payment received');
    bool updateWallet = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFull ? 'RECORD FULL SETTLEMENT' : 'RECORD PARTIAL PAYMENT',
                      style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Pending Dues: ₹${_pendingBalance.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Amount Received (₹)',
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.greenAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Notes / Payment Reference (UPI, Cash, etc.)',
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    prefixIcon: const Icon(Icons.receipt_long, color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (widget.debtorUserId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: updateWallet,
                        activeColor: Colors.greenAccent,
                        onChanged: (v) => setMState(() => updateWallet = v ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Credit/Restore debtor user wallet balance',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _executePayment(amtCtrl.text, notesCtrl.text, updateWallet, ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: Text(
                      'CONFIRM RECEIPT (₹${amtCtrl.text.isEmpty ? "0" : amtCtrl.text})',
                      style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _executePayment(String amtStr, String notes, bool syncWallet, BuildContext sheetCtx) async {
    final amt = double.tryParse(amtStr);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid received amount.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    Navigator.pop(sheetCtx);

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final newRecord = {
        'user_id': user.id,
        'debtor_user_id': widget.debtorUserId,
        'debtor_name': widget.debtorName,
        'debtor_phone': widget.debtorPhone,
        'amount': amt,
        'type': 'return',
        'status': 'settled',
        'notes': notes,
        'photo_url': widget.photoUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _client.from('lending_book').insert(newRecord);

      // Optionally credit back wallet
      if (widget.debtorUserId != null && syncWallet) {
        try {
          final pRes = await _client.from('profiles').select('balance').eq('id', widget.debtorUserId!).maybeSingle();
          final curBal = (pRes?['balance'] as num? ?? 0.0).toDouble();
          await _client.from('profiles').update({'balance': curBal + amt}).eq('id', widget.debtorUserId!);
        } catch (_) {}
      }

      setState(() {
        _txList.insert(0, newRecord);
        _isLoading = false;
      });

      widget.onDataChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully credited ₹${amt.toInt()} to ${widget.debtorName} Khata.'), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08090A) : Colors.white,
      appBar: AppBar(
        title: Text('LENDER PROFILE CARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Profile Header with Photo, Name & Contact
              _buildPersonHero(isDark),
              const SizedBox(height: 24),
              // Call & WhatsApp Direct Action Bar
              _buildCommunicationBar(),
              const SizedBox(height: 24),
              // Outstanding Breakdown Card
              _buildFinancialSummaryCard(isDark),
              const SizedBox(height: 24),
              // Quick Settlement Buttons
              _buildSettlementActionButtons(),
              const SizedBox(height: 36),
              // Date-wise Transaction History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TRANSACTION AUDIT TRAIL', style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('${_txList.length} Records', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ..._txList.map((tx) => _buildTransactionTile(tx, isDark)),
              const SizedBox(height: 60),
            ],
          ),
    );
  }

  Widget _buildPersonHero(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          widget.photoUrl != null && widget.photoUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.network(
                    widget.photoUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackAvatar(),
                  ),
                )
              : _fallbackAvatar(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.debtorName.toUpperCase(),
                  style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.debtorPhone ?? 'NO PHONE REGISTERED',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (widget.debtorUserId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('DATABASE REGISTERED USER', style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          widget.debtorName.isNotEmpty ? widget.debtorName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildCommunicationBar() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _makePhoneCall,
            icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
            label: const Text('CALL DEBTOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
            label: const Text('WHATSAPP NOTICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryCard(bool isDark) {
    final pending = _pendingBalance;
    final isClear = pending <= 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClear
              ? [Colors.greenAccent.withOpacity(0.15), Colors.greenAccent.withOpacity(0.04)]
              : [Colors.amberAccent.withOpacity(0.15), Colors.orangeAccent.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: (isClear ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PENDING TO RECEIVE', style: GoogleFonts.outfit(color: isClear ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isClear ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isClear ? 'SETTLED' : 'DUE',
                  style: TextStyle(color: isClear ? Colors.greenAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${pending.toInt()}',
            style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 38, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL UDHAR LENT', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('₹${_totalLent.toInt()}', style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL RECOVERED', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('₹${_totalReturned.toInt()}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showRecordPaymentModal(isFull: false),
            icon: const Icon(Icons.add_task_rounded, color: Colors.black, size: 18),
            label: const Text('PARTIAL PAYMENT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pendingBalance > 0 ? () => _showRecordPaymentModal(isFull: true) : null,
            icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
            label: const Text('FULL SETTLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(dynamic tx, bool isDark) {
    final isReturn = tx['type'] == 'return';
    final amt = (tx['amount'] as num? ?? 0).toDouble();
    final dt = DateTime.tryParse(tx['created_at']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    final notes = tx['notes']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isReturn ? Colors.greenAccent.withOpacity(0.2) : Colors.amberAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isReturn ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReturn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isReturn ? Colors.greenAccent : Colors.amberAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReturn ? 'PAYMENT RECEIVED' : 'UDHAR DISBURSED',
                  style: GoogleFonts.outfit(
                    color: isReturn ? Colors.greenAccent : Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10)),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: $notes', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Text(
            '${isReturn ? "-" : "+"}₹${amt.toInt()}',
            style: GoogleFonts.outfit(
              color: isReturn ? Colors.greenAccent : Colors.amberAccent,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
