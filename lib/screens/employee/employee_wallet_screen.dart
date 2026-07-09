import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeeWalletScreen extends StatefulWidget {
  const EmployeeWalletScreen({super.key});

  @override
  State<EmployeeWalletScreen> createState() => _EmployeeWalletScreenState();
}

class _EmployeeWalletScreenState extends State<EmployeeWalletScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  double _balance = 0;
  dynamic _profile;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final res = await _client.from('profiles').select().eq('id', user.id).single();
        if (mounted) {
          setState(() {
            _profile = res;
            final salary = double.tryParse((res['salary'] ?? 0).toString()) ?? 0;
            final allowance = double.tryParse((res['allowance'] ?? 0).toString()) ?? 0;
            _balance = salary + allowance;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SALARY & PAYOUTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(isDark),
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  FadeInDown(child: _buildBalanceCard()),
                  const SizedBox(height: 32),
                  _sectionHeader('EARNINGS OVERVIEW', color: Colors.greenAccent),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _miniInfo('BASE SALARY', '₹${(_profile?['salary'] ?? 0).toInt()}', Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _miniInfo('ALLOWANCES', '₹${(_profile?['allowance'] ?? 0).toInt()}', Colors.purpleAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _miniInfo('NET MONTHLY', '₹${_balance.toInt()}', Colors.greenAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _miniInfo('LEAVES TAKEN', (_profile?['unpaid_leaves'] ?? 0).toString(), Colors.orangeAccent)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _sectionHeader('PAYMENT CALENDAR', color: Colors.indigoAccent),
                  const SizedBox(height: 16),
                  FadeInUp(child: _buildPayoutCalendar(isDark)),
                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(
      top: -100,
      right: -50,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(isDark ? 0.05 : 0.02),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, {Color color = Colors.indigoAccent}) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildPayoutCalendar(bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDay = DateTime(now.year, now.month, 1).weekday;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(now).toUpperCase(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Row(
                children: [
                  _calLegend('SALARY', Colors.greenAccent),
                  const SizedBox(width: 12),
                  _calLegend('BONUS', Colors.blueAccent),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + (firstDay % 7),
            itemBuilder: (context, index) {
              if (index < (firstDay % 7)) return const SizedBox();
              final day = index - (firstDay % 7) + 1;
              bool isSalaryD = day == 1; // Standard payday
              bool isAllowD = day == 5; // Standard allowance day

              return Container(
                decoration: BoxDecoration(
                  color: isSalaryD 
                      ? Colors.greenAccent.withOpacity(0.1) 
                      : (isAllowD ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSalaryD 
                        ? Colors.greenAccent.withOpacity(0.3) 
                        : (isAllowD ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: (isSalaryD || isAllowD) ? FontWeight.bold : FontWeight.normal,
                      color: (isSalaryD || isAllowD) 
                          ? (isSalaryD ? Colors.greenAccent : Colors.blueAccent) 
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _calLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: color.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final role = (_profile?['role'] ?? 'MEMBER').toString().toUpperCase();
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7B32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL MONTHLY ESTIMATE',
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white38, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${_balance.toInt()}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _statusBadge(role),
              const SizedBox(width: 8),
              _statusBadge('ACTIVE STATUS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String val, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

