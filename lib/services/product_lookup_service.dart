import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop.dart';

/// Scraped / Resolved Product Metadata from Indian & Global Open Barcode Registries.
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

  /// Whether the product is non-vegetarian.
  ///
  /// Defaults to false because most retail/FMCG products are vegetarian
  /// unless explicitly identified otherwise.
  final bool isNonVeg;

  /// Possible values:
  /// - open_food_facts
  /// - upc_item_db
  /// - supabase_db
  /// - manual
  /// - unmapped
  /// - none
  final String source;

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
    this.isNonVeg = false,
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
      'is_non_veg': isNonVeg,
      'source': source,
    };
  }
}

class ProductLookupService {
  static final ProductLookupService _instance =
      ProductLookupService._internal();

  factory ProductLookupService() => _instance;

  ProductLookupService._internal();

  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // TIER 1: LOCAL SUPABASE DATABASE
  // ---------------------------------------------------------------------------

  /// Searches the local shop_items table.
  ///
  /// Checks:
  /// - barcode
  /// - sku_qr
  /// - id
  ///
  /// Returns the existing ShopItem if found.
  Future<ShopItem?> lookupInLocalDatabase(String barcode) async {
    try {
      final clean = barcode.trim();

      if (clean.isEmpty) {
        return null;
      }

      final res = await _supabase
          .from('shop_items')
          .select()
          .or(
            'barcode.eq.$clean,sku_qr.eq.$clean,id.eq.$clean',
          )
          .maybeSingle();

      if (res != null) {
        return ShopItem.fromJson(res);
      }
    } catch (e) {
      debugPrint('Local DB Barcode lookup error: $e');
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // TIER 2: OPEN FOOD FACTS
  // ---------------------------------------------------------------------------

  /// Open Food Facts API.
  ///
  /// Useful for:
  /// - Indian FMCG
  /// - Groceries
  /// - Snacks
  /// - Dairy
  /// - Beverages
  /// - Packaged foods
  Future<BarcodeProductLookupResult?> lookupOpenFoodFacts(
    String barcode,
  ) async {
    try {
      final clean = barcode.trim();

      if (clean.isEmpty) {
        return null;
      }

      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$clean.json',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'HostelShopManagementApp/1.0 (contact@campusconnect.local)',
        },
      ).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 1 || data['product'] == null) {
        return null;
      }

      final p = data['product'];

      final productName =
          p['product_name'] ??
          p['product_name_en'] ??
          p['generic_name'];

      if (productName == null ||
          productName.toString().trim().isEmpty) {
        return null;
      }

      // -----------------------------------------------------------------------
      // ALLERGENS
      // -----------------------------------------------------------------------

      List<String>? allergens;

      if (p['allergens_tags'] is List &&
          (p['allergens_tags'] as List).isNotEmpty) {
        allergens = (p['allergens_tags'] as List)
            .map(
              (e) => e
                  .toString()
                  .replaceFirst(
                    RegExp(r'^[a-z]{2}:'),
                    '',
                  )
                  .trim(),
            )
            .where(
              (e) => e.isNotEmpty,
            )
            .toList();
      }

      // -----------------------------------------------------------------------
      // NUTRITION
      // -----------------------------------------------------------------------

      final Map<String, dynamic> nutrimentsMap = {};

      final nutriments = p['nutriments'];

      if (nutriments is Map) {
        final energy =
            nutriments['energy-kcal_100g'] ??
            nutriments['energy-kcal_serving'] ??
            nutriments['energy-kcal'] ??
            nutriments['energy_100g'];

        if (energy != null) {
          nutrimentsMap['Calories'] = '${energy.toString()} kcal';
        }

        final protein =
            nutriments['proteins_100g'] ??
            nutriments['proteins_serving'];

        if (protein != null) {
          nutrimentsMap['Protein'] = '${protein.toString()} g';
        }

        final carbs =
            nutriments['carbohydrates_100g'] ??
            nutriments['carbohydrates_serving'];

        if (carbs != null) {
          nutrimentsMap['Carbohydrates'] = '${carbs.toString()} g';
        }

        final fat =
            nutriments['fat_100g'] ??
            nutriments['fat_serving'];

        if (fat != null) {
          nutrimentsMap['Fat'] = '${fat.toString()} g';
        }

        final sugars =
            nutriments['sugars_100g'] ??
            nutriments['sugars_serving'];

        if (sugars != null) {
          nutrimentsMap['Sugar'] = '${sugars.toString()} g';
        }

        final sodium =
            nutriments['sodium_100g'] ??
            nutriments['sodium_serving'];

        if (sodium != null) {
          nutrimentsMap['Sodium'] = '${sodium.toString()} mg';
        }

        final fiber =
            nutriments['fiber_100g'] ??
            nutriments['fiber_serving'];

        if (fiber != null) {
          nutrimentsMap['Fiber'] = '${fiber.toString()} g';
        }
      }

      // -----------------------------------------------------------------------
      // PACKAGE TYPE
      // -----------------------------------------------------------------------

      String? packageType =
          p['packaging_text']?.toString();

      if (packageType == null ||
          packageType.trim().isEmpty) {
        final rawPack =
            p['packaging']?.toString() ?? '';

        final lowerPack = rawPack.toLowerCase();

        if (lowerPack.contains('bottle')) {
          packageType = 'Bottle';
        } else if (lowerPack.contains('can')) {
          packageType = 'Can';
        } else if (lowerPack.contains('box')) {
          packageType = 'Box';
        } else if (lowerPack.contains('packet') ||
            lowerPack.contains('pouch') ||
            lowerPack.contains('sachet')) {
          packageType = 'Packet';
        }
      }

      // -----------------------------------------------------------------------
      // IMAGES
      // -----------------------------------------------------------------------

      final List<String> gatheredImages = [];

      void addImage(dynamic value) {
        if (value == null) return;

        final image = value.toString().trim();

        if (image.isEmpty) return;

        if (!gatheredImages.contains(image)) {
          gatheredImages.add(image);
        }
      }

      addImage(p['image_front_url']);
      addImage(p['image_ingredients_url']);
      addImage(p['image_nutrition_url']);
      addImage(p['image_url']);

      final primaryImage =
          gatheredImages.isNotEmpty
              ? gatheredImages.first
              : null;

      final imageString =
          gatheredImages.isNotEmpty
              ? gatheredImages.join(',')
              : null;

      // -----------------------------------------------------------------------
      // VEG / NON-VEG
      // -----------------------------------------------------------------------

      final isNonVeg = _detectNonVegFromOpenFoodFacts(p);

      return BarcodeProductLookupResult(
        found: true,
        barcode: clean,
        name: productName.toString().trim(),
        brand: _firstBrand(p['brands']),
        category: _normalizeCategory(
          p['categories']?.toString(),
        ),
        quantity: p['quantity']?.toString(),
        imageUrl: imageString ?? primaryImage,
        description:
            p['generic_name']?.toString() ??
            p['categories']?.toString(),
        ingredients: p['ingredients_text']?.toString(),
        servingSize: p['serving_size']?.toString(),
        allergens: allergens,
        nutriscore:
            p['nutriscore_grade']
                ?.toString()
                .toUpperCase(),
        packageType: packageType,
        nutritionalInfo:
            nutrimentsMap.isNotEmpty
                ? nutrimentsMap
                : null,
        images:
            gatheredImages.isNotEmpty
                ? gatheredImages
                : null,
        isNonVeg: isNonVeg,
        source: 'open_food_facts',
      );
    } catch (e) {
      debugPrint(
        'Open Food Facts lookup error: $e',
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // TIER 3: UPC ITEM DB
  // ---------------------------------------------------------------------------

  /// UPCitemdb lookup.
  ///
  /// Useful for general consumer/retail products.
  Future<BarcodeProductLookupResult?> lookupUpcItemDb(
    String barcode,
  ) async {
    try {
      final clean = barcode.trim();

      if (clean.isEmpty) {
        return null;
      }

      final url = Uri.parse(
        'https://api.upcitemdb.com/prod/trial/lookup?upc=$clean',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data['total'] == null ||
          data['total'] <= 0 ||
          data['items'] == null ||
          (data['items'] as List).isEmpty) {
        return null;
      }

      final item = data['items'][0];

      final title = item['title']?.toString();

      if (title == null || title.trim().isEmpty) {
        return null;
      }

      final images = item['images'] as List?;

      final List<String> upcImages =
          images != null
              ? images
                  .map(
                    (e) => e.toString(),
                  )
                  .where(
                    (e) => e.trim().isNotEmpty,
                  )
                  .toList()
              : [];

      final sizeWeight =
          item['size']?.toString() ??
          item['weight']?.toString();

      return BarcodeProductLookupResult(
        found: true,
        barcode: clean,
        name: title.trim(),
        brand: item['brand']?.toString(),
        category: _normalizeCategory(
          item['category']?.toString(),
        ),
        quantity: sizeWeight,
        imageUrl:
            upcImages.isNotEmpty
                ? upcImages.join(',')
                : null,
        images:
            upcImages.isNotEmpty
                ? upcImages
                : null,
        description:
            item['description']?.toString(),
        packageType:
            item['model'] != null
                ? 'Item'
                : null,
        isNonVeg: _detectNonVegFromText(
          title,
          item['description']?.toString(),
        ),
        source: 'upc_item_db',
      );
    } catch (e) {
      debugPrint(
        'UPCitemdb lookup error: $e',
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // UNIFIED LOOKUP PIPELINE
  // ---------------------------------------------------------------------------

  /// Unified High-Performance Hybrid Lookup Pipeline:
  ///
  /// 1. Local Supabase Database
  /// 2. Open Food Facts
  /// 3. UPCitemdb
  /// 4. Manual registration
  Future<BarcodeProductLookupResult> fetchProductDetailsOnline(
    String barcode,
  ) async {
    final clean = barcode.trim();

    if (clean.isEmpty) {
      return BarcodeProductLookupResult(
        found: false,
        barcode: clean,
        source: 'none',
      );
    }

    // -------------------------------------------------------------------------
    // 1. LOCAL SUPABASE
    // -------------------------------------------------------------------------

    final localProduct =
        await lookupInLocalDatabase(clean);

    if (localProduct != null) {
      return BarcodeProductLookupResult(
        found: true,
        barcode: clean,
        name: localProduct.name,
        brand: localProduct.brand,
        category: localProduct.category,
        quantity: localProduct.weightMl,
        imageUrl: localProduct.imageUrl,
        description: localProduct.description,
        ingredients: localProduct.ingredients,
        packageType: localProduct.packageType,
        nutritionalInfo:
            localProduct.nutritionalInfo,
        isNonVeg: localProduct.isNonVeg,
        source: 'supabase_db',
      );
    }

    // -------------------------------------------------------------------------
    // 2. OPEN FOOD FACTS
    // -------------------------------------------------------------------------

    final offResult =
        await lookupOpenFoodFacts(clean);

    if (offResult != null && offResult.found) {
      return offResult;
    }

    // -------------------------------------------------------------------------
    // 3. UPC ITEM DB
    // -------------------------------------------------------------------------

    final upcResult =
        await lookupUpcItemDb(clean);

    if (upcResult != null && upcResult.found) {
      return upcResult;
    }

    // -------------------------------------------------------------------------
    // 4. NOT FOUND
    // -------------------------------------------------------------------------

    return BarcodeProductLookupResult(
      found: false,
      barcode: clean,
      source: 'unmapped',
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTER PRODUCT
  // ---------------------------------------------------------------------------

  /// Save a new discovered/manual item to shop_items.
  ///
  /// The isNonVeg field is persisted to the database as is_non_veg.
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

    /// Whether this product is non-vegetarian.
    bool isNonVeg = false,
  }) async {
    try {
      final cleanBarcode = barcode.trim();

      if (name.trim().isEmpty ||
          cleanBarcode.isEmpty) {
        return null;
      }

      final payload = {
        'name': name.trim(),
        'barcode': cleanBarcode,
        'sku_qr': cleanBarcode,

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

        // IMPORTANT:
        // Dart: isNonVeg
        // Supabase: is_non_veg
        'is_non_veg': isNonVeg,

        'is_mandi': false,
        'unit': 'pcs',
      };

      final res = await _supabase
          .from('shop_items')
          .insert(payload)
          .select()
          .single();

      return ShopItem.fromJson(res);
    } catch (e) {
      debugPrint(
        'Error inserting new product into database: $e',
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Extracts the first brand when Open Food Facts returns:
  ///
  /// "Amul, GCMMF"
  ///
  /// -> "Amul"
  String? _firstBrand(dynamic rawBrand) {
    if (rawBrand == null) {
      return null;
    }

    final value = rawBrand.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value
        .split(',')
        .first
        .trim();
  }

  /// Attempts to determine whether Open Food Facts identifies
  /// the product as non-vegetarian.
  ///
  /// Explicit OFF tags are preferred.
  bool _detectNonVegFromOpenFoodFacts(
    dynamic product,
  ) {
    if (product is! Map) {
      return false;
    }

    // -------------------------------------------------------------------------
    // Explicit vegetarian / non-vegetarian tags
    // -------------------------------------------------------------------------

    final List<String> tags = [];

    void collectTags(dynamic value) {
      if (value is List) {
        for (final item in value) {
          final value = item.toString().toLowerCase().trim();

          if (value.isNotEmpty) {
            tags.add(value);
          }
        }
      }
    }

    collectTags(product['ingredients_analysis_tags']);
    collectTags(product['labels_tags']);
    collectTags(product['categories_tags']);

    for (final tag in tags) {
      if (tag.contains('non-vegetarian') ||
          tag.contains('non_vegetarian') ||
          tag.contains('nonvegetarian') ||
          tag.contains('contains-meat') ||
          tag.contains('contains_fish') ||
          tag.contains('contains-fish') ||
          tag.contains('contains_chicken') ||
          tag.contains('contains-chicken') ||
          tag.contains('contains-pork') ||
          tag.contains('contains-beef') ||
          tag.contains('contains-eggs')) {
        return true;
      }
    }

    // -------------------------------------------------------------------------
    // Ingredients / product text fallback
    // -------------------------------------------------------------------------

    final name =
        product['product_name']?.toString();

    final genericName =
        product['generic_name']?.toString();

    final ingredients =
        product['ingredients_text']?.toString();

    return _detectNonVegFromText(
      name,
      '$genericName $ingredients',
    );
  }

  /// Conservative text-based non-veg detection.
  ///
  /// This intentionally does NOT classify words such as "milk", "cheese",
  /// "butter", etc. as non-veg.
  bool _detectNonVegFromText(
    String? name,
    String? description,
  ) {
    final text =
        '${name ?? ''} ${description ?? ''}'
            .toLowerCase();

    if (text.trim().isEmpty) {
      return false;
    }

    const nonVegKeywords = [
      'chicken',
      'mutton',
      'lamb',
      'goat meat',
      'beef',
      'pork',
      'fish',
      'seafood',
      'prawn',
      'prawns',
      'shrimp',
      'crab',
      'tuna',
      'salmon',
      'anchovy',
      'sardine',
      'meat',
      'bacon',
      'ham',
      'sausage',
      'pepperoni',
      'salami',
      'egg',
      'eggs',
      'gelatin',
      'gelatine',
      'chicken sausage',
      'chicken salami',
      'chicken ham',
    ];

    for (final keyword in nonVegKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // CATEGORY NORMALIZATION
  // ---------------------------------------------------------------------------

  String _normalizeCategory(String? raw) {
    if (raw == null ||
        raw.trim().isEmpty) {
      return 'Groceries';
    }

    final lower = raw.toLowerCase();

    if (lower.contains('beverage') ||
        lower.contains('drink') ||
        lower.contains('tea') ||
        lower.contains('coffee') ||
        lower.contains('juice')) {
      return 'Beverages';
    }

    if (lower.contains('snack') ||
        lower.contains('biscuit') ||
        lower.contains('chip') ||
        lower.contains('cookie') ||
        lower.contains('namkeen')) {
      return 'Snacks';
    }

    if (lower.contains('dairy') ||
        lower.contains('milk') ||
        lower.contains('cheese') ||
        lower.contains('paneer') ||
        lower.contains('butter')) {
      return 'Dairy';
    }

    if (lower.contains('fruit') ||
        lower.contains('vegetable') ||
        lower.contains('produce') ||
        lower.contains('mandi')) {
      return 'Mandi';
    }

    if (lower.contains('stationery') ||
        lower.contains('pen') ||
        lower.contains('notebook') ||
        lower.contains('book')) {
      return 'Stationery';
    }

    return 'Grocery';
  }
}