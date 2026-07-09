import 'package:flutter/material.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Refund Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refund Policy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            const Text('Last updated: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 40, thickness: 1),
            
            _buildSection(textColor, '1. Shop Orders', 'Orders placed through the shop can be cancelled within 15 minutes of purchase for a full refund to your in-app wallet. Once items are packed or dispatched, refunds are not permitted.'),
            _buildSection(textColor, '2. Mandi and Fresh Produce', 'Due to the perishable nature of fresh fruits, vegetables, and dairy products, refunds or replacements are only issued if items are damaged or spoiled at the time of delivery. Claims must be submitted within 2 hours of receipt.'),
            _buildSection(textColor, '3. Hostel Rent & Fees', 'Room rent and mess fee cancellations are subject to administrative review. Refunds for cancellations requested before the month starts will be credited back minus processing fees.'),
            _buildSection(textColor, '4. Refund Processing', 'Approved refunds are credited directly to the user\'s in-app wallet instantly, or processed back to the source bank account within 5-7 business days.'),
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
