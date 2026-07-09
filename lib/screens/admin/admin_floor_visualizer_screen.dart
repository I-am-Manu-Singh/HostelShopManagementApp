import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;

class AdminFloorVisualizerScreen extends StatefulWidget {
  final String blockName;
  const AdminFloorVisualizerScreen({super.key, required this.blockName});

  @override
  State<AdminFloorVisualizerScreen> createState() => _AdminFloorVisualizerScreenState();
}

class _AdminFloorVisualizerScreenState extends State<AdminFloorVisualizerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _rooms = [];
  List<dynamic> _enrollments = [];

  // 🧪 Architectural 2.5D State
  double _rotationX = 0.3; // Slight tilt for depth
  double _rotationY = 0.0; // Front facing
  double _zoom = 0.85; 
  double _verticalSpread = 450.0; 
  double _focusRoomIndex = 0.0; // 🧬 Horizontal Focus
  double _focusFloor = 0.0;
  int _activeFloor = 0;
  
  // 🕹️ Spatial Translation State
  double _translateX = 0.0;
  double _translateY = 0.0;
  double _swipeAccumulator = 0.0; // 🎡 Smooth Scroll Accumulator

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final roomsRes = await _supabase.from('hostel_rooms').select().eq('building_name', widget.blockName).order('floor', ascending: true);
      
      // 🧬 MISSION-CRITICAL: Explicit Focal Mapping
      final List<dynamic> roomIds = (roomsRes as List).map((r) => r['id']).toList();
      final enrollRes = await _supabase.from('hostel_enrollments').select('*, profiles(*)').inFilter('room_id', roomIds);
      
      if (mounted) {
        setState(() {
          _rooms = roomsRes;
          _enrollments = enrollRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deployment Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final scaffoldBg = isDark ? const Color(0xFF08090A) : const Color(0xFFF8FAFC);

    final groupedRooms = groupBy(_rooms, (dynamic r) => int.tryParse(r['floor']?.toString() ?? '0') ?? 0);
    final sortedFloors = groupedRooms.keys.toList()..sort();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${widget.blockName.toUpperCase()} // ARCH_V4', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent), onPressed: _fetchData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : Column(
            children: [
               _buildLegend(isDark),
               Expanded(
                 child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _swipeAccumulator = 0,
                  onScaleUpdate: (details) {
                    setState(() {
                      if (details.pointerCount == 1) {
                          // 🏁 DOMINANT AXIS LOCKING Logic
                          if (details.focalPointDelta.dy.abs() > details.focalPointDelta.dx.abs()) {
                             // Vertical Workflow -> Circular Floor Scrolling
                             _swipeAccumulator += details.focalPointDelta.dy;
                             if (_swipeAccumulator.abs() > 25) { 
                                if (_swipeAccumulator > 0) {
                                   if (_activeFloor > 0) _activeFloor--;
                                } else {
                                   if (_activeFloor < sortedFloors.length - 1) _activeFloor++;
                                }
                                _swipeAccumulator = 0;
                             }
                          } else {
                             // Horizontal Workflow -> Screen-Space Panning
                             _translateX += details.focalPointDelta.dx / _zoom;
                          }
                       } else if (details.pointerCount == 2) {
                         _rotationY += details.focalPointDelta.dx * 0.003;
                         _rotationX -= details.focalPointDelta.dy * 0.003;
                         if (_rotationX > 1.8) _rotationX = 1.8;
                         if (_rotationX < 0.2) _rotationX = 0.2;
                         if (details.scale != 1.0) {
                            _zoom *= details.scale;
                            if (_zoom < 0.3) _zoom = 0.3;
                            if (_zoom > 2.5) _zoom = 2.5;
                         }
                      }
                    });
                  },
                   child: Stack(
                     alignment: Alignment.center,
                     children: [
                       _buildGridLines(isDark),
                       TweenAnimationBuilder<double>(
                         tween: Tween(begin: _focusFloor, end: _activeFloor.toDouble()),
                         duration: const Duration(milliseconds: 500),
                         curve: Curves.easeOutCubic,
                         builder: (context, focus, child) {
                           return Center(
                             child: Transform(
                               alignment: Alignment.center,
                               transform: Matrix4.identity()
                                 ..scale(_zoom)
                                 ..translate(_translateX, _translateY, 0.0),
                               child: Transform(
                                 alignment: Alignment.center,
                                 transform: Matrix4.identity()
                                   ..setEntry(3, 2, 0.0004) // Shallower perspective for better visibility
                                   ..rotateX(_rotationX)
                                   ..rotateY(_rotationY)
                                   ..translate(0.0, focus * _verticalSpread, 0.0), // 🛗 VERTICAL BUILDING OFFSET
                                 child: Stack(
                                   alignment: Alignment.center,
                                   children: [
                                     _buildLiftShaft(sortedFloors.length, isDark),
                                     _buildBuildingEnvelope(sortedFloors.length, isDark),
                                     ...sortedFloors.map((f) {
                                        int index = sortedFloors.indexOf(f);
                                        return _build3DFloorLayer(f, index, groupedRooms[f]!, isDark, focus);
                                     }),
                                     _buildRoof(sortedFloors.length, isDark),
                                   ],
                                 ),
                               ),
                             ),
                           );
                         },
                       ),
                       Positioned(left: 12, top: 100, child: _buildLiftPanel(sortedFloors, isDark)),
                       Positioned(bottom: 20, left: 80, right: 80, child: _buildHorizontalLadder(groupedRooms[_activeFloor] ?? [], isDark)),
                       Positioned(bottom: 20, right: 16, child: _buildControls(isDark)),
                     ],
                   ),
                 ),
               ),
            ],
          ),
    );
  }

  Widget _buildLiftShaft(int floorCount, bool isDark) {
    if (floorCount == 0) return const SizedBox();
    final height = (floorCount) * _verticalSpread;
    return Stack(
      alignment: Alignment.center,
      children: [
        // 🏛️ The Fixed Glide Shaft
        Transform(
          transform: Matrix4.identity()..translate(-220.0, - (height / 2) + 150, -100.0),
          child: Container(
            width: 80, height: height + 300,
            decoration: BoxDecoration(
              color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.05),
              border: Border.all(color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.15), width: 1),
            ),
          ),
        ),
        // 🛗 The Elevation-Synced Car
        AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          top: (floorCount - 1 - _activeFloor) * _verticalSpread - (height / 2) + 120,
          child: Transform(
             transform: Matrix4.identity()..translate(-220.0, 0, -100.0),
             child: Container(
               width: 70, height: 100,
               decoration: BoxDecoration(
                 color: Colors.blueAccent.withOpacity(0.35),
                 borderRadius: BorderRadius.circular(15),
                 border: Border.all(color: Colors.blueAccent, width: 2),
                 boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 30, spreadRadius: 4)],
               ),
               child: const Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 14),
                   Icon(Icons.security_rounded, color: Colors.white, size: 24),
                   Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 14),
                 ],
               ),
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLiftIndicator(int unitCount, bool isDark) {
    if (unitCount == 0) return const SizedBox();
    final double width = unitCount * 85.0;
    return Transform(
      transform: Matrix4.identity()..translate(0.0, - (_activeFloor * _verticalSpread) + 120, -110.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: width, height: 4, decoration: BoxDecoration(color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.05), borderRadius: BorderRadius.circular(2))),
          AnimatedPositioned(
             duration: const Duration(milliseconds: 600),
             curve: Curves.easeOutCubic,
             left: (width / 2) + (_focusRoomIndex * 84.0) - (width / 2) - 15, // 🧬 Precise structural alignment
             child: Container(width: 30, height: 12, decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 1), boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 20)])),
          ),
        ],
      ),
    );
  }

  Widget _buildRoof(int floorCount, bool isDark) {
    return Transform(
       transform: Matrix4.identity()..translate(0.0, - (floorCount * _verticalSpread), 10.0 * floorCount),
       child: Container(
         width: 360, height: 200,
         decoration: BoxDecoration(
           color: (isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.indigoAccent.withOpacity(0.2)),
           borderRadius: BorderRadius.circular(40),
           border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 3),
         ),
         child: Center(child: Text('BLOCK ROOF', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 4))),
       ),
    );
  }

  Widget _buildLiftPanel(List<int> floors, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
          child: Text('CORE_LIFT', style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        const SizedBox(height: 24),
        ...floors.reversed.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: GestureDetector(
            onTap: () => setState(() => _activeFloor = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutExpo,
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _activeFloor == f ? Colors.blueAccent : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
                shape: BoxShape.circle,
                border: Border.all(color: _activeFloor == f ? Colors.white.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.1), width: 1),
                boxShadow: [_activeFloor == f ? BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 15, spreadRadius: -2) : const BoxShadow()],
              ),
              child: Center(child: Text('$f', style: GoogleFonts.outfit(color: _activeFloor == f ? Colors.white : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11))),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildHorizontalLadder(List<dynamic> currentFloorRooms, bool isDark) {
    if (currentFloorRooms.isEmpty) return const SizedBox();
    return Container(
      height: 45,
      decoration: BoxDecoration(color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.blueAccent.withOpacity(0.08))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: currentFloorRooms.map((r) {
             return GestureDetector(
                onTap: () {
                   final int index = currentFloorRooms.indexOf(r);
                   setState(() {
                      _focusRoomIndex = index.toDouble();
                      _translateX = - (index * 80.0) + (currentFloorRooms.length * 10);
                   });
                },
                child: AnimatedContainer(
                   duration: const Duration(milliseconds: 400),
                   margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                   padding: const EdgeInsets.symmetric(horizontal: 10),
                   decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                   ),
                   child: Center(child: Text(r['room_number'] ?? '?', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 9))),
                ),
             );
          }).toList(),
        ),
      ),
    );
  }


  Widget _buildBuildingEnvelope(int floorCount, bool isDark) {
    if (floorCount == 0) return const SizedBox();
    final height = (floorCount - 1) * _verticalSpread + 60;
    final color = (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.15);
    return Stack(
      children: [
        ...[const Offset(-175, -85), const Offset(175, -85), const Offset(-175, 85), const Offset(175, 85)].map((off) => Transform(
          transform: Matrix4.identity()..translate(off.dx, - (height / 2) + 120, off.dy),
          child: Container(
            width: 6, height: height + 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withOpacity(0.01)]),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15)],
            ),
          ),
        )),
        Transform(
          transform: Matrix4.identity()..translate(0.0, - (height / 2) + 120, 90.0),
          child: Container(
            width: 350, height: height + 300,
            decoration: BoxDecoration(
              color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.01),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.12), width: 0.5),
              boxShadow: [BoxShadow(color: (isDark ? Colors.blueAccent : Colors.indigoAccent).withOpacity(0.08), blurRadius: 60, spreadRadius: 10)],
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.0), Colors.blueAccent.withOpacity(0.04), Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.0)], stops: const [0.0, 0.45, 0.5, 1.0]),
            ),
          ),
        ),
        ...List.generate(floorCount, (i) => Transform(
          transform: Matrix4.identity()..translate(0.0, - (i * _verticalSpread), 0.0),
          child: Container(
            width: 350, height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 5))],
            ),
          ),
        )),
      ],
    );
  }

  Widget _build3DFloorLayer(int floorId, int index, List<dynamic> floorRooms, bool isDark, double focus) {
    if (floorRooms.isEmpty) return const SizedBox();
    final int third = (floorRooms.length / 3).ceil();
    final row1 = floorRooms.take(third).toList();
    final row2 = floorRooms.skip(third).take(third).toList();
    final row3 = floorRooms.skip(2 * third).toList();

    // 📏 LINEAR STRUCTURAL Logic
    final double diff = index - focus;
    final double finalY = index * - _verticalSpread;
    
    // 🧬 Sublte 2.5D Depth
    final double zPos = - (diff.abs() * 60.0); 
    
    final double scale = (1.0 - (diff.abs() * 0.05)).clamp(0.8, 1.0);
    final double opacity = (1.0 - (diff.abs() * 0.15)).clamp(0.4, 1.0); // 🏁 High Visibility

    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, finalY, zPos) 
        ..scale(scale),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 380, height: 320, // Expanded for triple rows
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.15), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4 * opacity), blurRadius: 50, offset: const Offset(0, 20))],
              ),
              child: CustomPaint(painter: FloorGridPainter(isDark: isDark)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: row1.map((r) => _buildSimpleUnit(r, isDark)).toList()),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: row2.map((r) => _buildSimpleUnit(r, isDark)).toList()),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: row3.map((r) => _buildSimpleUnit(r, isDark)).toList()),
                ],
              ),
            ),
            Positioned(left: -120, child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateX(-_rotationX),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withOpacity(0.2))), child: Text(floorId == 0 ? 'GROUND' : 'LEVEL $floorId', style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2))),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleUnit(dynamic r, bool isDark) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _build3DUnit(r, isDark));

  Widget _buildWing(List<dynamic> rooms, bool isDark, bool isLeft) {
    return Column(mainAxisSize: MainAxisSize.min, children: rooms.map((r) => _build3DUnit(r, isDark)).toList());
  }

  Widget _build3DUnit(dynamic r, bool isDark) {
    final String targetId = r['id']?.toString() ?? '';
    final enroll = _enrollments.firstWhereOrNull((e) {
      final String? rid = e['room_id']?.toString();
      final String? hrid = e['hostel_rooms']?['id']?.toString();
      return rid == targetId || hrid == targetId;
    });

    final isOccupied = enroll != null;
    final accent = isOccupied ? Colors.blueAccent : Colors.transparent;
    final unitColor = isDark ? Colors.white10 : Colors.black12;

    // 🎓 Extract Student Metadata
    final profile = enroll?['profiles'];
    final String? avatarUrl = profile != null ? profile['avatar_url'] : null;
    final String fullName = profile != null ? (profile['full_name'] ?? 'N/A') : 'N/A';
    final String firstName = fullName.split(' ')[0].toUpperCase();

    return GestureDetector(
      onTap: () => _showRoomDetails(r, enroll, isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform(transform: Matrix4.identity()..translate(2.0, 4.0, -4.0), child: Container(width: 65, height: 75, decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(15)))),
            Container(
              width: 65, height: 75,
              decoration: BoxDecoration(
                color: isOccupied ? accent.withOpacity(0.9) : (isDark ? const Color(0xFF16181A) : Colors.white),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isOccupied ? Colors.white.withOpacity(0.6) : unitColor.withOpacity(0.6), width: 1.5),
                boxShadow: [if (isOccupied) ...[BoxShadow(color: accent.withOpacity(0.5), blurRadius: 25, spreadRadius: 2)]],
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateX(-_rotationX),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      if (isOccupied) ...[
                        if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
                           CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatarUrl), backgroundColor: Colors.white24),
                        ] else ...[
                           const Icon(Icons.person, color: Colors.white70, size: 18),
                        ],
                        const SizedBox(height: 6),
                        Text(r['room_number'] ?? '?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4), 
                          child: Text(firstName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ] else ...[
                        Text(r['room_number'] ?? '?', style: GoogleFonts.outfit(color: (isDark ? Colors.white38 : Colors.black38), fontWeight: FontWeight.w900, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _controlBtn(Icons.add_rounded, () => setState(() => _zoom += 0.1)),
        const SizedBox(height: 8),
        _controlBtn(Icons.remove_rounded, () => setState(() => _zoom -= 0.1)),
        const SizedBox(height: 8),
        _controlBtn(Icons.layers_rounded, () => setState(() => _verticalSpread = (_verticalSpread == 480.0 ? 320.0 : 480.0))),
        const SizedBox(height: 12),
        IconButton(onPressed: () => setState(() { 
          _rotationX = 0.3; _rotationY = 0.0; _zoom = 0.85; _verticalSpread = 450.0; _activeFloor = 0; _translateX = 0.0; _translateY = 0.0;
        }), icon: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.greenAccent, size: 20)),
        _controlBtn(Icons.biotech_rounded, () => _showTacticalScanner(isDark)),
      ],
    );
  }

  Widget _controlBtn(IconData i, VoidCallback onTap) => Container(width: 32, height: 32, decoration: BoxDecoration(color: (Colors.blueAccent).withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withOpacity(0.1))), child: IconButton(padding: EdgeInsets.zero, icon: Icon(i, color: Colors.blueAccent, size: 16), onPressed: onTap));

  Widget _naturalViewBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.greenAccent.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 20)]),
      child: Column(children: [const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.greenAccent, size: 20), const SizedBox(height: 6), Text('NATURAL VIEW', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))]),
    ),
  );

  Widget _tacticalHudIcon(bool isDark) => _controlBtn(Icons.biotech_rounded, () => _showTacticalScanner(isDark));

  void _showTacticalScanner(bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF08090A) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('STRUCTURAL_SCANNER', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        const SizedBox(height: 20),
        TextField(
          onChanged: (val) {
             final room = _rooms.firstWhereOrNull((r) => r['room_number'] == val);
             if (room != null) {
                setState(() {
                  _activeFloor = int.tryParse(room['floor']?.toString() ?? '0') ?? 0;
                  _translateX = 0; _translateY = 0;
                });
             }
          },
          decoration: InputDecoration(hintText: 'ENTER UNIT ID (e.g. 101)', prefixIcon: const Icon(Icons.search, color: Colors.blueAccent), filled: true, fillColor: Colors.blueAccent.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 20),
        Text('Real-time architectural indexing enabled.', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10)),
      ]),
    ));
  }

  Widget _buildLegend(bool isDark) {
    return Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [_legendItem('VACANT', isDark ? Colors.white12 : Colors.black12), const SizedBox(width: 24), _legendItem('OCCUPIED', Colors.blueAccent)]));
  }

  Widget _legendItem(String l, Color c) => Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 10), Text(l, style: GoogleFonts.outfit(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))]);

  Widget _buildGridLines(bool isDark) => IgnorePointer(child: Center(child: Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(color: Colors.transparent))));

  void _showRoomDetails(dynamic r, dynamic enroll, bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: isDark?const Color(0xFF08090A):Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UNIT ${r['room_number']}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900)), Text('Operational Intelligence Dispatch', style: TextStyle(color: isDark?Colors.white24:Colors.black26, fontSize: 9, fontWeight: FontWeight.bold))]), const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 28)]),
      const SizedBox(height: 32),
      if (enroll == null) _infoTile('STATUS', 'VACANT / MISSION READY', Colors.greenAccent, isDark)
      else ...[_infoTile('OCCUPANT', (enroll['profiles']?['full_name'] ?? 'TERMINAL_USER').toString().toUpperCase(), Colors.blueAccent, isDark), _infoTile('DUE BALANCE', '₹${((double.tryParse(enroll['total_price'].toString()) ?? 0) - (double.tryParse(enroll['paid_amount'].toString()) ?? 0)).toInt()}', Colors.redAccent, isDark), _infoTile('CHECK-IN', enroll['created_at'].toString().split('T')[0], Colors.tealAccent, isDark)],
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('DISMISS'))),
    ])));
  }

  Widget _infoTile(String l, String v, Color c, bool isDark) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(color: isDark?Colors.white12:Colors.black12, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)), Text(v, style: GoogleFonts.outfit(color: c, fontSize: 13, fontWeight: FontWeight.bold))]));
  }
}

class FloorGridPainter extends CustomPainter {
  final bool isDark;
  FloorGridPainter({required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = RadialGradient(colors: [(isDark ? Colors.white : Colors.black).withOpacity(0.08), (isDark ? Colors.white : Colors.black).withOpacity(0.01)]).createShader(rect)..strokeWidth = 0.5;
    double step = 25;
    for (double i = 0; i <= size.width; i += step) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i <= size.height; i += step) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    final glowPaint = Paint()..color = Colors.blueAccent.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), glowPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
