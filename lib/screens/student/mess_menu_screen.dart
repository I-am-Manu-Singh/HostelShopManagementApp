import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../mess_menu_calendar_screen.dart';

class MessMenuScreen extends StatelessWidget {
  const MessMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final List<Map<String, dynamic>> menu = [
      {'day': 'MONDAY', 'breakfast': 'Poha & Chai', 'lunch': 'Rajma Chawal', 'tea': 'Samosa & Tea', 'dinner': 'Paneer & Roti', 'calories': '2100'},
      {'day': 'TUESDAY', 'breakfast': 'Aloo Paratha', 'lunch': 'Kadadi Chawal', 'tea': 'Biscuits & Coffee', 'dinner': 'Mix Veg & Roti', 'calories': '2300'},
      {'day': 'WEDNESDAY', 'breakfast': 'Idli Sambhar', 'lunch': 'Chole Bhature', 'tea': 'Bread Pakora & Tea', 'dinner': 'Dal Tadka & Rice', 'calories': '2250'},
      {'day': 'THURSDAY', 'breakfast': 'Oatmeal & Fruits', 'lunch': 'Veg Biryani', 'tea': 'Puff Pastry & Tea', 'dinner': 'Malai Kofta & Roti', 'calories': '2400'},
      {'day': 'FRIDAY', 'breakfast': 'Sandwich & Coffee', 'lunch': 'Pasta & Salad', 'tea': 'Maggie & Cold Drinks', 'dinner': 'Palak Paneer', 'calories': '2150'},
      {'day': 'SATURDAY', 'breakfast': 'Puri Bhaji', 'lunch': 'Fried Rice', 'tea': 'Dhokla & Tea', 'dinner': 'Special Thali', 'calories': '2600'},
      {'day': 'SUNDAY', 'breakfast': 'Stuffed Paratha', 'lunch': 'Paneer Lababdar', 'tea': 'Cake & Coffee', 'dinner': 'Veg Pulao & Raita', 'calories': '2500'},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('MESS MENU', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded, color: Colors.indigoAccent), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessMenuCalendarScreen()))),
        ],
      ),
      body: Stack(
        children: [
          _buildRefractionOrbs(),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
              if (crossCount > 1) {
                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: menu.length,
                  itemBuilder: (context, i) => FadeInUp(
                    delay: Duration(milliseconds: i * 50),
                    child: _buildDayCard(menu[i], isDark),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: menu.length,
                itemBuilder: (context, i) => FadeInUp(
                  delay: Duration(milliseconds: i * 100),
                  child: _buildDayCard(menu[i], isDark),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildRefractionOrbs() {
    return Positioned(bottom: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(width: 250, height: 250, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildDayCard(Map<String, dynamic> data, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data['day'], style: GoogleFonts.outfit(color: Colors.indigoAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text('${data['calories']} KCAL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 20),
          _mealItem('BREAKFAST', data['breakfast'], Icons.wb_sunny_outlined, Colors.amberAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('LUNCH', data['lunch'], Icons.wb_cloudy_outlined, Colors.blueAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('TEA-TIME', data['tea'], Icons.local_cafe_outlined, Colors.orangeAccent, isDark),
          const SizedBox(height: 12),
          _mealItem('DINNER', data['dinner'], Icons.nightlight_round_outlined, Colors.purpleAccent, isDark),
        ],
      ),
    );
  }

  Widget _mealItem(String type, String menu, IconData icon, Color c, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: c.withOpacity(0.6), size: 16),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(menu, style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
