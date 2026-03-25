import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/preferences_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    bool isDark = themeNotifier.value == ThemeMode.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('CONTROL CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlow(isDark),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FadeInDown(child: _buildSectionHeader('SYSTEM_CORE')),
              const SizedBox(height: 16),
              _buildSettinsCard(
                title: 'Thermal Vision (Dark Mode)',
                subtitle: 'Toggle high-contrast display protocols',
                icon: Icons.nightlight_round,
                color: Colors.indigoAccent,
                trailing: Switch(
                  value: isDark,
                  activeColor: Colors.indigoAccent,
                  onChanged: (val) async {
                    await PreferencesService().setTheme(val);
                    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildSettinsCard(
                title: 'Tactical Alerts',
                subtitle: 'Real-time notification deployment',
                icon: Icons.notifications_active_rounded,
                color: Colors.orangeAccent,
                trailing: Switch(
                  value: _notifications,
                  activeColor: Colors.orangeAccent,
                  onChanged: (val) => setState(() => _notifications = val),
                ),
              ),
              const SizedBox(height: 32),
              FadeInUp(child: _buildSectionHeader('SECURITY_ACCESS')),
              const SizedBox(height: 16),
              _buildSettinsCard(
                title: 'Identity Dossier',
                subtitle: 'Modify personnel information',
                icon: Icons.face_retouching_natural_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.pushNamed(context, '/edit_profile'),
              ),
              const SizedBox(height: 12),
              _buildSettinsCard(
                title: 'Authorization Protocols',
                subtitle: 'Password and access management',
                icon: Icons.security_rounded,
                color: Colors.greenAccent,
                onTap: () {},
              ),
              const SizedBox(height: 32),
              FadeInUp(child: _buildSectionHeader('MAINTENANCE')),
              const SizedBox(height: 16),
              _buildSettinsCard(
                title: 'Cache Disposal',
                subtitle: 'Neutralize temporary system data',
                icon: Icons.cleaning_services_rounded,
                color: Colors.redAccent,
                onTap: () {},
              ),
              const SizedBox(height: 48),
              Center(child: Text('VER_1.8.5_BETA // STABLE_CHANNEL', style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black12, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow(bool isDark) {
    return Positioned(top: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: (isDark ? Colors.indigoAccent : Colors.blueAccent).withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.5));
  }

  Widget _buildSettinsCard({required String title, required String subtitle, required IconData icon, required Color color, Widget? trailing, VoidCallback? onTap}) {
    bool isDark = themeNotifier.value == ThemeMode.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
            ])),
            trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white12 : Colors.black12),
          ],
        ),
      ),
    );
  }
}
