import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class CampusProtocolHub extends StatefulWidget {
  const CampusProtocolHub({super.key});

  @override
  State<CampusProtocolHub> createState() => _CampusProtocolHubState();
}

class _CampusProtocolHubState extends State<CampusProtocolHub> {
  final List<Map<String, dynamic>> _protocols = [
    {
      'title': 'HOSTEL RULES',
      'category': 'Hostel',
      'desc': 'Gate timings, quiet hours, and visitor policy.',
      'icon': Icons.home_work_rounded,
      'color': Colors.indigoAccent,
      'items': [
        {'title': 'Night Curfew', 'detail': 'Main gate closes at 23:00. Late entry requires warden approval.'},
        {'title': 'Quiet Hours', 'detail': '22:00 to 07:00. Loud activities not allowed during this time.'},
        {'title': 'Visitor Policy', 'detail': 'Visitors are allowed only in the common lobby. No overnight guests.'},
      ]
    },
    {
      'title': 'MESS TIMINGS',
      'category': 'Mess',
      'desc': 'Meal timings and hygiene standards.',
      'icon': Icons.restaurant_rounded,
      'color': Colors.orangeAccent,
      'items': [
        {'title': 'Breakfast', 'detail': '07:30 - 09:30. Biometric check-in required.'},
        {'title': 'Dinner', 'detail': '19:30 - 21:30.'},
        {'title': 'Water', 'detail': 'RO water available 24/7 on every floor.'},
      ]
    },
    {
      'title': 'SHOP RULES',
      'category': 'Shop',
      'desc': 'Purchase limits and QR checkout rules.',
      'icon': Icons.shopping_basket_rounded,
      'color': Colors.pinkAccent,
      'items': [
        {'title': 'Checkout', 'detail': 'Scan QR first, then confirm in app.'},
        {'title': 'Daily Credit Limit', 'detail': 'Maximum ₹500 per day. Clear balance by weekend.'},
        {'title': 'Returns', 'detail': 'Accepted within 24 hours for sealed items only.'},
      ]
    },
    {
      'title': 'EMERGENCY INFO',
      'category': 'Emergency',
      'desc': 'Evacuation and medical contacts.',
      'icon': Icons.emergency_rounded,
      'color': Colors.redAccent,
      'items': [
        {'title': 'Fire Exit', 'detail': 'Follow the arrows to Assembly Point A (North Wing).'},
        {'title': 'Medical Room', 'detail': 'Ground floor, Block C. Call ext. 101.'},
        {'title': 'Security Office', 'detail': 'Main entrance gate. Open 24/7.'},
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      appBar: AppBar(
        title: Text('CAMPUS GUIDELINES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(child: Text('Rules & Guidelines', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1))),
                const SizedBox(height: 8),
                Text('Standard rules and procedures for campus life.', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
                const SizedBox(height: 48),
                ..._protocols.map((p) => _buildProtocolCard(p)).toList(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(top: -50, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildProtocolCard(Map<String, dynamic> p) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: ExpansionTile(
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(p['icon'], color: p['color'], size: 24)),
          title: Text(p['title'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(p['desc'], style: const TextStyle(color: Colors.white24, fontSize: 10)),
          iconColor: Colors.white38,
          collapsedIconColor: Colors.white24,
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          expandedAlignment: Alignment.topLeft,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (p['items'] as List).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'].toUpperCase(), style: GoogleFonts.outfit(color: p['color'], fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(item['detail'], style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
