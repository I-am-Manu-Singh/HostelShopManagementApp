import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';

/// Scraped / Resolved Product Metadata from Indian & Global Open Barcode Registries
class BarcodeProductLookupResult {
  final bool found;
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? quantity;
  final String? imageUrl;
  final String? description;
  final String? ingredients;
  final String? servingSize;
  final List<String>? allergens;
  final String? nutriscore;
  final String? packageType;
  final Map<String, dynamic>? nutritionalInfo;
  final List<String>? images;
  final String source; // 'open_food_facts', 'upc_item_db', 'supabase_db', 'manual'

  BarcodeProductLookupResult({
    required this.found,
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.quantity,
    this.imageUrl,
    this.description,
    this.ingredients,
    this.servingSize,
    this.allergens,
    this.nutriscore,
    this.packageType,
    this.nutritionalInfo,
    this.images,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'weight_ml': quantity ?? servingSize,
      'package_type': packageType,
      'image_url': imageUrl,
      'description': description,
      'ingredients': ingredients,
      'nutritional_info': nutritionalInfo,
      'source': source,
    };
  }
}

class ProductLookupService {
  static final ProductLookupService _instance = ProductLookupService._internal();
  factory ProductLookupService() => _instance;
  ProductLookupService._internal();

  final _supabase = Supabase.instance.client;

  /// Tier 1: Local Supabase Database Check (shop_items)
  /// Returns ShopItem if previously scanned or registered.
  Future<ShopItem?> lookupInLocalDatabase(String barcode) async {
    try {
      final clean = barcode.trim();
      final res = await _supabase.from('shop_items').select().or('barcode.eq.$clean,sku_qr.eq.$clean,id.eq.$clean').maybeSingle();
      if (res != null) {
        return ShopItem.fromJson(res);
      }
    } catch (e) {
      debugPrint('Local DB Barcode lookup error: $e');
    }
    return null;
  }

