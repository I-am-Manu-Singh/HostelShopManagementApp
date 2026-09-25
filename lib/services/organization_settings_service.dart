import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service to fetch and cache organization, store, and contact settings from Supabase
class OrganizationSettingsService {
  static final OrganizationSettingsService _instance = OrganizationSettingsService._internal();
  factory OrganizationSettingsService() => _instance;
  OrganizationSettingsService._internal();

  final _supabase = Supabase.instance.client;

  // Cached dynamic organization & store details
  String companyName = 'H House';
  String companyPhone = '+91 79762 87989';
  String supportEmail = 'support@campusconnect.com';
  String website = 'https://hostelconnect.edu.in';
  String companyAddress = 'Campus Central Avenue, Tech Zone Block 4, Mohali – 160071';
  String storeGstin = '03ABCDE1234F1Z8';
  String merchantName = 'Hostel SuperMart & POS';
  String merchantUpiVpa = 'campusshop@upi';
  String receiptFooterNote = 'Thank you for shopping with us!\nVisit again.';
  double deliveryCharge = 20.0;
  List<Map<String, dynamic>> logisticsRules = [];

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// Loads settings from Supabase public.app_settings
  Future<void> fetchSettings({bool forceRefresh = false}) async {
    if (_hasLoaded && !forceRefresh) return;
    try {
      final res = await _supabase.from('app_settings').select('key, value');
      for (var row in res) {
        final k = row['key']?.toString() ?? '';
        final v = row['value'];
        if (v == null) continue;

        switch (k) {
          case 'company_name':
            companyName = v.toString();
            break;
          case 'company_phone':
          case 'store_phone':
            companyPhone = v.toString();
            break;
          case 'support_email':
            supportEmail = v.toString();
            break;
          case 'website':
            website = v.toString();
            break;
          case 'company_address':
          case 'store_address':
            companyAddress = v.toString();
            break;
          case 'store_gstin':
            storeGstin = v.toString();
            break;
          case 'merchant_name':
            merchantName = v.toString();
            break;
          case 'merchant_upi_vpa':
            merchantUpiVpa = v.toString();
            break;
          case 'receipt_footer_note':
            receiptFooterNote = v.toString();
            break;
          case 'delivery_charge':
            deliveryCharge = double.tryParse(v.toString()) ?? 20.0;
            break;
          case 'logistics_rules':
            if (v is List) {
              logisticsRules = List<Map<String, dynamic>>.from(v);
            } else if (v is String) {
              try {
                final decoded = jsonDecode(v);
                if (decoded is List) {
                  logisticsRules = List<Map<String, dynamic>>.from(decoded);
                }
              } catch (_) {}
            }
            break;
        }
      }
      _hasLoaded = true;
    } catch (e) {
      debugPrint('OrganizationSettingsService fetch error: $e');
    }
  }

  /// Parses logistics rules flexibly whether stored as JSON string, jsonb, or raw list
  static List<Map<String, dynamic>> parseRules(dynamic rawValue) {
    if (rawValue == null) return [];
    if (rawValue is List) {
      return List<Map<String, dynamic>>.from(rawValue);
    }
    if (rawValue is String) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      } catch (_) {}
    }
    return [];
  }
}
