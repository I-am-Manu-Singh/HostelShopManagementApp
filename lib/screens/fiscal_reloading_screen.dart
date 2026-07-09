import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class FiscalReloadingScreen extends StatefulWidget {
  const FiscalReloadingScreen({super.key});

  @override
  State<FiscalReloadingScreen> createState() => _FiscalReloadingScreenState();
}

class _FiscalReloadingScreenState extends State<FiscalReloadingScreen> {
  final _amountController = TextEditingController();
  List<dynamic> _transactions = [];
  bool _isLoadingHistory = true;
  bool _isProcessing = false;
  String _selectedMethod = 'UPI';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final res = await client.from('wallet_transactions').select().eq('user_id', user.id).order('created_at', ascending: false).limit(10);
      if (mounted) setState(() { _transactions = res; _isLoadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _processReload() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final success = await DatabaseService().reloadWallet(amount, 'REFILL: $_selectedMethod');
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet balance added successfully'), backgroundColor: Colors.greenAccent));
          _amountController.clear();
          _fetchHistory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reload failed. Please try again.'), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('LOAD BALANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 32),
                _buildAmountInput(isDark),
                const SizedBox(height: 32),
                _buildPaymentMethods(isDark),
                const SizedBox(height: 40),
                _buildPayButton(isDark),
                const SizedBox(height: 48),
                _buildHistorySection(isDark),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRANSACTION AUDIT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
        const SizedBox(height: 20),
        if (_isLoadingHistory)
          const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        else if (_transactions.isEmpty)
          Center(child: Text('NO PRIOR ACTIVITY RECORDED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)))
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Column(
              children: List.generate(_transactions.length, (index) {
                final t = _transactions[index];
                return Column(
                  children: [
                    _historyItem(t, isDark),
                    if (index != _transactions.length - 1) 
                      Divider(height: 32, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _historyItem(dynamic t, bool isDark) {
    final amount = t['amount'] ?? 0;
    final date = DateFormat('dd MMM, HH:mm').format(DateTime.parse(t['created_at']));
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.greenAccent, size: 16)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['transaction_type']?.toString().toUpperCase() ?? 'RELOAD', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(date, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
        ])),
        Text('+₹$amount', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.indigoAccent, size: 28)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ADD MONEY TO WALLET', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Secure & Instant Top-up', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ])),
        ],
      ),
    );
  }

  Widget _buildAmountInput(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ENTER AMOUNT (₹)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(color: textColor, fontSize: 32, fontWeight: FontWeight.w900),
          decoration: InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12), border: InputBorder.none, prefixText: '₹ ', prefixStyle: const TextStyle(color: Colors.indigoAccent)),
        ),
      ),
    ]);
  }

  Widget _buildPaymentMethods(bool isDark) {
    final methods = [{'id': 'UPI', 'label': 'UPI / Google Pay / PhonePe', 'icon': Icons.bolt_rounded}, {'id': 'CARD', 'label': 'Credit / Debit Card', 'icon': Icons.credit_card_rounded}, {'id': 'NET', 'label': 'Net Banking', 'icon': Icons.account_balance_rounded}];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('SELECT PAYMENT METHOD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
       const SizedBox(height: 16),
       ...methods.map((m) => _methodTile(m, isDark)).toList()
    ]);
  }

  Widget _methodTile(Map<String, dynamic> m, bool isDark) {
    bool isSelected = _selectedMethod == m['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = m['id']),
      child: FadeInLeft(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isSelected ? Colors.indigoAccent.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)))),
          child: Row(
            children: [
              Icon(m['icon'] as IconData, color: isSelected ? Colors.indigoAccent : (isDark ? Colors.white24 : Colors.black26), size: 20),
              const SizedBox(width: 16),
              Text(m['label'], style: GoogleFonts.outfit(color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black45), fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.indigoAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayButton(bool isDark) {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity, height: 65,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processReload,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          child: _isProcessing 
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('PAY NOW', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
        ),
      ),
    );
  }
}
