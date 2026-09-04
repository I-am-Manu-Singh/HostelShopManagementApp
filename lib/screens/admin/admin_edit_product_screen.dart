import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/shop.dart';
import '../../services/product_lookup_service.dart';

class AdminEditProductScreen extends StatefulWidget {
  final ShopItem? product;
  final String? scannedSku;
  const AdminEditProductScreen({super.key, this.product, this.scannedSku});

  @override
  State<AdminEditProductScreen> createState() => _AdminEditProductScreenState();
}

class _AdminEditProductScreenState extends State<AdminEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _client = Supabase.instance.client;

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _discountPriceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late TextEditingController _brandController;
  late TextEditingController _weightController;
  late TextEditingController _shelfLifeController;
  late TextEditingController _tagsController;
  late TextEditingController _ingredientsController;
  late TextEditingController _usageController;
  late TextEditingController _imageUrlController;
  late TextEditingController _ratingController;
  late TextEditingController _reviewsController;
  late TextEditingController _unitController;
  // POS & Tax Controllers
  late TextEditingController _barcodeController;
  late TextEditingController _hsnController;
  late TextEditingController _taxRateController;
  late TextEditingController _costPriceController;
  late TextEditingController _minStockController;
  bool _isTaxInclusive = true;
  bool _isBestseller = false;
  bool _isMandi = false;
  String _packageType = 'Packet';
  bool _isLoading = false;
  bool _isUploadingImage = false;
  
  // 🛡️ DYNAMIC DATA LISTS
  final List<TextEditingController> _factLabelControllers = [];
  final List<TextEditingController> _factValueControllers = [];
  final List<String> _tags = [];
  final Set<String> _knownTags = {};
  final Set<String> _knownCategories = {};
  
  final List<String> _commonFacts = [
    'Energy', 'Calories', 'Total Fat', 'Saturated Fat', 'Trans Fat', 
    'Cholesterol', 'Sodium', 'Total Carbohydrates', 'Dietary Fiber', 
    'Sugars', 'Protein', 'Calcium', 'Iron', 'Potassium', 'Magnesium', 'Zinc',
    'Vitamin A', 'Vitamin B12', 'Vitamin C', 'Vitamin D', 'Vitamin E'
  ];

  @override
  void initState() {
    super.initState();
    _loadSyncMetadata();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _skuController = TextEditingController(text: p?.skuQr ?? widget.scannedSku);
    _categoryController = TextEditingController(text: p?.category);
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _discountPriceController = TextEditingController(text: p?.discountPrice?.toString() ?? '');
    _stockController = TextEditingController(text: p?.stockQuantity.toString() ?? '');
    _descriptionController = TextEditingController(text: p?.description);
    _brandController = TextEditingController(text: p?.brand);
    _weightController = TextEditingController(text: p?.weightMl);
    _shelfLifeController = TextEditingController(text: p?.shelfLife);
    _ingredientsController = TextEditingController(text: p?.ingredients);
    _usageController = TextEditingController(text: p?.howToUse);
    _imageUrlController = TextEditingController(text: p?.imageUrl);
    _ratingController = TextEditingController(text: p != null ? p.rating.toString() : '0.0');
    _reviewsController = TextEditingController(text: p != null ? p.totalReviews.toString() : '0');
    _isBestseller = p?.isBestseller ?? false;
    _packageType = p?.packageType ?? 'Packet';
    _unitController = TextEditingController(text: p?.unit ?? 'pcs');
    _isMandi = p?.isMandi ?? false;

    // POS & Tax fields
    _barcodeController = TextEditingController(text: p?.barcode ?? p?.skuQr);
    _hsnController = TextEditingController(text: p?.hsnCode ?? '');
    _taxRateController = TextEditingController(text: p != null ? p.taxRate.toString() : '5.0');
    _costPriceController = TextEditingController(text: p?.costPrice != null ? p!.costPrice.toString() : '');
    _minStockController = TextEditingController(text: p != null ? p.minStockAlert.toString() : '5');
    _isTaxInclusive = p?.isTaxInclusive ?? true;

    if (p?.tags != null) _tags.addAll(p!.tags!);

    // 🛡️ INITIALIZE NUTRITIONAL FACTS
    if (p?.nutritionalInfo != null && p!.nutritionalInfo!.isNotEmpty) {
      p.nutritionalInfo!.forEach((k, v) {
        _factLabelControllers.add(TextEditingController(text: k));
        _factValueControllers.add(TextEditingController(text: v.toString()));
      });
    } else {
      _addFactField();
    }

    // Auto-fetch if opened with a scanned SKU
    if (widget.product == null && widget.scannedSku != null && widget.scannedSku!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFetchForBarcode(widget.scannedSku!);
      });
    }
  }

  Future<void> _autoFetchForBarcode(String barcode) async {
    final result = await ProductLookupService().fetchProductDetailsOnline(barcode);
    if (mounted && result.found) {
      setState(() {
        if (_nameController.text.isEmpty && result.name != null) {
          _nameController.text = result.name!;
        }
        if (_brandController.text.isEmpty && result.brand != null) {
          _brandController.text = result.brand!;
        }
        if (_categoryController.text.isEmpty && result.category != null) {
          _categoryController.text = result.category!;
        }
        if (_weightController.text.isEmpty && (result.quantity != null || result.servingSize != null)) {
          _weightController.text = result.quantity ?? result.servingSize!;
        }
        if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
          if (_imageUrlController.text.isEmpty) {
            _imageUrlController.text = result.imageUrl!;
          } else {
            final existing = _currentImageUrls;
            final incoming = result.imageUrl!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
            for (final u in incoming) {
              if (!existing.contains(u)) existing.add(u);
            }
            _setImageUrls(existing);
          }
        }
        if (_descriptionController.text.isEmpty && result.description != null) {
          _descriptionController.text = result.description!;
        }
        if (_ingredientsController.text.isEmpty && result.ingredients != null) {
          _ingredientsController.text = result.ingredients!;
        }
        if (result.packageType != null) {
          _packageType = result.packageType!;
        }
        if (result.allergens != null && result.allergens!.isNotEmpty) {
          for (final allergen in result.allergens!) {
            final tagStr = 'Contains $allergen';
            if (!_tags.contains(tagStr)) {
              _tags.add(tagStr);
            }
          }
        }
        if (result.nutritionalInfo != null && result.nutritionalInfo!.isNotEmpty) {
          _factLabelControllers.clear();
          _factValueControllers.clear();
          result.nutritionalInfo!.forEach((k, v) {
            _factLabelControllers.add(TextEditingController(text: k));
            _factValueControllers.add(TextEditingController(text: v.toString()));
          });
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-resolved from ${result.source}: ${result.name}'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _loadSyncMetadata() async {
    try {
      final res = await _client.from('shop_items').select('category, tags');
      for (var row in res) {
         if (row['category'] != null) _knownCategories.add(row['category']);
         if (row['tags'] != null) {
            final t = row['tags'] as List;
            for (var tag in t) _knownTags.add(tag.toString());
         }
      }
      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _addFactField() {
    setState(() {
      _factLabelControllers.add(TextEditingController());
      _factValueControllers.add(TextEditingController());
    });
  }

  void _removeFactField(int index) {
    setState(() {
      _factLabelControllers.removeAt(index);
      _factValueControllers.removeAt(index);
    });
  }

  List<String> get _currentImageUrls {
    final raw = _imageUrlController.text.trim();
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _setImageUrls(List<String> urls) {
    setState(() {
      _imageUrlController.text = urls.join(', ');
    });
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(imageQuality: 75);
      if (pickedFiles.isEmpty) return;

      setState(() => _isUploadingImage = true);

      final List<String> newUrls = List.from(_currentImageUrls);
      for (final xfile in pickedFiles) {
        final file = File(xfile.path);
        final ext = xfile.path.split('.').last;
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_${newUrls.length}.$ext';

        await _client.storage.from('mandi-assets').upload(fileName, file);
        final publicUrl = _client.storage.from('mandi-assets').getPublicUrl(fileName);
        newUrls.add(publicUrl);
      }

      _setImageUrls(newUrls);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${pickedFiles.length} images successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showAddImageUrlDialog(bool isDark) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
        title: Text('ADD IMAGE LINK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(hintText: 'https://... image url'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
            onPressed: () {
              final link = ctrl.text.trim();
              if (link.isNotEmpty) {
                final list = List<String>.from(_currentImageUrls);
                list.add(link);
                _setImageUrls(list);
              }
              Navigator.pop(ctx);
            },
            child: const Text('ADD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageManagerSection(bool isDark) {
    final images = _currentImageUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PRODUCT PHOTOS (${images.length})', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showAddImageUrlDialog(isDark),
                  icon: const Icon(Icons.link_rounded, size: 16, color: Colors.blueAccent),
                  label: Text('ADD LINK', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _isUploadingImage ? null : _pickAndUploadImages,
                  icon: _isUploadingImage
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.black),
                  label: Text(_isUploadingImage ? 'UPLOADING...' : 'UPLOAD PHOTOS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (images.isNotEmpty)
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (ctx, idx) {
                final url = images[idx];
                return Container(
                  width: 95,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                          errorWidget: (c, e, s) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 24)),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            final list = List<String>.from(images);
                            list.removeAt(idx);
                            _setImageUrls(list);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                      if (idx == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(6)),
                            child: const Text('COVER', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        _buildField('Image URLs (comma-separated for carousel)', _imageUrlController, Icons.photo_library_rounded, isDark),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    _shelfLifeController.dispose();
    _tagsController.dispose();
    _ingredientsController.dispose();
    _usageController.dispose();
    _imageUrlController.dispose();
    _barcodeController.dispose();
    _hsnController.dispose();
    _taxRateController.dispose();
    _costPriceController.dispose();
    _minStockController.dispose();
    for(var c in _factLabelControllers) c.dispose();
    for(var c in _factValueControllers) c.dispose();
    _ratingController.dispose();
    _reviewsController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Map<String, String>? _getNutritionalMap() {
    final map = <String, String>{};
    for(int i = 0; i < _factLabelControllers.length; i++) {
      final k = _factLabelControllers[i].text.trim();
      final v = _factValueControllers[i].text.trim();
      if(k.isNotEmpty && v.isNotEmpty) {
         map[k] = v;
      }
    }
    return map.isEmpty ? null : map;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final payload = {
        'name': _nameController.text,
        'sku_qr': _skuController.text,
        'category': _categoryController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'discount_price': _discountPriceController.text.isEmpty ? null : double.tryParse(_discountPriceController.text),
        'stock_quantity': int.tryParse(_stockController.text) ?? 0,
        'description': _descriptionController.text,
        'brand': _brandController.text,
        'weight_ml': _weightController.text,
        'package_type': _packageType,
        'is_bestseller': _isBestseller,
        'shelf_life': _shelfLifeController.text,
        'tags': _tags,
        'ingredients': _ingredientsController.text,
        'how_to_use': _usageController.text,
        'image_url': _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
        'rating': double.tryParse(_ratingController.text) ?? 4.5,
        'total_reviews': int.tryParse(_reviewsController.text) ?? 0,
        'nutritional_info': _getNutritionalMap(),
        'unit': _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim(),
        'is_mandi': _isMandi,
        'barcode': _barcodeController.text.trim().isEmpty ? _skuController.text.trim() : _barcodeController.text.trim(),
        'hsn_code': _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
        'tax_rate': double.tryParse(_taxRateController.text) ?? 0.0,
        'cost_price': _costPriceController.text.trim().isEmpty ? null : double.tryParse(_costPriceController.text),
        'min_stock_alert': int.tryParse(_minStockController.text) ?? 5,
        'is_tax_inclusive': _isTaxInclusive,
      };

      ShopItem? savedItem;
      if (widget.product == null) {
        final inserted = await _client.from('shop_items').insert(payload).select().maybeSingle();
        if (inserted != null) {
          savedItem = ShopItem.fromJson(inserted);
        }
      } else {
        final updated = await _client.from('shop_items').update(payload).eq('id', widget.product!.id).select().maybeSingle();
        if (updated != null) {
          savedItem = ShopItem.fromJson(updated);
        }
      }

      if (mounted) {
        Navigator.pop(context, savedItem ?? true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.product == null ? 'NEW ITEM DEPLOYED' : 'LOGISTICS SYNCED'} SUCCESSFULLY'),
          backgroundColor: Colors.indigoAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DEPOT REJECTED: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.product == null ? 'NEW PRODUCT' : 'EDIT PRODUCT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isLoading) 
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2)))
          else
            TextButton(onPressed: _saveProduct, child: Text('SAVE', style: TextStyle(color: isDark ? Colors.pinkAccent : Colors.pink, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(child: _buildSectionTitle('BASIC INFORMATION', Colors.indigoAccent, isDark)),
              const SizedBox(height: 24),
              _buildField('Product Name', _nameController, Icons.label_rounded, isDark, isRequired: true),
              _buildField(
                'SKU / QR Code', 
                _skuController, 
                Icons.qr_code_scanner_rounded, 
                isDark,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.indigoAccent, size: 18),
                  tooltip: 'Scan SKU with Camera',
                  onPressed: () => _scanBarcodeInto(_skuController),
                ),
              ),
              Row(children: [
                Expanded(child: _buildField('Base Price (₹)', _priceController, Icons.payments_rounded, isDark, isNumeric: true, isRequired: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Discount Price (₹)', _discountPriceController, Icons.local_offer_rounded, isDark, isNumeric: true)),
              ]),
              Row(children: [
                Expanded(child: _buildCategoryAutocomplete(isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Stock Units', _stockController, Icons.inventory_2_rounded, isDark, isNumeric: true)),
              ]),

              const SizedBox(height: 32),
              FadeInDown(child: _buildSectionTitle('POS & GST / TAX SPECIFICATIONS', Colors.amberAccent, isDark)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: _buildField(
                    'Barcode (1D/2D EAN/UPC)', 
                    _barcodeController, 
                    Icons.barcode_reader, 
                    isDark,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.barcode_reader, color: Colors.amberAccent, size: 18),
                      tooltip: 'Scan Barcode with Camera',
                      onPressed: () => _scanBarcodeInto(_barcodeController),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildField('HSN / SAC Code', _hsnController, Icons.tag_rounded, isDark)),
              ]),
              Row(children: [
                Expanded(child: _buildField('GST Rate % (e.g. 5, 12, 18)', _taxRateController, Icons.percent_rounded, isDark, isNumeric: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Cost Price / Buy (₹)', _costPriceController, Icons.shopping_cart_checkout, isDark, isNumeric: true)),
              ]),
              Row(children: [
                Expanded(child: _buildField('Low Stock Warning Alert', _minStockController, Icons.warning_amber_rounded, isDark, isNumeric: true)),
                const SizedBox(width: 16),
                Expanded(child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price is Tax Inclusive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Switch(value: _isTaxInclusive, onChanged: (v) => setState(() => _isTaxInclusive = v), activeColor: Colors.amberAccent),
                    ],
                  ),
                )),
              ]),
              
              const SizedBox(height: 40),
              FadeInDown(child: _buildSectionTitle('ADDITIONAL DETAILS', Colors.pinkAccent, isDark)),
              const SizedBox(height: 24),
              _buildField('Brand / Manufacturer', _brandController, Icons.verified_rounded, isDark),
              Row(children: [
                Expanded(child: _buildField('Weight (e.g. 500g)', _weightController, Icons.scale_rounded, isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildPackageDropdown(isDark)),
              ]),
              Row(children: [
                Expanded(child: _buildField('Sales Unit (e.g. kg, pcs)', _unitController, Icons.shopping_bag_outlined, isDark)),
                const SizedBox(width: 16),
                Expanded(child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mandi Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Switch(value: _isMandi, onChanged: (v) => setState(() => _isMandi = v), activeColor: Colors.indigoAccent),
                    ],
                  ),
                )),
              ]),
              _buildTagManager(isDark),
              _buildField('Shelf Life', _shelfLifeController, Icons.timer_rounded, isDark),
              _buildSwitchField('Mark as Bestseller', _isBestseller, isDark, (v) => setState(() => _isBestseller = v)),
              
              const SizedBox(height: 40),
              FadeInDown(child: _buildSectionTitle('USAGE & PERFORMANCE', Colors.blueAccent, isDark)),
              const SizedBox(height: 24),
              _buildImageManagerSection(isDark),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _buildField('App Rating', _ratingController, Icons.star_rate_rounded, isDark, isNumeric: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildField('Review Count', _reviewsController, Icons.reviews_rounded, isDark, isNumeric: true)),
              ]),
              
              const SizedBox(height: 32),
              _buildNutritionFactEditor(isDark),

              const SizedBox(height: 32),
              _buildLargeField('Description', _descriptionController, isDark),
              _buildLargeField('Ingredients', _ingredientsController, isDark),
              _buildLargeField('How to Use', _usageController, isDark),
              
              const SizedBox(height: 50),
              
              if (_isLoading)
                 const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              else
                 _buildSubmitButton(isDark),
                 
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.indigoAccent, Colors.indigoAccent]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.indigoAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton(
        onPressed: _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          widget.product == null ? 'CREATE PRODUCT' : 'UPDATE PRODUCT',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color c, bool isDark) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.outfit(color: c, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildField(String hint, TextEditingController controller, IconData icon, bool isDark, {bool isNumeric = false, bool isRequired = false, Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 18),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Field Required' : null : null,
      ),
    );
  }

  void _scanBarcodeInto(TextEditingController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Scan Barcode / QR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) async {
                final barcodes = capture.barcodes;
                for (final b in barcodes) {
                  final code = b.rawValue;
                  if (code != null && code.isNotEmpty) {
                    controller.text = code;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Scanned: $code. Fetching details...'), backgroundColor: Colors.indigo),
                    );

                    // Fetch details from online registries
                    await _autoFetchForBarcode(code);
                    break;
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeField(String hint, TextEditingController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        maxLines: 4,
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 12),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildPackageDropdown(bool isDark) {
    final List<String> packageTypes = ['Packet', 'Bottle', 'Can', 'Unit', 'Box', 'Bar', 'Jar', 'Tetra', 'Tube', 'Strip', 'Egg', 'Dropper', 'Pack', 'Bundle'];
    
    // Safety check: ensure _packageType is valid and present in packageTypes
    String selectedPackageType = _packageType;
    if (!packageTypes.contains(selectedPackageType)) {
      if (selectedPackageType.isEmpty) {
        selectedPackageType = 'Packet';
      } else {
        packageTypes.add(selectedPackageType);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedPackageType,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
          onChanged: (v) => setState(() {
            _packageType = v!;
          }),
          items: packageTypes
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryAutocomplete(bool isDark) {
    List<String> categories = _knownCategories.toList();
    if (!categories.contains(_categoryController.text) && _categoryController.text.isNotEmpty) {
      categories.add(_categoryController.text);
    }
    if (categories.isEmpty) categories = ['Snacks', 'Drinks', 'Personal Care', 'Stationery', 'Essentials'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categoryController.text.isEmpty ? categories.first : _categoryController.text,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
          onChanged: (v) => setState(() => _categoryController.text = v!),
          items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
        ),
      ),
    );
  }

  Widget _buildTagManager(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRODUCT TAGS', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              onDeleted: () => setState(() => _tags.remove(t)),
              backgroundColor: Colors.indigoAccent.withOpacity(0.1),
              deleteIconColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 14),
              label: const Text('ADD TAG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddTagDialog(isDark),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showAddTagDialog(bool isDark) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('NEW TAG', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
      content: Autocomplete<String>(
        optionsBuilder: (text) {
           if (text.text.isEmpty) return _knownTags;
           return _knownTags.where((s) => s.toLowerCase().contains(text.text.toLowerCase()));
        },
        onSelected: (s) => ctrl.text = s,
        fieldViewBuilder: (ctx, c, focus, onSubmitted) {
           c.text = ctrl.text;
           c.addListener(() => ctrl.text = c.text);
           return TextField(controller: c, focusNode: focus, decoration: const InputDecoration(hintText: 'Tag name...'));
        },
      ),
      actions: [
        TextButton(onPressed: () {
          if (ctrl.text.isNotEmpty && !_tags.contains(ctrl.text)) {
            setState(() => _tags.add(ctrl.text));
          }
          Navigator.pop(ctx);
        }, child: const Text('ADD')),
      ],
    ));
  }

  Widget _buildNutritionFactEditor(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('NUTRITIONAL VALUES', style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            TextButton.icon(
              onPressed: _addFactField,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.blueAccent),
              label: Text('ADD FACT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _factLabelControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return _commonFacts;
                        return _commonFacts.where((s) => s.toLowerCase().contains(value.text.toLowerCase()));
                      },
                      onSelected: (s) => _factLabelControllers[index].text = s,
                      fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                        ctrl.text = _factLabelControllers[index].text;
                        ctrl.addListener(() => _factLabelControllers[index].text = ctrl.text);
                        return _buildSmallField('Fact (e.g. Protein)', ctrl, isDark);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildSmallField('Value (e.g. 15g)', _factValueControllers[index], isDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                    onPressed: () => _removeFactField(index),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwitchField(String label, bool value, bool isDark, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _buildSmallField(String hint, TextEditingController controller, bool isDark) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
