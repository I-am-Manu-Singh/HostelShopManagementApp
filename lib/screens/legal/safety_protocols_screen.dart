import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class SafetyProtocolsScreen extends StatelessWidget {
  const SafetyProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SAFETY PROTOCOLS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text('CAMPUS RESIDENCE SAFETY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: const Text('Last revised: March 2026', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 60, thickness: 1),
            
            _buildSection(context, 'I. BIOMETRIC & FACE IDENTIFICATION', 'Access to hostel blocks and mess units is secured via mandatory face enrollment and gate biometric scans. Sharing credentials or tailgating is strictly prohibited.'),
            _buildSection(context, 'II. NIGHT OUTPASS REGISTRATION', 'Any resident leaving the hostel campus after curfew hours must submit an online outpass request for warden approval. Unapproved absences will trigger emergency notifications.'),
            _buildSection(context, 'III. INVENTORY SAFE KEEPING', 'Room inspections are conducted periodically. Possession of unauthorized electrical appliances or hazards will lead to immediate confiscation.'),
            _buildSection(context, 'IV. EMERGENCY ALERTS', 'In the event of a medical emergency or security concern, residents can trigger the Emergency Alert button inside the Student App to notify security guards en-route.'),
            
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.2))),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                  SizedBox(width: 20),
                  Expanded(child: Text('SAFETY RULES ARE STRICTLY ENFORCED. Violations of code of conduct will result in disciplinary action.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent))),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(content, style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7), height: 1.5)),
          ],
        ),
      ),
    );
  }
}
