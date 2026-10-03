import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/revenuecat_billing_service.dart';

class SubscriptionTiersDialog extends StatefulWidget {
  const SubscriptionTiersDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubscriptionTiersDialog(),
    );
  }

  @override
  State<SubscriptionTiersDialog> createState() => _SubscriptionTiersDialogState();
}

class _SubscriptionTiersDialogState extends State<SubscriptionTiersDialog> {
  final _billing = RevenueCatBillingService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = const Color(0xFFEAB308);
    final bgSurface = isDark ? const Color(0xFF131826) : Colors.white;

    return ValueListenableBuilder<AppTier>(
      valueListenable: _billing.currentTier,
      builder: (context, activeTier, _) {
        return Container(
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: goldColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'MEMBERSHIP & TIERS',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Powered by RevenueCat Enterprise Billing',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 20),

              // Tiers List
              _buildTierCard(
                title: 'Free Core',
                price: '₹0 / forever',
                features: ['Resident room view & mess menu', 'POS Billing up to 50 items/mo', 'Community chat access'],
                isSelected: activeTier == AppTier.free,
                isDark: isDark,
                accentColor: Colors.blueAccent,
                onSelect: null,
              ),
              const SizedBox(height: 12),
              _buildTierCard(
                title: 'Pro Command',
                price: '₹299 / month',
                features: ['Unlimited POS Barcode scanning', 'Automated Expense & Khata Ledger', 'Priority incident resolution tagging'],
                isSelected: activeTier == AppTier.pro,
                isDark: isDark,
                accentColor: goldColor,
                onSelect: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connecting to Google Play Billing...')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildTierCard(
                title: 'Enterprise Campus',
                price: '₹1,499 / month',
                features: ['Multi-Hostel & Campus fleet command', 'Biometric & Face Match Turnstile gate sync', 'Dedicated SLA & Data export'],
                isSelected: activeTier == AppTier.enterprise,
                isDark: isDark,
                accentColor: const Color(0xFF6366F1),
                onSelect: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connecting to Google Play Billing...')),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Restore Purchases
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _billing.restorePurchases();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Purchases restored successfully')),
                  );
                },
                child: Text(
                  'Restore Purchases',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTierCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
    required VoidCallback? onSelect,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? accentColor : (isDark ? Colors.white10 : Colors.black12),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  price,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 13, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('ACTIVE PLAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor)),
              ),
            ),
        ],
      ),
    );
  }
}
