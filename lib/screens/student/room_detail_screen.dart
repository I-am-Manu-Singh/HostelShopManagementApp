import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/hostel.dart';
import '../admin/admin_room_inspection_screen.dart';
import '../campus/hostel_browse_screen.dart';
import '../auth/login_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final HostelRoom room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _client = Supabase.instance.client;
  bool _isSaved = false;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canReview = false;
  int _currentImageIndex = 0;
  String _role = 'user';
  List<String> _galleryImages = [];
  Map<String, dynamic>? _latestInspection;
  bool _isLoadingInspection = true;

  @override
  void initState() {
    super.initState();
    _initGalleryImages();
    _checkSavedStatus();
    _checkReviewEligibility();
    _fetchReviews();
    _checkUserRole();
    _fetchLatestInspection();
  }

  Future<void> _fetchLatestInspection() async {
    try {
      final res = await _client
          .from('room_maintenance_records')
          .select('*, profiles(full_name)')
          .eq('room_id', widget.room.id)
          .order('inspection_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _latestInspection = res;
          _isLoadingInspection = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInspection = false);
    }
  }

  Future<void> _initGalleryImages() async {
    final initialList = <String>[];
    if (widget.room.imageUrl != null && widget.room.imageUrl!.isNotEmpty) {
      initialList.add(widget.room.imageUrl!);
    }
    try {
      final res = await _client.from('hostel_rooms').select('images, image_url').eq('id', widget.room.id).maybeSingle();
      if (res != null) {
        if (res['images'] is List && (res['images'] as List).isNotEmpty) {
          for (var img in (res['images'] as List)) {
            final s = img?.toString();
            if (s != null && s.isNotEmpty && !initialList.contains(s)) {
              initialList.add(s);
            }
          }
        }
        if (res['image_url'] != null && res['image_url'].toString().isNotEmpty) {
          final u = res['image_url'].toString();
          if (!initialList.contains(u)) initialList.insert(0, u);
        }
      }
    } catch (_) {}

    if (initialList.isEmpty) {
      initialList.add('https://images.unsplash.com/photo-1555854817-5b273417735e');
    }

    if (mounted) setState(() => _galleryImages = initialList);
  }

  Future<void> _checkUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) setState(() => _role = res['role'] ?? 'user');
    } catch (_) {}
  }

  Future<void> _checkSavedStatus() async {
    if (mounted) setState(() => _isSaved = false);
  }
  
  Future<void> _checkReviewEligibility() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client.from('hostel_enrollments').select('id').eq('room_id', widget.room.id).eq('user_id', user.id).limit(1);
      if (res.isNotEmpty && mounted) {
        setState(() => _canReview = true);
      }
    } catch (_) {}
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await _client
          .from('reviews')
          .select('*, profiles(full_name)')
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDark),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF08090A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        _buildHeaderSection(isDark),
                        const SizedBox(height: 24),
                        _buildQuickSpecs(cardColor, borderColor),
                        const SizedBox(height: 32),
                        _buildAboutSection(),
                        const SizedBox(height: 32),
                        _buildAmenitiesGrid(isDark, cardColor, borderColor),
                        const SizedBox(height: 32),
                        _buildInclusionsList(isDark),
                        const SizedBox(height: 32),
                        _buildInspectionStatus(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 340,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black38,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black38,
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              onPressed: () {
                Share.share('Check out Unit ${widget.room.roomNumber} on HostelShop!');
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          children: [
            Positioned.fill(
              child: _galleryImages.isEmpty
                  ? Container(
                      color: Colors.indigoAccent.withOpacity(0.1),
                      child: const Icon(Icons.bed_rounded, color: Colors.indigoAccent, size: 64),
                    )
                  : PageView.builder(
                      itemCount: _galleryImages.length,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemBuilder: (context, i) => CachedNetworkImage(
                        imageUrl: _galleryImages[i],
                        fit: BoxFit.cover,
                        errorWidget: (c, e, s) => Container(
                          color: Colors.indigoAccent.withOpacity(0.1),
                          child: const Icon(Icons.bed_rounded, color: Colors.indigoAccent, size: 64),
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            if (_galleryImages.length > 1)
              Positioned(
                bottom: 16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${_galleryImages.length}',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.room.roomType?.toUpperCase() ?? 'STANDARD',
                    style: GoogleFonts.outfit(
                      color: Colors.indigoAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostelBrowseScreen())),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'CAMPUS BLOCKS',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'UNIT ${widget.room.roomNumber}',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Colors.indigoAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              '${widget.room.wing ?? 'Main Wing'} • ${widget.room.buildingName ?? 'Block B'}',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSpecs(Color bg, Color border) {
    return Row(
      children: [
        Expanded(child: _specBox(Icons.people_outline, '${widget.room.capacity} Sharing', 'Capacity', bg, border)),
        const SizedBox(width: 12),
        Expanded(child: _specBox(Icons.ac_unit, widget.room.roomType?.toLowerCase().contains('ac') == true ? 'AC Active' : 'Non-AC', 'Climatization', bg, border)),
        const SizedBox(width: 12),
        Expanded(child: _specBox(Icons.security, '24/7 Guard', 'Safety Rating', bg, border)),
      ],
    );
  }

  Widget _specBox(IconData icon, String val, String label, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 20),
          const SizedBox(height: 8),
          Text(
            val,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT THIS UNIT',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Text(
          widget.room.description ?? 'A high-fidelity premium tactical room option engineered for peak resident comfort, smart locks, and operational productivity.',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildAmenitiesGrid(bool isDark, Color bg, Color border) {
    final list = widget.room.amenities.isNotEmpty ? widget.room.amenities : [
      'High-speed WiFi',
      'Laundry Service',
      'Attach Bathroom',
      'Private Balcony',
      'Study Table',
      'Smart Lock'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCLUDED AMENITIES',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.5,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      list[i],
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInclusionsList(bool isDark) {
    final inclusions = [
      {'label': 'HIGH-SPEED WIFI', 'status': true},
      {'label': 'STUDY DESK & CHAIR', 'status': true},
      {'label': 'SMART LOCK ACCESS', 'status': true},
      {'label': 'ATTACHED BATHROOM', 'status': true},
      {'label': '24/7 MAINTENANCE', 'status': true},
      {'label': 'LAUNDRY SERVICE', 'status': false},
      {'label': 'MEAL SUBSCRIPTION', 'status': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STANDARD POLICIES & BILLING',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        ...inclusions.map((inc) {
          final status = inc['status'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.03)),
            ),
            child: Row(
              children: [
                Icon(
                  status ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  color: status ? Colors.greenAccent : Colors.redAccent.withOpacity(0.5),
                  size: 15,
                ),
                const SizedBox(width: 12),
                Text(
                  inc['label'].toString(),
                  style: GoogleFonts.outfit(
                    color: status ? Colors.white70 : Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  status ? 'INCLUDED' : 'METERED / ADD-ON',
                  style: TextStyle(
                    color: status ? Colors.greenAccent : Colors.white24,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInspectionStatus(bool isDark) {
    final status = _latestInspection?['status']?.toString().toUpperCase() ?? 'CERTIFIED';
    final isOk = status == 'OK' || status == 'CERTIFIED';
    final isAttention = status == 'NEEDS_ATTENTION' || status == 'REPAIR_SCHEDULED';
    final statusColor = isOk ? Colors.greenAccent : (isAttention ? Colors.orangeAccent : Colors.redAccent);
    
    final desc = _latestInspection?['issue_description']?.toString();
    final resolution = _latestInspection?['resolution_details']?.toString();
    final inspectDate = _latestInspection?['inspection_date'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(_latestInspection!['inspection_date']))
        : 'Recently verified';
    final inspector = _latestInspection?['profiles']?['full_name']?.toString() ?? 'Campus Facilities Team';

    final isAdmin = _role == 'admin' || _role == 'hostel_manager' || _role == 'owner';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOk ? Icons.verified_user_rounded : Icons.report_problem_rounded, color: statusColor, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'INSPECTION STATUS: $status',
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          inspectDate,
                          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc != null && desc.isNotEmpty
                          ? desc
                          : 'Passed lock grid, plumbing nodes, and electrical checkups for immediate move-in.',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11),
                    ),
                    if (resolution != null && resolution.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Resolution: $resolution', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 2),
                    Text('Inspector: $inspector', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ADMIN MAINTENANCE CONTROLS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRoomInspectionScreen()));
                    _fetchLatestInspection();
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 14, color: Colors.indigoAccent),
                  label: const Text('EDIT / AUDIT ROOM', style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16181A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STARTING FROM', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('₹${widget.room.basePrice.toInt()}/mo', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showBookingSheet(context, isDark),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'ENROLL / BOOK NOW',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookingSheet(BuildContext context, bool isDark) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16181A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('STUDENT ACCOUNT REQUIRED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14, letterSpacing: 1.5)),
          content: Text('Please log in or create an account to proceed with room allotment and optional service add-ons.', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('LOG IN NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double totalMonthly = widget.room.basePrice;
        final selectedAddons = <String>{};
        List<dynamic> feePackages = [];
        bool isLoadingFees = true;

        int currentStep = 1; 
        String selectedPaymentMethod = 'Wallet';
        File? upiScreenshot;
        bool isProcessingCheckout = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (isLoadingFees) {
              client.from('fee_structure').select().then((res) {
                setSheetState(() {
                  feePackages = res;
                  isLoadingFees = false;
                });
              }).catchError((_) {
                setSheetState(() {
                  isLoadingFees = false;
                });
              });

              return Container(
                height: 400,
                decoration: const BoxDecoration(
                  color: Color(0xFF16181A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: const Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
              );
            }

            final roomTypeLower = (widget.room.roomType ?? '').toLowerCase();
            final addonsOnly = feePackages.where((p) {
              if (p['category'] == 'Rent') return false;
              final targetRoomType = (p['applicable_room_type'] ?? p['room_type'] ?? 'all').toString().toLowerCase();
              if (targetRoomType != 'all' && targetRoomType.isNotEmpty) {
                return targetRoomType == roomTypeLower || roomTypeLower.contains(targetRoomType);
              }
              return true;
            }).toList();

            if (currentStep == 1) {
              return Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF16181A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'BOOKING & INCLUSIONS',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UNIT ${widget.room.roomNumber} • ${widget.room.buildingName?.toUpperCase() ?? 'CAMPUS BLOCK'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'SELECT OPTIONAL SERVICE ADD-ONS',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      ...addonsOnly.map((pkg) {
                        final name = pkg['service_name'];
                        final price = (pkg['price'] as num?)?.toDouble() ?? 0.0;
                        final isSelected = selectedAddons.contains(name);
                        final isMess = pkg['category'] == 'Mess';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.indigoAccent.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? Colors.indigoAccent : Colors.transparent),
                          ),
                          child: CheckboxListTile(
                            activeColor: Colors.indigoAccent,
                            title: Text(
                              name.toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Text(
                              isMess ? 'Includes Mess Card / Meal QR access' : 'Standard monthly campus add-on',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                            secondary: Text(
                              '₹${price.toInt()}/mo',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.indigoAccent),
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  selectedAddons.add(name);
                                  totalMonthly += price;
                                } else {
                                  selectedAddons.remove(name);
                                  totalMonthly -= price;
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL MONTHLY ESTIMATE', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('₹${totalMonthly.toInt()}/mo', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setSheetState(() {
                                currentStep = 2;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text('PROCEED TO CHECKOUT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            if (currentStep == 2) {
              return Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF16181A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'SECURE CHECKOUT & ALLOTMENT',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Allotment Price', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('₹${totalMonthly.toInt()}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('CHOOSE PAYMENT METHOD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => selectedPaymentMethod = 'Wallet'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selectedPaymentMethod == 'Wallet' ? Colors.indigoAccent.withOpacity(0.1) : Colors.white.withOpacity(0.01),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selectedPaymentMethod == 'Wallet' ? Colors.indigoAccent : Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text('Wallet', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => selectedPaymentMethod = 'UPI'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selectedPaymentMethod == 'UPI' ? Colors.indigoAccent.withOpacity(0.1) : Colors.white.withOpacity(0.01),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selectedPaymentMethod == 'UPI' ? Colors.indigoAccent : Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.qr_code_scanner_outlined, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text('UPI / QR', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => selectedPaymentMethod = 'Cash'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selectedPaymentMethod == 'Cash' ? Colors.indigoAccent.withOpacity(0.1) : Colors.white.withOpacity(0.01),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selectedPaymentMethod == 'Cash' ? Colors.indigoAccent : Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.payments_outlined, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text('Cash', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (selectedPaymentMethod == 'UPI') ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.network(
                              'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=hostelshop@upi&pn=HostelShop&am=${totalMonthly.toInt()}',
                              height: 120,
                              width: 120,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(child: Text('SCAN TO PAY VIA ANY UPI APP', style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 16),
                        ListTile(
                          tileColor: Colors.white.withOpacity(0.02),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.cloud_upload_outlined, color: Colors.indigoAccent),
                          title: const Text('UPLOAD PAYMENT SCREENSHOT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          subtitle: Text(upiScreenshot != null ? 'Screenshot Attached' : 'Tap to pick proof from gallery', style: const TextStyle(color: Colors.white30, fontSize: 9)),
                          onTap: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.gallery);
                            if (img != null) {
                              setSheetState(() {
                                upiScreenshot = File(img.path);
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setSheetState(() => currentStep = 1),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('BACK', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isProcessingCheckout ? null : () async {
                                setSheetState(() {
                                  isProcessingCheckout = true;
                                });

                                try {
                                  // 1. Wallet balance check & deduction if Wallet payment
                                  if (selectedPaymentMethod == 'Wallet') {
                                    final pRes = await client.from('profiles').select('balance').eq('id', user.id).single();
                                    final curBal = (pRes['balance'] as num? ?? 0.0).toDouble();
                                    if (curBal < totalMonthly) {
                                      throw Exception('Insufficient wallet balance. Please top up your wallet or choose UPI/Cash.');
                                    }
                                    await client.from('profiles').update({
                                      'balance': curBal - totalMonthly,
                                    }).eq('id', user.id);
                                  }

                                  // 2. Upload UPI Screenshot if provided
                                  String? screenshotUrl;
                                  if (upiScreenshot != null) {
                                    try {
                                      final fileName = 'proof_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      await client.storage.from('payment-proofs').upload(fileName, upiScreenshot!);
                                      screenshotUrl = client.storage.from('payment-proofs').getPublicUrl(fileName);
                                    } catch (uploadErr) {
                                      debugPrint('Storage upload failed: $uploadErr');
                                    }
                                  }

                                  // 3. Upsert Hostel Enrollment
                                  final Map<String, dynamic> selectedPackages = {
                                    'room_plan': widget.room.roomType ?? 'Standard',
                                    'add_ons': selectedAddons.toList(),
                                  };

                                  final isPaid = selectedPaymentMethod == 'Wallet';
                                  await client.from('hostel_enrollments').upsert({
                                    'user_id': user.id,
                                    'room_id': widget.room.id,
                                    'total_price': totalMonthly,
                                    'paid_amount': isPaid ? totalMonthly : 0.0,
                                    'status': isPaid ? 'Active' : 'Pending',
                                    'payment_status': isPaid ? 'Approved' : 'Pending',
                                    'selected_packages': selectedPackages,
                                    'created_at': DateTime.now().toIso8601String(),
                                  }, onConflict: 'user_id');

                                  // 4. Record in fiscal_collections & payment_approvals
                                  try {
                                    await client.from('fiscal_collections').insert({
                                      'user_id': user.id,
                                      'amount': totalMonthly,
                                      'collection_type': 'Rent',
                                      'payment_method': selectedPaymentMethod,
                                      'notes': 'Room allotment for Unit ${widget.room.roomNumber}',
                                    });
                                  } catch (_) {}

                                  if (!isPaid) {
                                    try {
                                      await client.from('payment_approvals').insert({
                                        'user_id': user.id,
                                        'amount': totalMonthly,
                                        'payment_type': 'Rent',
                                        'status': 'Pending',
                                        'screenshot_url': screenshotUrl,
                                        'notes': 'Room Allotment Unit ${widget.room.roomNumber}',
                                      });
                                    } catch (_) {}
                                  }

                                  // 5. Update mess card if mess package included
                                  if (selectedAddons.any((addon) => addon.toUpperCase().contains('MESS'))) {
                                    final expiry = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0];
                                    await client.from('mess_cards').upsert({
                                      'user_id': user.id,
                                      'card_number': 'MESS-${user.id.substring(0, 8).toUpperCase()}',
                                      'status': 'Active',
                                      'expiry_date': expiry,
                                      'meals_allowed': ['B', 'L', 'T', 'D'],
                                      'is_nfc_synced': false,
                                      'temp_balance': 0.0,
                                      'last_sync_at': DateTime.now().toIso8601String(),
                                    }, onConflict: 'user_id');
                                  }

                                  // 6. Mark room active
                                  await client.from('hostel_rooms').update({
                                    'is_active': true, 
                                  }).eq('id', widget.room.id);

                                  setSheetState(() {
                                    isProcessingCheckout = false;
                                    currentStep = 3;
                                  });
                                } catch (e) {
                                  setSheetState(() {
                                    isProcessingCheckout = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Checkout failed: $e'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: isProcessingCheckout
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : Text('AUTHORIZE & PAY', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Color(0xFF16181A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    'ALLOTMENT CONFIRMED',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unit ${widget.room.roomNumber} is now registered under your student dossier profile.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchReviews();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('DISMISS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}