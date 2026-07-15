import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('TERMS OF SERVICE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
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
            Text('TERMS & CONDITIONS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            const Text('Last updated: March 2026', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
            const Divider(height: 40, thickness: 1),
            
            _buildSection(textColor, '1. Terms Acceptance', 'By downloading, accessing, or using the Hostel & Mandi Shop Management application, you agree to be bound by these Terms of Service. If you disagree with any terms, please do not use the app.'),
            _buildSection(textColor, '2. User Accounts', 'You are responsible for maintaining the confidentiality of your account login credentials. Any activity performed through your account is your sole responsibility.'),
            _buildSection(textColor, '3. Service Use Rules', 'Users must provide accurate details (including roles and contact details). Any misuse of shop checkouts, fake order placements, or fraudulent payment receipt uploads may result in immediate suspension.'),
            _buildSection(textColor, '4. Service Availability', 'While we strive to provide uninterrupted service, we reserve the right to suspend or modify features for maintenance or updates without prior notice.'),
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
