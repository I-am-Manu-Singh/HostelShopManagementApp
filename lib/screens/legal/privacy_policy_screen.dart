import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('PRIVACY POLICY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRIVACY STATEMENT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            const Text('Last updated: March 2026', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
            const Divider(height: 40, thickness: 1),
            
            _buildSection(textColor, '1. Introduction', 'We are committed to protecting your privacy. This policy explains how we collect, use, and store information when you use our Hostel & Mandi Shop Management application.'),
            _buildSection(textColor, '2. Information We Collect', 'We collect account details (name, email, phone number, and campus role) to authenticate logins and process store purchases. For Mandi operations, delivery address or location coordinates are collected to enable orders dispatch.'),
            _buildSection(textColor, '3. Data Usage', 'Your information is used strictly to facilitate order bookings, coordinate deliveries, manage hostel rooms, and notify you about relevant campus announcements. We do not sell your personal data.'),
            _buildSection(textColor, '4. Security', 'We use industry-standard security measures and secure database channels to ensure your personal details, order receipts, and transactions remain protected from unauthorized access.'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(Color color, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}
