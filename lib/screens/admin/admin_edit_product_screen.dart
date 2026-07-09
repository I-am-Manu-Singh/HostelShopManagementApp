import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../models/shop.dart';

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
  bool _isSaving = false;

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
  bool _isBestseller = false;
  bool _isMandi = false;
  String _packageType = 'Packet';
  bool _isLoading = false;
  
  // 🛡️ DYNAMIC DATA LISTS
  final List<TextEditingController> _factLabelControllers = [];
  final List<TextEditingController> _factValueControllers = [];
  final List<String> _tags = [];
  final Set<String> _knownTags = {};
  final Set<String> _knownCategories = {};
  
  final List<String> _commonFacts = [
    'Energy', 'Calories', 'Total Fat', 'Saturated Fat', 'Trans Fat', 
    'Cholesterol', 'Sodium', 'Total Carbohydrates', 'Dietary Fiber', 
    'Sugars', 'Protein', 'Calcium', 'Iron', 'Vitamin A', 'Vitamin C', 'Vitamin D'
  ];

  @override
  void initState() {
    super.initState();
    _loadSyncMetadata();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _skuController = TextEditingController(text: p?.skuQr ?? widget.scannedSku);
    _categoryController = TextEditingController(text: p?.category);
    _priceController = TextEditingController(text: p?.price?.toString() ?? '');
    _discountPriceController = TextEditingController(text: p?.discountPrice?.toString() ?? '');
    _stockController = TextEditingController(text: p?.stockQuantity?.toString() ?? '');
    _descriptionController = TextEditingController(text: p?.description);
    _brandController = TextEditingController(text: p?.brand);
    _weightController = TextEditingController(text: p?.weightMl);
    _shelfLifeController = TextEditingController(text: p?.shelfLife);
    _ingredientsController = TextEditingController(text: p?.ingredients);
    _usageController = TextEditingController(text: p?.howToUse);
    _imageUrlController = TextEditingController(text: p?.imageUrl);
    _ratingController = TextEditingController(text: p?.rating?.toString() ?? '4.5');
    _reviewsController = TextEditingController(text: p?.totalReviews?.toString() ?? '0');
    _isBestseller = p?.isBestseller ?? false;
    _packageType = p?.packageType ?? 'Packet';
    _unitController = TextEditingController(text: p?.unit ?? 'pcs');
    _isMandi = p?.isMandi ?? false;

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

  Map<String, String>? _parseNutritional(String text) {
    if (text.trim().isEmpty) return null;
    final map = <String, String>{};
    for (var pair in text.split(',')) {
      final parts = pair.split(':');
      if (parts.length == 2) map[parts[0].trim()] = parts[1].trim();
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
      };

      if (widget.product == null) {
        await _client.from('shop_items').insert(payload);
      } else {
        await _client.from('shop_items').update(payload).eq('id', widget.product!.id);
      }

      if (mounted) {
        Navigator.pop(context, true);
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
              _buildField('SKU / QR Code', _skuController, Icons.qr_code_scanner_rounded, isDark),
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
              _buildField('Image URL', _imageUrlController, Icons.image_rounded, isDark),
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
        gradient: const LinearGradient(colors: [Colors.indigoAccent, Colors.pinkAccent]),
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
          widget.product == null ? 'CREATE PRODUCT' : 'UPDATE REQUISITION',
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

  Widget _buildField(String hint, TextEditingController controller, IconData icon, bool isDark, {bool isNumeric = false, bool isRequired = false}) {
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
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Field Required' : null : null,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _packageType,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF16181A) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
          onChanged: (v) => setState(() => _packageType = v!),
          items: ['Packet', 'Bottle', 'Can', 'Unit', 'Box', 'Bar', 'Jar', 'Tetra', 'Tube', 'Strip', 'Egg', 'Dropper', 'Pack']
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
