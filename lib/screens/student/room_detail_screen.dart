import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/hostel.dart';
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../add_review_screen.dart';
import '../web_view_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import '../chat_screen.dart';
import '../../widgets/user_avatar.dart';

class RoomDetailScreen extends StatefulWidget {
  final HostelRoom room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canReview = false;
  int _currentImageIndex = 0;
  final ScreenshotController _screenshotController = ScreenshotController();
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkSavedStatus();
    _checkReviewEligibility();
    _fetchReviews();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) setState(() => _role = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    // Re-linking to hostel preferences
    if (mounted) setState(() => _isSaved = false);
  }
  
  Future<void> _checkReviewEligibility() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client.from('hostel_enrollments').select('id').eq('room_id', widget.room.id).eq('user_id', user.id).limit(1);
      if (res.isNotEmpty && mounted) {
        setState(() => _canReview = true);
      }
    } catch (_) {}
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('hostel_id', widget.room.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _reviews = response as List;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Desktop/Wide View: 2-column sidebar layout
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 400,
                          width: double.infinity,
                          child: _buildImageGallery(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 12),
                              _buildLocationRow(),
                              const SizedBox(height: 24),
                              _buildQuickStats(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: Colors.indigoAccent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white38,
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'OVERVIEW'),
                          Tab(text: 'AMENITIES'),
                          Tab(text: 'INCLUSIONS'),
                          Tab(text: 'INSPECTION'),
                          Tab(text: 'REVIEWS'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverview(),
                            _buildAmenities(),
                            _buildInclusions(),
                            _buildInspectionChecklist(),
                            _buildReviewsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Mobile View: Default nested scrolling list
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 400,
                  pinned: false,
                  floating: true,
                  backgroundColor: const Color(0xFF08090A),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildImageGallery(),
                  ),
                  leading: _buildAppBarAction(Icons.arrow_back, () => Navigator.pop(context)),
                  actions: [
                    _buildAppBarAction(Icons.share, () => Share.share('Join me at Unit ${widget.room.roomNumber}!')),
                    _buildAppBarAction(_isSaved ? Icons.favorite : Icons.favorite_border, () {}, color: _isSaved ? Colors.red : Colors.white),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        _buildLocationRow(),
                        const SizedBox(height: 24),
                        _buildQuickStats(),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    preferredHeight: 60,
                    child: Container(
                      color: const Color(0xFF08090A),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: Colors.indigoAccent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white38,
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'OVERVIEW'),
                          Tab(text: 'AMENITIES'),
                          Tab(text: 'INCLUSIONS'),
                          Tab(text: 'INSPECTION'),
                          Tab(text: 'REVIEWS'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildAmenities(),
                _buildInclusions(),
                _buildInspectionChecklist(),
                _buildReviewsTab(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBarAction(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNIT ${widget.room.roomNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '4.8 (120 reviews)',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(width: 10),

      /// PRICE BOX (shrink-safe)
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigoAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '₹${widget.room.basePrice.toInt()}/mo',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildLocationRow() {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.indigoAccent, size: 18),
        const SizedBox(width: 8),
        Text('${widget.room.wing ?? 'Main Wing'} • Block B', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
      ],
    );
  }

Widget _buildQuickStats() {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _quickStat(Icons.people_outline, '3 Sharing', 'Capacity'),
      _quickStat(Icons.ac_unit, 'AC Room', 'Type'),
      _quickStat(Icons.security, '24/7 Guard', 'Safety'),
    ],
  );
}

  Widget _quickStat(IconData icon, String val, String label) {
  return Container(
    width: 100,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      children: [
        Icon(icon, color: Colors.white24, size: 18),
        const SizedBox(height: 6),
        Text(
          val,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildImageGallery() {
    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: widget.room.imageUrl ?? 'https://images.unsplash.com/photo-1555854817-5b2247a8175f?q=80&w=1000',
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeInUp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ABOUT THIS UNIT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(widget.room.description ?? 'A high-fidelity tactical unit engineered for peak resident performance and operational comfort.', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 15, height: 1.6)),
            const SizedBox(height: 32),
            Text('FLOOR PLAN', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: const Icon(Icons.map_outlined, color: Colors.indigoAccent, size: 40),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildAmenities() {
  final list = [
    'High-speed WiFi',
    'Laundry Service',
    'Attach Bathroom',
    'Private Balcony',
    'Study Table',
    'Smart Lock'
  ];

  return GridView.builder(
    padding: const EdgeInsets.all(24),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.2,
    ),
    itemCount: list.length,
    itemBuilder: (context, i) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.greenAccent, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                list[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    },
  ); // 👈 THIS WAS MISSING
}

  Widget _buildInclusions() {
    final inclusions = [
      {'label': 'HIGH-SPEED WIFI', 'status': true},
      {'label': 'STUDY DESK & CHAIR', 'status': true},
      {'label': 'SMART LOCK ACCESS', 'status': true},
      {'label': 'ATTACHED BATHROOM', 'status': true},
      {'label': '24/7 MAINTENANCE', 'status': true},
      {'label': 'LAUNDRY SERVICE', 'status': false},
      {'label': 'MEAL SUBSCRIPTION', 'status': false},
      {'label': 'ELECTRICITY (METERED)', 'status': false},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: inclusions.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.04))),
        child: Row(children: [
          Icon(inclusions[i]['status'] as bool ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, color: inclusions[i]['status'] as bool ? Colors.greenAccent : Colors.redAccent.withOpacity(0.4), size: 16),
          const SizedBox(width: 16),
          Text(inclusions[i]['label'] as String, style: GoogleFonts.outfit(color: inclusions[i]['status'] as bool ? Colors.white70 : Colors.white24, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const Spacer(),
          Text(inclusions[i]['status'] as bool ? 'INCLUDED' : 'EXCLUDED', style: TextStyle(color: inclusions[i]['status'] as bool ? Colors.greenAccent : Colors.white10, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildInspectionChecklist() {
    final checks = ['Plumbing Grid', 'Electrical Node', 'Wall Integrity', 'Lock Functionality', 'Furniture Condition'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRE-ALLOTMENT AUDIT STATUS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2)),
          const SizedBox(height: 20),
          ...checks.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [const Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 16), const SizedBox(width: 16), Text(c, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)), const Spacer(), const Text('SECURE', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900))]),
          )).toList(),
          const SizedBox(height: 32),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.assignment_turned_in_rounded, color: Colors.greenAccent, size: 16), const SizedBox(width: 12), const Expanded(child: Text('THIS UNIT HAS PASSED ALL SMART INSPECTION PROTOCOLS FOR IMMEDIATE ALLOTMENT.', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)))]))
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return _isLoadingReviews 
      ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
      : ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: _reviews.length,
          itemBuilder: (context, i) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_reviews[i]['profiles']['full_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_reviews[i]['content'], style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
        );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF16181A), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STARTING FROM', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('₹${widget.room.basePrice.toInt()}/mo', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 20),
         ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.indigoAccent,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: const Text(
    'ENROLL',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
),
        ],
      ),
    );
  }
}


class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.preferredHeight,
    required this.child,
  });

  final double preferredHeight;
  final Widget child;

  @override
  double get minExtent => preferredHeight;

  @override
  double get maxExtent => preferredHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}