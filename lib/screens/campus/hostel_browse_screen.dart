import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../models/hostel.dart';
import '../student/room_detail_screen.dart';

class HostelBrowseScreen extends StatefulWidget {
  const HostelBrowseScreen({super.key});

  @override
  State<HostelBrowseScreen> createState() => _HostelBrowseScreenState();
}

class _HostelBrowseScreenState extends State<HostelBrowseScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _blocks = [];

  @override
  void initState() {
    super.initState();
    _fetchBlocks();
  }

  Future<void> _fetchBlocks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('hostel_rooms').select('building_name, floor').eq('is_active', true);
      
      final Map<String, Set<int>> blockMap = {};
      for (var r in (response as List)) {
        final b = r['building_name'] ?? 'Main Block';
        final f = int.tryParse(r['floor']?.toString() ?? '0') ?? 0;
        if (!blockMap.containsKey(b)) blockMap[b] = {};
        blockMap[b]!.add(f);
      }

      final List<Map<String, dynamic>> list = [];
      blockMap.forEach((k, v) {
        list.add({
          'name': k,
          'floors': v.toList()..sort(),
          'image': 'https://images.unsplash.com/photo-1555854817-5b273417735e' // Default architectural placeholder
        });
      });

      if (mounted) setState(() { _blocks = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('HOSTEL ARCHITECTURE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _blocks.length,
            itemBuilder: (context, i) => _buildBlockCard(_blocks[i], isDark),
          ),
    );
  }

  Widget _buildBlockCard(Map<String, dynamic> block, bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelRoomListScreen(blockName: block['name']))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: Image.network(block['image'], height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(block['name'].toUpperCase(), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.indigoAccent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${block['floors'].length} OPERATIONAL LEVELS', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: (block['floors'] as List).take(5).map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('L$f', style: const TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HostelRoomListScreen extends StatefulWidget {
  final String blockName;
  const HostelRoomListScreen({super.key, required this.blockName});

  @override
  State<HostelRoomListScreen> createState() => _HostelRoomListScreenState();
}

class _HostelRoomListScreenState extends State<HostelRoomListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<HostelRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('hostel_rooms').select().eq('building_name', widget.blockName).order('room_number');
      if (mounted) {
        setState(() {
          _rooms = (res as List).map((r) => HostelRoom.fromJson(r)).toList();
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.blockName} UNITS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
            itemCount: _rooms.length,
            itemBuilder: (context, i) => _buildRoomCard(_rooms[i], isDark),
          ),
    );
  }

  Widget _buildRoomCard(HostelRoom room, bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room))),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(room.imageUrl ?? 'https://images.unsplash.com/photo-1555854817-5b273417735e', width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.indigoAccent.withOpacity(0.1), child: const Icon(Icons.bed_rounded, color: Colors.indigoAccent))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNIT ${room.roomNumber}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(room.roomType?.toUpperCase() ?? 'STANDARD', style: TextStyle(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('₹${room.basePrice.toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white24),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
