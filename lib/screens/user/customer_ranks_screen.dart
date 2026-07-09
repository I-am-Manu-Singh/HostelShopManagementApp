import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomerRanksScreen extends StatefulWidget {
  const CustomerRanksScreen({super.key});

  @override
  State<CustomerRanksScreen> createState() => _CustomerRanksScreenState();
}

class _CustomerRanksScreenState extends State<CustomerRanksScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _ranks = [];
  int _myRank = -1;
  double _myTotalValue = 0.0;
  int _myTotalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCustomerLeaderboard();
  }

  Future<void> _fetchCustomerLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      
      // Fetch all store orders in the past 30 days to calculate metrics
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final List<dynamic> orders = await _client
          .from('shop_orders')
          .select('*, profiles(id, full_name, role)')
          .gte('created_at', oneMonthAgo);

      // Group metrics by user
      final Map<String, Map<String, dynamic>> userMetrics = {};
      
      for (var o in orders) {
        final profile = o['profiles'];
        if (profile == null) continue;
        
        final uid = profile['id'] as String;
        final name = profile['full_name'] as String? ?? 'Valued Customer';
        final val = (o['total_price'] as num? ?? 0.0).toDouble();
        
        if (userMetrics.containsKey(uid)) {
          userMetrics[uid]!['count'] = (userMetrics[uid]!['count'] as int) + 1;
          userMetrics[uid]!['value'] = (userMetrics[uid]!['value'] as double) + val;
        } else {
          userMetrics[uid] = {
            'id': uid,
            'name': name,
            'count': 1,
            'value': val,
          };
        }
      }

      // Transform map to sorted list
      final sortedRanks = userMetrics.values.toList()
        ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

      if (mounted) {
        setState(() {
          _ranks = sortedRanks;
          if (user != null) {
            final idx = _ranks.indexWhere((r) => r['id'] == user.id);
            if (idx != -1) {
              _myRank = idx + 1;
              _myTotalCount = _ranks[idx]['count'] as int;
              _myTotalValue = _ranks[idx]['value'] as double;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customer rankings: $e');
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('CUSTOMER RANKS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : RefreshIndicator(
              onRefresh: _fetchCustomerLeaderboard,
              color: Colors.indigoAccent,
              child: CustomScrollView(
                slivers: [
                  // Current user summary card
                  if (_myRank != -1)
                    SliverToBoxAdapter(
                      child: FadeInDown(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigoAccent.withOpacity(0.15), Colors.pinkAccent.withOpacity(0.15)],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('#$_myRank', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('YOUR LOGISTICS STANDING', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
                                    const SizedBox(height: 2),
                                    Text('YOU', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                                    Text(
                                      '$_myTotalCount Orders in past month',
                                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${_myTotalValue.toInt()}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 22)),
                                  Text('TOTAL VALUE', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Top standing label
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text('30-DAY ACQUISITION STANDINGS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
                    ),
                  ),

                  // Leader list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final rank = _ranks[i];
                        final isMe = rank['id'] == _client.auth.currentUser?.id;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isMe 
                              ? Colors.indigoAccent.withOpacity(0.05)
                              : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isMe ? Colors.indigoAccent.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text('#${i + 1}', style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w900, fontSize: 13)),
                              const SizedBox(width: 16),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                child: Text(rank['name']?[0] ?? 'C', style: TextStyle(color: textColor, fontSize: 12)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rank['name'] ?? 'Valued Customer',
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      '${rank['count']} orders placed',
                                      style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${(rank['value'] as double).toInt()}',
                                style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _ranks.length,
                    ),
                  ),

                  if (_ranks.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'NO STANDING DATA AVAILABLE',
                          style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
    );
  }
}
