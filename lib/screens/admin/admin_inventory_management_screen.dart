import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'admin_edit_product_screen.dart';
import '../inventory_scanner_screen.dart';
import '../../models/shop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:io';
import '../../utils/csv_web_helper.dart';
import '../../utils/csv_range_dialog.dart';

class AdminInventoryManagementScreen extends StatefulWidget {
  const AdminInventoryManagementScreen({super.key});

  @override
  State<AdminInventoryManagementScreen> createState() => _AdminInventoryManagementScreenState();
}

class _AdminInventoryManagementScreenState extends State<AdminInventoryManagementScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<ShopItem> _allItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInventory();
  }

  Future<void> _exportInventoryToCSV() async {
    final String activeType = _tabController.index == 0 ? 'SHOP' : (_tabController.index == 1 ? 'MESS' : 'CANTEEN');
    final String typeLabel = _tabController.index == 0 ? 'Shop Stock' : (_tabController.index == 1 ? 'Mess Inventory' : 'Canteen');

    final range = await showCsvRangeDialog(
      context: context,
      title: '$typeLabel Export',
      isImport: false,
    );
    if (range == null) return;

    try {
      final List<String> csvHeaders = [
        'id', 'name', 'sku_qr', 'category', 'description', 'price', 'discount_price',
        'stock_quantity', 'image_url', 'is_available', 'brand', 'weight_ml', 'package_type',
        'is_bestseller', 'rating', 'total_reviews', 'shelf_life', 'tags', 'ingredients',
        'how_to_use', 'unit', 'is_mandi'
      ];
      
      final buffer = StringBuffer();
      buffer.writeln(csvHeaders.join(','));

      final targetItems = _allItems.where((i) {
        final cat = i.category.toLowerCase();
        final name = i.name.toLowerCase();
        
        // Tab type filter
        bool matchesType = true;
        if (activeType == 'SHOP') {
          matchesType = !cat.contains('kitchen') && !cat.contains('raw') && !cat.contains('grocery') && 
                        !cat.contains('beverage') && !cat.contains('snack') && !cat.contains('meal') && 
                        !cat.contains('ready');
        } else if (activeType == 'MESS') {
          matchesType = cat.contains('kitchen') || cat.contains('raw') || cat.contains('grocery') || 
                        cat.contains('bulk') || name.contains('rice') || name.contains('dal') || name.contains('oil');
        } else if (activeType == 'CANTEEN') {
          matchesType = cat.contains('beverage') || cat.contains('snack') || cat.contains('ready') || 
                        cat.contains('canteen') || cat.contains('fast food') || name.contains('coke') || name.contains('chips');
        }

        // Date filter: only if rateDate is available
        if (matchesType && i.rateDate != null) {
          final dt = DateTime.tryParse(i.rateDate!.toString());
          if (dt != null) {
            return dt.isAfter(range.startDate) && dt.isBefore(range.endDate);
          }
        }
        return matchesType;
      }).toList();
      
      for (var item in targetItems) {
        final List<String> row = [
          item.id,
          '"${item.name.replaceAll('"', '""')}"',
          item.skuQr ?? '',
          '"${item.category.replaceAll('"', '""')}"',
          '"${(item.description ?? '').replaceAll('"', '""')}"',
          item.price.toString(),
          (item.discountPrice ?? '').toString(),
          item.stockQuantity.toString(),
          item.imageUrl ?? '',
          item.isAvailable.toString(),
          '"${(item.brand ?? '').replaceAll('"', '""')}"',
          item.weightMl ?? '',
          item.packageType ?? '',
          item.isBestseller.toString(),
          item.rating.toString(),
          item.totalReviews.toString(),
          item.shelfLife ?? '',
          '"${(item.tags?.join(';') ?? '').replaceAll('"', '""')}"',
          '"${(item.ingredients ?? '').replaceAll('"', '""')}"',
          '"${(item.howToUse ?? '').replaceAll('"', '""')}"',
          item.unit,
          item.isMandi.toString(),
        ];
        buffer.writeln(row.join(','));
      }
      
      final dateLabel = '${DateFormat('yyyyMMdd').format(range.startDate)}_to_${DateFormat('yyyyMMdd').format(range.endDate)}';
      final filename = '${activeType.toLowerCase()}_inventory_$dateLabel.csv';

      if (kIsWeb) {
        try {
          downloadCsvFile(buffer.toString(), filename);
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export not supported on this browser.'), backgroundColor: Colors.orangeAccent));
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: '$typeLabel Inventory Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _importInventoryFromCSV() async {
    final String activeType = _tabController.index == 0 ? 'SHOP' : (_tabController.index == 1 ? 'MESS' : 'CANTEEN');
    final String typeLabel = _tabController.index == 0 ? 'Shop Stock' : (_tabController.index == 1 ? 'Mess Inventory' : 'Canteen');

    final range = await showCsvRangeDialog(
      context: context,
      title: '$typeLabel Import',
      isImport: true,
    );
    if (range == null) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result == null) return;

      // Web uses bytes; native uses path
      List<String> lines;
      if (kIsWeb) {
        final bytes = result.files.single.bytes;
        if (bytes == null) return;
        lines = utf8.decode(bytes).split('\n');
      } else {
        if (result.files.single.path == null) return;
        final file = File(result.files.single.path!);
        lines = await file.readAsLines();
      }
      if (lines.length < 2) {
        throw 'File is empty or missing content rows';
      }
      
      // Parse header to map columns
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      
      int successCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Simple CSV cell parsing matching double quotes
        final List<String> cells = [];
        bool inQuotes = false;
        StringBuffer currentCell = StringBuffer();
        
        for (int c = 0; c < line.length; c++) {
          final char = line[c];
          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            cells.add(currentCell.toString().trim());
            currentCell.clear();
          } else {
            currentCell.write(char);
          }
        }
        cells.add(currentCell.toString().trim());
        
        if (cells.length < 4) continue;
        
        // Build payload row
        final Map<String, dynamic> payload = {};
        
        String? itemId;
        
        for (int cellIdx = 0; cellIdx < cells.length; cellIdx++) {
          if (cellIdx >= headers.length) break;
          final header = headers[cellIdx];
          final val = cells[cellIdx].replaceAll(RegExp(r'^"|"$'), '').replaceAll('""', '"');
          
          if (header == 'id') {
            if (val.isNotEmpty && val.length > 5) itemId = val;
          } else if (header == 'name') {
            payload['name'] = val;
          } else if (header == 'sku_qr') {
            payload['sku_qr'] = val.isEmpty ? null : val;
          } else if (header == 'category') {
            payload['category'] = val.isEmpty ? 'General' : val;
          } else if (header == 'description') {
            payload['description'] = val;
          } else if (header == 'price') {
            payload['price'] = double.tryParse(val) ?? 0.0;
          } else if (header == 'discount_price') {
            payload['discount_price'] = val.isEmpty ? null : double.tryParse(val);
          } else if (header == 'stock_quantity') {
            payload['stock_quantity'] = int.tryParse(val) ?? 0;
          } else if (header == 'image_url') {
            payload['image_url'] = val.isEmpty ? null : val;
          } else if (header == 'is_available') {
            payload['is_available'] = val.toLowerCase() == 'true';
          } else if (header == 'brand') {
            payload['brand'] = val;
          } else if (header == 'weight_ml') {
            payload['weight_ml'] = val;
          } else if (header == 'package_type') {
            payload['package_type'] = val;
          } else if (header == 'is_bestseller') {
            payload['is_bestseller'] = val.toLowerCase() == 'true';
          } else if (header == 'rating') {
            payload['rating'] = double.tryParse(val) ?? 4.5;
          } else if (header == 'total_reviews') {
            payload['total_reviews'] = int.tryParse(val) ?? 0;
          } else if (header == 'shelf_life') {
            payload['shelf_life'] = val;
          } else if (header == 'tags') {
            payload['tags'] = val.isEmpty ? [] : val.split(';');
          } else if (header == 'ingredients') {
            payload['ingredients'] = val;
          } else if (header == 'how_to_use') {
            payload['how_to_use'] = val;
          } else if (header == 'unit') {
            payload['unit'] = val.isEmpty ? 'pcs' : val;
          } else if (header == 'is_mandi') {
            payload['is_mandi'] = val.toLowerCase() == 'true';
          }
        }
        
        if (payload['name'] == null) continue;

        // Enforce active category import separation
        final cat = (payload['category']?.toString() ?? '').toLowerCase();
        final name = (payload['name']?.toString() ?? '').toLowerCase();
        bool matchesType = true;
        if (activeType == 'SHOP') {
          matchesType = !cat.contains('kitchen') && !cat.contains('raw') && !cat.contains('grocery') && 
                        !cat.contains('beverage') && !cat.contains('snack') && !cat.contains('meal') && 
                        !cat.contains('ready');
        } else if (activeType == 'MESS') {
          matchesType = cat.contains('kitchen') || cat.contains('raw') || cat.contains('grocery') || 
                        cat.contains('bulk') || name.contains('rice') || name.contains('dal') || name.contains('oil');
        } else if (activeType == 'CANTEEN') {
          matchesType = cat.contains('beverage') || cat.contains('snack') || cat.contains('ready') || 
                        cat.contains('canteen') || cat.contains('fast food') || name.contains('coke') || name.contains('chips');
        }
        if (!matchesType) continue;
        
        if (itemId != null) {
          // Update item
          await _client.from('shop_items').update(payload).eq('id', itemId);
        } else {
          // Insert item
          await _client.from('shop_items').insert(payload);
        }
        successCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully processed $successCount inventory records'), backgroundColor: Colors.indigoAccent));
        _fetchInventory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final shopRes = await _client.from('shop_items').select().order('name');
      final List<ShopItem> combined = (shopRes as List).map((i) => ShopItem.fromJson(i)).toList();

      if (mounted) {
        setState(() {
          _allItems = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> _getAnalytics(List<ShopItem> items) {
    int total = items.length;
    int low = items.where((i) => i.stockQuantity > 0 && i.stockQuantity < 10).length;
    int out = items.where((i) => i.stockQuantity <= 0).length;
    return {'total': total, 'low': low, 'out': out};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('INVENTORY MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_rounded, color: Colors.indigoAccent),
            tooltip: 'Import CSV',
            onPressed: _importInventoryFromCSV,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: Colors.indigoAccent),
            tooltip: 'Export CSV',
            onPressed: _exportInventoryToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigoAccent),
            tooltip: 'Barcode Scanner (Single & Batch)',
            onPressed: () async {
              final dynamic result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InventoryScannerScreen(existingCatalog: _allItems)),
              );
              if (result != null) {
                if (!mounted) return;
                if (result is int && result > 0) {
                  // Batch mode completed and saved products directly
                  _fetchInventory();
                  return;
                }
                
                if (result is String && result.trim().isNotEmpty) {
                  final cleanResult = result.trim().toLowerCase();
                  // Try finding item by barcode or sku_qr
                  final item = _allItems.cast<ShopItem?>().firstWhere(
                    (i) => (i?.barcode?.trim().toLowerCase() == cleanResult) ||
                           (i?.skuQr?.trim().toLowerCase() == cleanResult) ||
                           (i?.id.trim().toLowerCase() == cleanResult),
                    orElse: () => null,
                  );
                  if (item != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: item))).then((_) => _fetchInventory());
                  } else {
                    // Not found, open Add screen with SKU pre-filled (auto-resolves from online registries, allows manual edits & saving)
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(scannedSku: result.trim()))).then((_) => _fetchInventory());
                  }
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
             Tab(text: 'SHOP STOCK'),
             Tab(text: 'MESS INVENTORY'),
             Tab(text: 'CANTEEN'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildRefractionOrbs(isDark),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Desktop/Wide View: 2-column sidebar tab structure
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                            ),
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              children: [
                                _buildInventorySidebarTile(0, 'SHOP STOCK', Icons.storefront_rounded),
                                _buildInventorySidebarTile(1, 'MESS INVENTORY', Icons.restaurant_menu_rounded),
                                _buildInventorySidebarTile(2, 'CANTEEN', Icons.coffee_rounded),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _buildSearchBar(isDark),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildTabContent('SHOP', isDark, cardColor, borderColor),
                                    _buildTabContent('MESS', isDark, cardColor, borderColor),
                                    _buildTabContent('CANTEEN', isDark, cardColor, borderColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile View: Single column layout list
                  return Column(
                    children: [
                      _buildSearchBar(isDark),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTabContent('SHOP', isDark, cardColor, borderColor),
                            _buildTabContent('MESS', isDark, cardColor, borderColor),
                            _buildTabContent('CANTEEN', isDark, cardColor, borderColor),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEditProductScreen()));
          if (res == true) _fetchInventory();
        },
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildInventorySidebarTile(int index, String label, IconData icon) {
    final active = _tabController.index == index;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.indigoAccent.withOpacity(0.08),
      leading: Icon(icon, color: active ? Colors.indigoAccent : Colors.grey),
      title: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: active ? Colors.indigoAccent : Colors.grey)),
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'FILTER BY ITEM NAME OR CODE...',
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 20),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigoAccent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRefractionOrbs(bool isDark) {
    return Positioned(bottom: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(isDark ? 0.05 : 0.02), shape: BoxShape.circle))));
  }

  Widget _buildTabContent(String type, bool isDark, Color cardColor, Color borderColor) {
    final filteredItems = _allItems.where((i) {
      final cat = i.category.toLowerCase();
      final name = i.name.toLowerCase();
      if (type == 'SHOP') {
        // Items NOT in other categories
        return !cat.contains('kitchen') && !cat.contains('raw') && !cat.contains('grocery') && 
               !cat.contains('beverage') && !cat.contains('snack') && !cat.contains('meal') && 
               !cat.contains('ready');
      }
      if (type == 'MESS') {
        // Raw materials and bulk kitchen supplies
        return cat.contains('kitchen') || cat.contains('raw') || cat.contains('grocery') || 
               cat.contains('bulk') || name.contains('rice') || name.contains('dal') || name.contains('oil');
      }
      if (type == 'CANTEEN') {
        // Ready to eat, snacks, beverages
        return cat.contains('beverage') || cat.contains('snack') || cat.contains('ready') || 
               cat.contains('canteen') || cat.contains('fast food') || name.contains('coke') || name.contains('chips');
      }
      return true;
    }).toList();

    final searchFiltered = filteredItems.where((i) => 
      i.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      i.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    
    final stats = _getAnalytics(filteredItems);

    return Column(
      children: [
        _buildAnalyticsRow(stats, isDark),
        Expanded(
          child: searchFiltered.isEmpty 
            ? _buildEmptyInventory(type, isDark)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: searchFiltered.length,
                itemBuilder: (context, i) => _buildItemCard(searchFiltered[i], cardColor, borderColor, isDark),
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyInventory(String type, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
          Text('NO ITEMS IN $type REPOSITORY', style: GoogleFonts.outfit(color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Register new assets using the action button.', style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(Map<String, int> stats, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          _statCard('TOTAL', stats['total']!, Colors.indigoAccent, isDark),
          const SizedBox(width: 12),
          _statCard('LOW STOCK', stats['low']!, Colors.amberAccent, isDark),
          const SizedBox(width: 12),
          _statCard('OUT OF STOCK', stats['out']!, Colors.redAccent, isDark),
        ],
      ),
    );
  }

  Widget _statCard(String label, int val, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.1))),
        child: Column(
          children: [
            Text(val.toString(), style: GoogleFonts.outfit(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ShopItem item, Color cardColor, Color borderColor, bool isDark) {
    final int stock = item.stockQuantity;
    final bool lowStock = stock < 10;
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: lowStock ? Colors.redAccent.withOpacity(0.3) : borderColor)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: item.imageUrl != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.inventory_2_rounded, color: Colors.indigoAccent)))
              : const Icon(Icons.inventory_2_rounded, color: Colors.indigoAccent),
          ),
          title: Text(item.name, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(children: [
              _statusTag('QTY: $stock', lowStock ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 8),
              _statusTag('₹${item.discountPrice ?? item.price}', Colors.indigoAccent),
            ]),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
             _actionIcon(Icons.history_rounded, isDark ? Colors.white24 : Colors.black26, () {}),
             _actionIcon(Icons.edit_rounded, Colors.blueAccent, () async {
               final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: item)));
               if (res == true) _fetchInventory();
             }),
          ]),
        ),
      ),
    );
  }

  Widget _statusTag(String label, Color c) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900)));
  }

  Widget _actionIcon(IconData icon, Color c, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: c, size: 20), onPressed: onTap);
  }
}