  /// Tier 2: Open Food Facts API (India & Global FMCG, Kirana, Snacks, Dairy, Maggi, Amul)
  /// Open & free REST JSON API: https://world.openfoodfacts.org/api/v2/product/{barcode}.json
  Future<BarcodeProductLookupResult?> lookupOpenFoodFacts(String barcode) async {
    try {
      final clean = barcode.trim();
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$clean.json');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'HostelShopManagementApp/1.0 (contact@campusconnect.local)',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          final productName = p['product_name'] ?? p['product_name_en'] ?? p['generic_name'];
          if (productName != null && productName.toString().trim().isNotEmpty) {
            // Extract allergens cleanly (remove 'en:' prefix)
            List<String>? allergens;
            if (p['allergens_tags'] != null && (p['allergens_tags'] as List).isNotEmpty) {
              allergens = (p['allergens_tags'] as List)
                  .map((e) => e.toString().replaceFirst(RegExp(r'^[a-z]{2}:'), '').trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }

            // Extract nutritional facts per 100g / per serving
            final Map<String, dynamic> nutrimentsMap = {};
            final nutriments = p['nutriments'];
            if (nutriments is Map) {
              final energy = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal_serving'] ?? nutriments['energy-kcal'] ?? nutriments['energy_100g'];
              if (energy != null) nutrimentsMap['Calories'] = '${energy.toString()} kcal';

              final protein = nutriments['proteins_100g'] ?? nutriments['proteins_serving'];
              if (protein != null) nutrimentsMap['Protein'] = '${protein.toString()} g';

              final carbs = nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates_serving'];
              if (carbs != null) nutrimentsMap['Carbohydrates'] = '${carbs.toString()} g';

              final fat = nutriments['fat_100g'] ?? nutriments['fat_serving'];
              if (fat != null) nutrimentsMap['Fat'] = '${fat.toString()} g';

              final sugars = nutriments['sugars_100g'] ?? nutriments['sugars_serving'];
              if (sugars != null) nutrimentsMap['Sugar'] = '${sugars.toString()} g';

              final sodium = nutriments['sodium_100g'] ?? nutriments['sodium_serving'];
              if (sodium != null) nutrimentsMap['Sodium'] = '${sodium.toString()} mg';

              final fiber = nutriments['fiber_100g'] ?? nutriments['fiber_serving'];
              if (fiber != null) nutrimentsMap['Fiber'] = '${fiber.toString()} g';
            }

            // Determine package type
            String? packageType = p['packaging_text']?.toString();
            if (packageType == null || packageType.trim().isEmpty) {
              final rawPack = p['packaging']?.toString() ?? '';
              if (rawPack.toLowerCase().contains('bottle')) {
                packageType = 'Bottle';
              } else if (rawPack.toLowerCase().contains('can')) {
                packageType = 'Can';
              } else if (rawPack.toLowerCase().contains('box')) {
                packageType = 'Box';
              } else if (rawPack.toLowerCase().contains('packet') || rawPack.toLowerCase().contains('pouch') || rawPack.toLowerCase().contains('sachet')) {
                packageType = 'Packet';
              }
            }

            // Collect multiple product images if available
            final List<String> gatheredImages = [];
            if (p['image_front_url'] != null) gatheredImages.add(p['image_front_url'].toString());
            if (p['image_ingredients_url'] != null) gatheredImages.add(p['image_ingredients_url'].toString());
            if (p['image_nutrition_url'] != null) gatheredImages.add(p['image_nutrition_url'].toString());
            if (p['image_url'] != null && !gatheredImages.contains(p['image_url'].toString())) {
              gatheredImages.add(p['image_url'].toString());
            }

            final primaryImage = gatheredImages.isNotEmpty ? gatheredImages.first : null;
            final imageString = gatheredImages.isNotEmpty ? gatheredImages.join(',') : null;

            return BarcodeProductLookupResult(
              found: true,
              barcode: clean,
              name: productName.toString().trim(),
              brand: p['brands']?.toString().split(',').first.trim(),
              category: _normalizeCategory(p['categories']?.toString()),
              quantity: p['quantity']?.toString(),
              imageUrl: imageString ?? primaryImage,
              description: p['generic_name']?.toString() ?? p['categories']?.toString(),
              ingredients: p['ingredients_text']?.toString(),
              servingSize: p['serving_size']?.toString(),
              allergens: allergens,
              nutriscore: p['nutriscore_grade']?.toString().toUpperCase(),
              packageType: packageType,
              nutritionalInfo: nutrimentsMap.isNotEmpty ? nutrimentsMap : null,
              images: gatheredImages.isNotEmpty ? gatheredImages : null,
              source: 'open_food_facts',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Open Food Facts lookup error: $e');
    }
    return null;
  }

  /// Tier 3: UPCitemdb (Free Tier: 100 queries/day for general retail, soaps, cosmetics, electronics)
  Future<BarcodeProductLookupResult?> lookupUpcItemDb(String barcode) async {
    try {
      final clean = barcode.trim();
      final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$clean');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['total'] != null && data['total'] > 0 && data['items'] != null && (data['items'] as List).isNotEmpty) {
          final item = data['items'][0];
          final title = item['title']?.toString();
          if (title != null && title.isNotEmpty) {
            final images = item['images'] as List?;
            final List<String> upcImages = images != null ? images.map((e) => e.toString()).toList() : [];
            final sizeWeight = item['size']?.toString() ?? item['weight']?.toString();
            return BarcodeProductLookupResult(
              found: true,
              barcode: clean,
              name: title,
              brand: item['brand']?.toString(),
              category: _normalizeCategory(item['category']?.toString()),
              quantity: sizeWeight,
              imageUrl: upcImages.isNotEmpty ? upcImages.join(',') : null,
              images: upcImages.isNotEmpty ? upcImages : null,
              description: item['description']?.toString(),
              packageType: item['model'] != null ? 'Item' : null,
              source: 'upc_item_db',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('UPCitemdb lookup error: $e');
    }
    return null;
  }

  /// Unified High-Performance Hybrid Lookup Pipeline:
  /// 1. Local Database (Instant <10ms)
  /// 2. Open Food Facts (Free Indian FMCG / Groceries)
  /// 3. UPCitemdb (General Consumer items)
  /// 4. If not found, returns found: false -> triggers In-House Manual Entry / Loose Kirana creation
  Future<BarcodeProductLookupResult> fetchProductDetailsOnline(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) {
      return BarcodeProductLookupResult(found: false, barcode: clean, source: 'none');
    }

    // 1. Try Open Food Facts
    final offResult = await lookupOpenFoodFacts(clean);
    if (offResult != null && offResult.found) {
      return offResult;
    }

    // 2. Try UPCitemdb
    final upcResult = await lookupUpcItemDb(clean);
    if (upcResult != null && upcResult.found) {
      return upcResult;
    }

    // 3. Not found anywhere -> prompt manual registration
    return BarcodeProductLookupResult(
      found: false,
      barcode: clean,
      source: 'unmapped',
    );
  }

  /// Save new discovered/manual item to `shop_items` table so it persists in the database permanently
  Future<ShopItem?> registerProductInDatabase({
    required String name,
    required String barcode,
    required double price,
    double? costPrice,
    int stockQuantity = 50,
    String category = 'Groceries',
    String? brand,
    String? weightMl,
    String? imageUrl,
    String? description,
    String? hsnCode,
    String? packageType,
    String? ingredients,
    List<String>? tags,
    Map<String, dynamic>? nutritionalInfo,
    double taxRate = 5.0,
    bool isTaxInclusive = true,
  }) async {
    try {
      final payload = {
        'name': name.trim(),
        'barcode': barcode.trim(),
        'sku_qr': barcode.trim(),
        'price': price,
        'cost_price': costPrice,
        'stock_quantity': stockQuantity,
        'category': category.trim(),
        'brand': brand?.trim(),
        'weight_ml': weightMl?.trim(),
        'image_url': imageUrl?.trim(),
        'description': description?.trim(),
        'hsn_code': hsnCode?.trim(),
        'package_type': packageType?.trim(),
        'ingredients': ingredients?.trim(),
        'tags': tags,
        'nutritional_info': nutritionalInfo,
        'tax_rate': taxRate,
        'is_tax_inclusive': isTaxInclusive,
        'is_available': true,
        'is_mandi': false,
        'unit': 'pcs',
      };

      final res = await _supabase.from('shop_items').insert(payload).select().single();
      return ShopItem.fromJson(res);
    } catch (e) {
      debugPrint('Error inserting new product into database: $e');
      return null;
    }
  }

  String _normalizeCategory(String? raw) {
    if (raw == null || raw.isEmpty) return 'Groceries';
    final lower = raw.toLowerCase();
    if (lower.contains('beverage') || lower.contains('drink') || lower.contains('tea') || lower.contains('coffee') || lower.contains('juice')) {
      return 'Beverages';
    }
    if (lower.contains('snack') || lower.contains('biscuit') || lower.contains('chip') || lower.contains('cookie') || lower.contains('namkeen')) {
      return 'Snacks';
    }
    if (lower.contains('dairy') || lower.contains('milk') || lower.contains('cheese') || lower.contains('paneer') || lower.contains('butter')) {
      return 'Dairy';
    }
    if (lower.contains('fruit') || lower.contains('vegetable') || lower.contains('produce') || lower.contains('mandi')) {
      return 'Mandi';
    }
    if (lower.contains('stationery') || lower.contains('pen') || lower.contains('notebook') || lower.contains('book')) {
      return 'Stationery';
    }
    return 'Grocery';
  }
}
