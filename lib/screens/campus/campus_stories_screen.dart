import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_blog_screen.dart';

class CampusStoriesScreen extends StatefulWidget {
  const CampusStoriesScreen({super.key});

  @override
  State<CampusStoriesScreen> createState() => _CampusStoriesScreenState();
}

class _CampusStoriesScreenState extends State<CampusStoriesScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _stories = [];

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.from('blogs').select('*, profiles(*)').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _stories = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('STORIES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.indigoAccent), 
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBlogScreen()));
              if (res == true) _fetchStories();
            }
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Stack(
            children: [
              _buildBackgroundGlow(),
              RefreshIndicator(
                onRefresh: _fetchStories,
                child: _stories.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome_rounded, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), size: 64), const SizedBox(height: 16), Text('NO CAMPUS INTEL YET', style: GoogleFonts.outfit(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2))]))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildStoryBubbles(isDark),
                        const SizedBox(height: 32),
                        _buildSectionHeader('LATEST NEWS'),
                        const SizedBox(height: 16),
                        ..._stories.map((s) => _buildDispatchCard(s, isDark)).toList(),
                        const SizedBox(height: 100),
                      ],
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(top: -50, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.05), shape: BoxShape.circle))));
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.indigoAccent, letterSpacing: 2));
  }

  Widget _buildStoryBubbles(bool isDark) {
    // Collect unique authors from stories
    final uniqueAuthors = _stories.map((s) => s['profiles']).where((p) => p != null).toSet().toList();

    if (uniqueAuthors.length < 2) {
       uniqueAuthors.addAll([
         {'full_name': 'Chief Warden', 'avatar_url': null},
         {'full_name': 'Sports Head', 'avatar_url': null},
         {'full_name': 'Mess Team', 'avatar_url': null},
       ]);
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: uniqueAuthors.length,
        itemBuilder: (context, i) {
          final profile = uniqueAuthors[i];
          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.indigoAccent, Colors.pinkAccent])), child: CircleAvatar(radius: 28, backgroundColor: isDark ? Colors.white10 : Colors.black12, backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null, child: profile['avatar_url'] == null ? Text(profile['full_name']?[0] ?? 'S', style: TextStyle(color: isDark ? Colors.white : Colors.black)) : null)),
                const SizedBox(height: 4),
                Text(profile['full_name'] ?? 'User', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDispatchCard(dynamic s, bool isDark) {
    final profile = s['profiles'];
    final textColor = isDark ? Colors.white : Colors.black;
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: isDark ? Colors.white10 : Colors.black12, child: Text(profile?['full_name']?[0] ?? 'C', style: TextStyle(color: textColor))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(profile?['full_name'] ?? 'User', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('OFFICIAL UPDATE', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                  const Spacer(),
                  Icon(Icons.more_horiz, color: isDark ? Colors.white24 : Colors.black26),
                ],
              ),
            ),
            if (s['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(s['image_url'], width: double.infinity, height: 250, fit: BoxFit.cover, errorBuilder: (c,e,st) => const SizedBox()),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(s['title'] ?? 'New Post', style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   Text(s['content'] ?? '', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.5)),
                   const SizedBox(height: 24),
                   Row(children: [
                      _actionIcon(Icons.favorite_border_rounded, '24', isDark),
                      const SizedBox(width: 20),
                      _actionIcon(Icons.chat_bubble_outline_rounded, '8', isDark),
                      const Spacer(),
                      _actionIcon(Icons.share_rounded, '', isDark),
                   ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, bool isDark) {
    return Row(children: [Icon(icon, color: isDark ? Colors.white24 : Colors.black26, size: 20), if (label.isNotEmpty) const SizedBox(width: 6), if (label.isNotEmpty) Text(label, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12, fontWeight: FontWeight.bold))]);
  }
}
