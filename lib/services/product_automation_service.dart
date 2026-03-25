import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductAutomationService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product/';

  static Future<Map<String, dynamic>?> fetchProductMetadata(String barcode) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl$barcode.json'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final p = data['product'];
          return {
            'name': p['product_name'] ?? 'Unknown Product',
            'brand': p['brands'] ?? 'Various',
            'image_url': p['image_url'] ?? p['image_front_url'] ?? '',
            'barcode': barcode,
            'category': _suggestCategory(p['categories'] ?? ''),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _suggestCategory(String categories) {
    final c = categories.toLowerCase();
    if (c.contains('drink') || c.contains('beverage')) return 'Beverages';
    if (c.contains('snack') || c.contains('sweet')) return 'Snacks';
    if (c.contains('dairy') || c.contains('milk')) return 'Dairy';
    if (c.contains('cereal')) return 'Breakfast';
    return 'General';
  }
}
