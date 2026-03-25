import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_room_intelligence_screen.dart';

class AdminBlockManagementScreen extends StatefulWidget {
  const AdminBlockManagementScreen({super.key});

  @override
  State<AdminBlockManagementScreen> createState() => _AdminBlockManagementScreenState();
}

class _AdminBlockManagementScreenState extends State<AdminBlockManagementScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _hostels = [];
  List<dynamic> _feePackages = []; // 🧬 Dynamic Room Types

  @override
  void initState() {
    super.initState();
    _fetchHostels();
  }

  Future<void> _fetchHostels() async {
    setState(() => _isLoading = true);
    try {
      // 🧠 Fetch from building_name
      final response = await _client.from('hostel_rooms').select('building_name, floor');
      
      final Map<String, List<int>> map = {};
      for (var r in (response as List)) {
        final b = r['building_name'] ?? 'General Building';
        final f = int.tryParse(r['floor']?.toString() ?? '0') ?? 0;
        if (!map.containsKey(b)) map[b] = [];
        if (!map[b]!.contains(f)) map[b]!.add(f);
      }

      final List<Map<String, dynamic>> list = [];
      map.forEach((k, v) {
        v.sort();
        list.add({'name': k, 'floors': v});
      });

      // 🧬 Fetch valid types from Headquarters
      try {
         final pkgRes = await _client.from('fee_structure').select().eq('category', 'Hostel');
         debugPrint('🚀 [ARCH_TYPE_SYNC] Found ${pkgRes.length} archetypes.');
         if (mounted) setState(() => _feePackages = pkgRes);
      } catch (e) {
         debugPrint('❌ ARCH_TYPE_SYNC_ERROR: $e');
      }

      if (mounted) {
        setState(() {
          _hostels = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark?const Color(0xFF0F172A):Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('BUILDING MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
           IconButton(icon: const Icon(Icons.add_business_rounded, color: Colors.indigoAccent), onPressed: () => _showAddBuildingModal(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBuildingModal(isDark),
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('CONSTRUCT BLOCK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12, letterSpacing: 1)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _hostels.length,
            itemBuilder: (context, i) => _buildHostelCard(_hostels[i], isDark),
          ),
    );
  }

  Widget _buildHostelCard(Map<String, dynamic> hostel, bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminRoomIntelligenceScreen(blockName: hostel['name']))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(36), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text(hostel['name'].toUpperCase(), style: GoogleFonts.outfit(color: isDark?Colors.white:Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                 Row(children: [
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _showDeleteBuildingDialog(hostel['name'])),
                    const Icon(Icons.business_rounded, color: Colors.indigoAccent, size: 24),
                 ]),
              ]),
              const SizedBox(height: 12),
              Text('${hostel['floors'].length} OPERATIONAL FLOORS', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 24),
              Wrap(spacing: 8, runSpacing: 8, children: (hostel['floors'] as List).map((f) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('F$f', style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900)))).toList()),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteBuildingDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('DECOMMISSION BLOCK?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove all units in $name? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(onPressed: () async {
             try {
                // 🧬 Cascading Purge: Free the building of all occupants first
                final roomsInBlock = await _client.from('hostel_rooms').select('id').eq('building_name', name);
                final List<dynamic> roomIds = (roomsInBlock as List).map((r) => r['id']).toList();
                
                if (roomIds.isNotEmpty) {
                   await _client.from('hostel_enrollments').delete().inFilter('room_id', roomIds);
                }
                
                // 🏗️ Structural Wipe: Remove the physical units
                await _client.from('hostel_rooms').delete().eq('building_name', name);
                
                Navigator.pop(ctx); 
                _fetchHostels();
             } catch (e) {
                debugPrint('❌ DECOMMISSION_ERROR: $e');
                if (mounted) {
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operational Error: $e'), backgroundColor: Colors.redAccent));
                }
             }
          }, child: const Text('DELETE ALL DATA', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _showAddBuildingModal(bool isDark) {
    final nameCtrl = TextEditingController();
    final floorsCtrl = TextEditingController(text: '1');
    final roomsPerFloorCtrl = TextEditingController(text: '5');
    
    // Architect's Workbench: Floor-level room configurations
    Map<int, List<Map<String, dynamic>>> floorMap = {}; 
    bool startFromZero = true; // 🧬 Zero-Floor Toggling
    String? selType;
    if (_feePackages.isNotEmpty) selType = _feePackages[0]['service_name'];
    
    bool isGenerating = false;
    bool isDeploying = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (c, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: isDark?const Color(0xFF1E293B):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ARCHITECTURAL CONSTRUCTOR', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('PRECISION UNIT PLACEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
               ]),
               IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 32),
            
            // 🏗️ Structural Configuration Row
            Row(children: [
               Expanded(child: _buildInput('BLOCK NAME', 'e.g. 462', nameCtrl, isDark)),
               const SizedBox(width: 12),
               Expanded(child: _buildInput('LEVELS', '1-6', floorsCtrl, isDark, numerical: true)),
               const SizedBox(width: 12),
               Expanded(child: _buildInput('BASE_UNITS', '5', roomsPerFloorCtrl, isDark, numerical: true)),
            ]),
            const SizedBox(height: 16),
            
            // 🧬 Ground Floor Support Toggle
            Row(children: [
               Text('START FROM LEVEL 0 (GROUND)', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1, color: isDark?Colors.white38:Colors.black38)),
               const Spacer(),
               Switch(value: startFromZero, activeColor: Colors.indigoAccent, onChanged: (v) => setS(() => startFromZero = v)),
            ]),
            const SizedBox(height: 16),
            
            // 🧬 Space Type Selection
            Text('DEFAULT UNIT ARCHETYPE', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.indigoAccent)),
            const SizedBox(height: 8),
            _feePackages.isEmpty 
               ? Row(children: [
                    Expanded(child: _buildInput('MANUAL TYPE', 'e.g. Standard', TextEditingController(), isDark)),
                    IconButton(icon: const Icon(Icons.help_outline), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find data in fee_structure. Enter manually.'))))
                 ])
               : DropdownButton<String>(
                  value: selType, isExpanded: true,
                  items: _feePackages.map((t) => DropdownMenuItem(value: t['service_name'].toString(), child: Text(t['service_name'].toString()))).toList(),
                  onChanged: (v) => setS(() => selType = v!),
               ),
            const SizedBox(height: 24),

            // 🧬 Workbench Generation Trigger
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {
               final int flrs = int.tryParse(floorsCtrl.text) ?? 1;
               final int baseUnits = int.tryParse(roomsPerFloorCtrl.text) ?? 5;
               floorMap.clear();
               final int startLvl = startFromZero ? 0 : 1;
               for (int f = 0; f < flrs; f++) {
                  final int realLvl = startLvl + f;
                  floorMap[realLvl] = List.generate(baseUnits, (i) => {
                     'id': '${realLvl}${ (i+1).toString().padLeft(2, '0') }',
                     'type': selType ?? 'Standard',
                     'capacity': 2
                  });
               }
               setS(() => isGenerating = true);
            }, child: const Text('GENERATE BLUEPRINT'))),
            
            const SizedBox(height: 32),
            if (floorMap.isNotEmpty) ...[
               Text('BLUEPRINT ADJUSTMENT (TAP UNIT TO CUSTOMIZE)', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.indigoAccent)),
               const SizedBox(height: 16),
               Expanded(child: ListView.builder(
                  itemCount: floorMap.length,
                  itemBuilder: (ctx, f) {
                     final floorNum = floorMap.keys.elementAt(f);
                     final units = floorMap[floorNum]!;
                     return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text('LEVEL $floorNum', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                           const SizedBox(height: 8),
                           Wrap(spacing: 8, runSpacing: 8, children: [
                              ...units.asMap().entries.map((entry) => GestureDetector(
                                 onTap: () => _editUnitModal(ctx, units, entry.key, isDark, () => setS((){})),
                                 child: Container(
                                    padding: const EdgeInsets.all(12), 
                                    decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigoAccent.withOpacity(0.2))), 
                                    child: Column(children: [
                                       Text(entry.value['id'], style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                                       Text(entry.value['type'].toString().toUpperCase(), style: TextStyle(color: Colors.indigoAccent.withOpacity(0.5), fontSize: 6, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                    ])
                                 ),
                              )),
                              GestureDetector(onTap: () => setS(() => units.add({'id': 'NEW', 'type': selType ?? 'Standard', 'capacity': 2})), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, size: 14, color: Colors.greenAccent))),
                           ]),
                        ]),
                     );
                  },
               )),
               
               const SizedBox(height: 24),
               SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
                  onPressed: isDeploying ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    setS(() => isDeploying = true);
                    try {
                       if (selType == null && _feePackages.isNotEmpty) throw 'Select a valid Room Type';
                       
                       double basePrice = 6500.0;
                       if (_feePackages.isNotEmpty && selType != null) {
                          basePrice = double.tryParse(_feePackages.firstWhere((p) => p['service_name'] == selType)['price']?.toString() ?? '6500') ?? 6500;
                       }
                       
                       // Define final room type for deployment
                       final String finalType = selType ?? 'Standard';
                       
                       final List<Map<String, dynamic>> roomsToInsert = [];
                       floorMap.forEach((floor, units) {
                          for (var unit in units) {
                             final double bPrice = (_feePackages.isNotEmpty && unit['type'] != null)
                                ? double.tryParse(_feePackages.firstWhere((p) => p['service_name'] == unit['type'], orElse: () => {'price': '6500'})['price']?.toString() ?? '6500') ?? 6500
                                : 6500;

                             roomsToInsert.add({
                                'building_name': nameCtrl.text.trim(),
                                'room_number': unit['id'],
                                'floor': floor,
                                'capacity': unit['capacity'] ?? 2,
                                'room_type': unit['type'] ?? 'Standard',
                                'is_active': true,
                                'base_price': bPrice
                             });
                          }
                       });
                       
                       await _client.from('hostel_rooms').insert(roomsToInsert);
                       Navigator.pop(ctx);
                       _fetchHostels();
                    } catch (e) {
                       setS(() => isDeploying = false);
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Construction Failure: $e'), backgroundColor: Colors.redAccent));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: isDeploying ? const CircularProgressIndicator(color: Colors.white) : const Text('CONSTRUCT TOTAL BLOCK')
               )),
            ],
          ],
        ),
      )),
    );
  }

  void _editUnitModal(BuildContext ctx, List<Map<String, dynamic>> units, int index, bool isDark, VoidCallback onUpdate) {
     final idCtrl = TextEditingController(text: units[index]['id']);
     final capCtrl = TextEditingController(text: units[index]['capacity'].toString());
     String? unitType = units[index]['type'];

     showDialog(context: ctx, builder: (c) => StatefulBuilder(builder: (c2, setS) => AlertDialog(
        backgroundColor: isDark?const Color(0xFF1E293B):Colors.white,
        title: Text('UNIT CUSTOMIZATION: ${idCtrl.text}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Room Number')),
           TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacity (1-4)'), keyboardType: TextInputType.number),
           const SizedBox(height: 16),
           const Text('UNIT ARCHETYPE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
           _feePackages.isEmpty 
             ? TextField(onChanged: (v) => unitType = v, decoration: const InputDecoration(hintText: 'Manual Type'))
             : DropdownButton<String>(
                value: unitType, isExpanded: true,
                items: _feePackages.map((t) => DropdownMenuItem(value: t['service_name'].toString(), child: Text(t['service_name'].toString()))).toList(),
                onChanged: (v) => setS(() => unitType = v!),
             ),
        ]),
        actions: [
           TextButton(onPressed: () { units.removeAt(index); onUpdate(); Navigator.pop(c); }, child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent))),
           TextButton(onPressed: () { 
              units[index] = {
                 'id': idCtrl.text,
                 'type': unitType,
                 'capacity': int.tryParse(capCtrl.text) ?? 2
              }; 
              onUpdate(); Navigator.pop(c); 
           }, child: const Text('SAVE ARCHITECTURE')),
        ],
     )));
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, bool isDark, {bool numerical = false}) {
     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.indigoAccent, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(controller: ctrl, keyboardType: numerical ? TextInputType.number : null, decoration: InputDecoration(hintText: hint, filled: true, fillColor: isDark?Colors.white.withOpacity(0.05):Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
     ]);
  }
}
