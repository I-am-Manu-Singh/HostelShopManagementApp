import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import 'academic_planner_screen.dart';

class AcademicIntelligenceHubScreen extends StatefulWidget {
  const AcademicIntelligenceHubScreen({super.key});

  @override
  State<AcademicIntelligenceHubScreen> createState() => _AcademicIntelligenceHubScreenState();
}

class _AcademicIntelligenceHubScreenState extends State<AcademicIntelligenceHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseService();
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedSubject;

  List<Map<String, dynamic>> _targets = [];
  List<Map<String, dynamic>> _vault = [];
  List<Map<String, dynamic>> _doubts = [];
  List<Map<String, dynamic>> _syllabus = [];
  List<Map<String, dynamic>> _revisionQueue = [];
  List<Map<String, dynamic>> _mockScores = [];
  List<Map<String, dynamic>> _deadlines = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.fetchAcademicTargets(),
        _db.fetchKnowledgeVault(),
        _db.fetchDoubts(),
        _db.fetchSyllabus(),
        _db.fetchRevisionQueue(),
        _db.fetchMockScores(),
        _db.fetchExamDeadlines(),
      ]);
      if (mounted) {
        setState(() {
          _targets = results[0];
          _vault = results[1];
          _doubts = results[2];
          _syllabus = results[3];
          _revisionQueue = results[4];
          _mockScores = results[5];
          _deadlines = results[6];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> original) {
    return original.where((item) {
      final matchesSearch = item['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? 
                            item['content']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ??
                            item['doubt']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? true;
      final matchesSubject = _selectedSubject == null || item['subject'] == _selectedSubject;
      return matchesSearch && matchesSubject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final allSubjects = {..._vault, ..._doubts, ..._syllabus, ..._mockScores}.map((e) => e['subject'] as String?).where((e) => e != null).cast<String>().toSet().toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ACADEMIC HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search topics, notes, marks...', 
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12), 
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigoAccent, size: 20), 
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.indigoAccent,
              isScrollable: true,
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: isDark ? Colors.white24 : Colors.black26,
              labelStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'GOALS'),
                Tab(text: 'SYLLABUS'),
                Tab(text: 'NOTES'),
                Tab(text: 'DOUBTS'),
                Tab(text: 'REVISION'),
              ],
            ),
          ]),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
        : Column(
            children: [
              if (allSubjects.isNotEmpty) Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    FilterChip(
                      label: const Text('ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
                      selected: _selectedSubject == null, 
                      onSelected: (_) => setState(() => _selectedSubject = null),
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      selectedColor: Colors.indigoAccent.withOpacity(0.2),
                      checkmarkColor: Colors.indigoAccent,
                    ),
                    const SizedBox(width: 8),
                    ...allSubjects.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
                        selected: _selectedSubject == s, 
                        onSelected: (_) => setState(() => _selectedSubject = s),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        selectedColor: Colors.indigoAccent.withOpacity(0.2),
                        checkmarkColor: Colors.indigoAccent,
                      ),
                    )),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildGoalsTab(isDark),
                    _buildSyllabusTab(isDark),
                    _buildNotesTab(isDark),
                    _buildDoubtsTab(isDark),
                    _buildRevisionTab(isDark),
                  ],
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigoAccent,
        onPressed: () => _showAddDialog(isDark),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildQuickStats(isDark),
        const SizedBox(height: 32),
        _buildDeadlinesList(isDark),
        const SizedBox(height: 32),
        _buildTrendChart(isDark),
        const SizedBox(height: 32),
        _buildTabSummaries(isDark),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 60,
          child: ElevatedButton.icon(
            onPressed: () => _showAddDialog(isDark, specificType: 0),
            icon: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 20),
            label: const Text('LOG TEST SCORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
        ),
        const SizedBox(height: 32),
        _buildRecentScores(isDark),
        const SizedBox(height: 32),
        _buildPlannerBanner(isDark),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Row(
      children: [
        _miniStatusBox('TARGETS', '${_targets.where((t) => t['is_achieved'] != true).length}', Colors.indigoAccent, isDark),
        const SizedBox(width: 12),
        _miniStatusBox('DOUBTS', '${_doubts.where((d) => d['is_resolved'] != true).length}', Colors.redAccent, isDark),
        const SizedBox(width: 12),
        _miniStatusBox('REVISE', '${_revisionQueue.length}', Colors.orangeAccent, isDark),
      ],
    );
  }

  Widget _miniStatusBox(String l, String v, Color c, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        child: Column(children: [
          Text(v, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildTabSummaries(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('INTEL MODULES'),
            Text('TAP TO JUMP', style: TextStyle(color: Colors.indigoAccent.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        _overviewLinkCard('SYLLABUS PROGRESS', '${_syllabus.length} Active Exams', Icons.menu_book_rounded, Colors.pinkAccent, 2, isDark),
        _overviewLinkCard('KNOWLEDGE VAULT', '${_vault.length} Snippets', Icons.tips_and_updates_rounded, Colors.amberAccent, 3, isDark),
        _overviewLinkCard('DOUBT SOLVING', '${_doubts.where((d)=>d['is_resolved']!=true).length} Pending', Icons.help_outline_rounded, Colors.redAccent, 4, isDark),
        _overviewLinkCard('REVISION FEED', '${_revisionQueue.length} Due Today', Icons.auto_mode_rounded, Colors.orangeAccent, 5, isDark),
      ],
    );
  }

  Widget _overviewLinkCard(String t, String s, IconData i, Color c, int tabIndex, bool isDark) {
    return GestureDetector(
      onTap: () => _tabController.animateTo(tabIndex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.05))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle), child: Icon(i, color: c, size: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(s, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    // Legacy mapping or specific peak view if needed
    return const SizedBox.shrink();
  }

  Widget _emptyIntel(bool isDark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01), borderRadius: BorderRadius.circular(16)), child: Center(child: Text('NO DATA LOGGED', style: TextStyle(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), fontSize: 9, fontWeight: FontWeight.bold))));
  Widget _sectionLabel(String l) => Text(l, style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));

  Widget _buildPlannerBanner(bool isDark) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicPlannerScreen())),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BIG CALENDAR VIEW', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Plan your semester & track deadlines.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(bool isDark) {
    final filteredScores = _mockScores.where((m) => _selectedSubject == null || m['subject'] == _selectedSubject).toList();
    if (filteredScores.isEmpty) return const SizedBox.shrink();
    filteredScores.sort((a, b) => DateTime.parse(a['mock_date']).compareTo(DateTime.parse(b['mock_date'])));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_selectedSubject ?? "OVERALL"} PERFORMANCE TREND', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: filteredScores.asMap().entries.map((e) {
                    double perc = (e.value['score_obtained'] / e.value['total_score']) * 100;
                    return FlSpot(e.key.toDouble(), perc);
                  }).toList(),
                  isCurved: true,
                  color: Colors.indigoAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.indigoAccent.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlinesList(bool isDark) {
    if (_deadlines.isEmpty) return const SizedBox.shrink();
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('UPCOMING EXAMS', style: GoogleFonts.outfit(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 16),
       ..._deadlines.map((d) {
          final daysLeft = DateTime.parse(d['exam_date']).difference(DateTime.now()).inDays;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.pinkAccent.withOpacity(0.2))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(d['exam_title'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Text(DateFormat('dd MMMM yyyy').format(DateTime.parse(d['exam_date'])), style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
              ])),
              _countdownBadge(daysLeft),
            ]),
          );
       }),
    ]);
  }

  Widget _countdownBadge(int days) {
    return Column(children: [
      Text('$days', style: GoogleFonts.outfit(color: Colors.pinkAccent, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
      const Text('DAYS LEFT', style: TextStyle(color: Colors.pinkAccent, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildRecentScores(bool isDark) {
    if (_mockScores.isEmpty) return const SizedBox.shrink();
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('RECENT TEST SCORES', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
       const SizedBox(height: 16),
       ..._mockScores.take(3).map((m) {
          double perc = (m['score_obtained'] / m['total_score']) * 100;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(m['exam_name'].toString().toUpperCase(), style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                 Text(m['subject'] ?? 'Combined', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
              ])),
              Text('${m['score_obtained']}/${m['total_score']}', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (perc > 70 ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${perc.toInt()}%', style: TextStyle(color: perc > 70 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
          );
       }),
    ]);
  }

  Widget _buildGoalsTab(bool isDark) {
    final list = _filterList(_targets);
    final textColor = isDark ? Colors.white : Colors.black;
    return list.isEmpty ? _emptyState('No goals set yet') : ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final t = list[i];
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.flag_rounded, color: Colors.indigoAccent, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(t['target_type'].toString().toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 const SizedBox(height: 2),
                 Text(t['content'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
              ])),
              if (t['is_achieved'] == true) const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 24),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildSyllabusTab(bool isDark) {
    final list = _filterList(_syllabus);
    final textColor = isDark ? Colors.white : Colors.black;
    return list.isEmpty ? _emptyState('No syllabus items found') : ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(s['subject'].toString().toUpperCase(), style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(DateFormat('dd MMM').format(DateTime.parse(s['test_date'])), style: const TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold))),
              ]),
              const Divider(color: Colors.white10, height: 32),
              Wrap(spacing: 8, runSpacing: 8, children: (s['topics'] as List).map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: Text(t, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)))).toList()),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildNotesTab(bool isDark) {
    final list = _filterList(_vault);
    final textColor = isDark ? Colors.white : Colors.black;
    return list.isEmpty ? _emptyState('No notes available') : ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final v = list[i];
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.indigoAccent.withOpacity(0.1))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text(v['category'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 Text(v['subject']?.toUpperCase() ?? 'GEN', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
               ]),
               const SizedBox(height: 12),
               Text(v['title'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 6),
               Text(v['content'], style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.4)),
               if (v['tags'] != null && (v['tags'] as List).isNotEmpty) ...[
                 const SizedBox(height: 16),
                 Wrap(spacing: 8, children: (v['tags'] as List).map((t) => Text('#$t', style: const TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.bold))).toList()),
               ]
            ]),
          ),
        );
      },
    );
  }

  Widget _buildDoubtsTab(bool isDark) {
    final list = _filterList(_doubts);
    final textColor = isDark ? Colors.white : Colors.black;
    return list.isEmpty ? _emptyState('No active doubts') : ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final d = list[i];
        bool resolved = d['is_resolved'] == true;
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: resolved ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (resolved ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(resolved ? Icons.check_rounded : Icons.help_outline_rounded, color: resolved ? Colors.greenAccent : Colors.redAccent, size: 20)),
               const SizedBox(width: 16),
               Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['subject']?.toUpperCase() ?? 'GENERAL', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(d['doubt'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (d['resolution'] != null) ...[
                    const SizedBox(height: 12),
                    Text('RESOLUTION:', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text(d['resolution'], style: TextStyle(color: resolved ? Colors.greenAccent : textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
               ])),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRevisionTab(bool isDark) {
    final list = _filterList(_revisionQueue);
    return list.isEmpty ? _emptyState('No pending revisions') : ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final v = list[i];
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orangeAccent.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text('REVISION DUE', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 Text(v['subject']?.toUpperCase() ?? 'GEN', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
               ]),
               const SizedBox(height: 12),
               Text(v['title'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 20),
               SizedBox(
                 width: double.infinity, height: 45,
                 child: ElevatedButton(
                   onPressed: () async {
                      await _db.completeVaultRevision(v['id']);
                      _loadAllData();
                   },
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                   child: const Text('MARK COMPLETED', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                 ),
               ),
            ]),
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_edu_rounded, color: Colors.indigoAccent.withOpacity(0.1), size: 48), const SizedBox(height: 16), Text(msg, style: TextStyle(color: isDarkMode ? Colors.white10 : Colors.black12, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold))]));
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  void _showAddDialog(bool isDark, {int? specificType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AcademicEntryModal(type: specificType ?? _tabController.index, isDark: isDark, onSuccess: () { Navigator.pop(ctx); _loadAllData(); }),
    );
  }
}

class _AcademicEntryModal extends StatefulWidget {
  final int type;
  final bool isDark;
  final VoidCallback onSuccess;
  const _AcademicEntryModal({required this.type, required this.isDark, required this.onSuccess});

  @override
  State<_AcademicEntryModal> createState() => _AcademicEntryModalState();
}

class _AcademicEntryModalState extends State<_AcademicEntryModal> {
  final _db = DatabaseService();
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _tagCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _selectedType = 'weekly';
  String _selectedCat = 'trick';
  int _modalSubTab = 0;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.type == 0) ...[
          Row(children: [
            _subTabBtn('SCORES', _modalSubTab == 0, () => setState(() => _modalSubTab = 0)),
            const SizedBox(width: 12),
            _subTabBtn('PLANNER', _modalSubTab == 1, () => setState(() => _modalSubTab = 1)),
          ]),
          const SizedBox(height: 24),
          if (_modalSubTab == 0) ...[
            TextField(controller: _c1, style: TextStyle(color: textColor), decoration: _inputDeco('Exam Title (e.g. Test 01)')),
            const SizedBox(height: 16),
            TextField(controller: _c2, style: TextStyle(color: textColor), decoration: _inputDeco('Subject')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: _c3, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: _inputDeco('Score'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _tagCtrl, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: _inputDeco('Total Marks'))),
            ]),
          ] else ...[
             TextField(controller: _c3, style: TextStyle(color: textColor), decoration: _inputDeco('Exam Title (e.g. Finals)')),
             const SizedBox(height: 16),
             InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1000)));
                  if (d != null) setState(() => _date = d);
                },
                child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.indigoAccent), const SizedBox(width: 12), Text('DATE: ${DateFormat('dd MMM yyyy').format(_date)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))])),
              ),
          ],
        ] else if (widget.type == 1) ...[
          _dropdownLabel('GOAL FREQUENCY'),
          DropdownButton<String>(
            value: _selectedType,
            dropdownColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
            isExpanded: true,
            underline: const SizedBox(),
            items: ['weekly', 'monthly', 'semester'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 16),
          TextField(controller: _c1, style: TextStyle(color: textColor), decoration: _inputDeco('Goal Description')),
        ] else if (widget.type == 2) ...[
          TextField(controller: _c1, style: TextStyle(color: textColor), decoration: _inputDeco('Subject Name')),
          const SizedBox(height: 16),
          TextField(controller: _c2, style: TextStyle(color: textColor), decoration: _inputDeco('Topics (comma separated)')),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _date = d);
            },
            child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.indigoAccent), const SizedBox(width: 12), Text('TEST DATE: ${DateFormat('dd MMM yyyy').format(_date)}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))])),
          ),
        ] else if (widget.type == 3) ...[
           _dropdownLabel('NOTE CATEGORY'),
           DropdownButton<String>(
            value: _selectedCat,
            dropdownColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
            isExpanded: true,
            underline: const SizedBox(),
            items: ['trick', 'shortcut', 'important_topic', 'revision_note'].map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_',' ').toUpperCase(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedCat = v!),
          ),
          const SizedBox(height: 16),
          TextField(controller: _c1, style: TextStyle(color: textColor), decoration: _inputDeco('Topic Title')),
          const SizedBox(height: 16),
          TextField(controller: _c2, maxLines: 3, style: TextStyle(color: textColor), decoration: _inputDeco('Notes Content')),
          const SizedBox(height: 16),
          TextField(controller: _c3, style: TextStyle(color: textColor), decoration: _inputDeco('Subject')),
        ] else ...[
          TextField(controller: _c3, style: TextStyle(color: textColor), decoration: _inputDeco('Subject')),
          const SizedBox(height: 16),
          TextField(controller: _c1, maxLines: 3, style: TextStyle(color: textColor), decoration: _inputDeco('Describe your doubt...')),
        ],
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
          onPressed: () async {
            final tags = _tagCtrl.text.isEmpty ? <String>[] : _tagCtrl.text.split(',').map((e) => e.trim()).toList();
            if (widget.type == 0) {
               if (_modalSubTab == 0) await _db.createMockScore(_c1.text, _c2.text, double.parse(_c3.text), double.parse(_tagCtrl.text));
               else await _db.createExamDeadline(_c3.text, _date);
            }
            if (widget.type == 1) await _db.createAcademicTarget(_selectedType, _c1.text);
            if (widget.type == 2) await _db.createSyllabus(_c1.text, _date, _c2.text.split(','), tags);
            if (widget.type == 3) await _db.createVaultEntry(_selectedCat, _c1.text, _c2.text, _c3.text, tags);
            if (widget.type == 4) await _db.createDoubt(_c3.text, _c1.text, tags);
            widget.onSuccess();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('SAVE ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        )),
      ]),
    );
  }

  Widget _subTabBtn(String l, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45, decoration: BoxDecoration(color: active ? Colors.indigoAccent : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center, child: Text(l, style: TextStyle(color: active ? Colors.white : (widget.isDark ? Colors.white38 : Colors.black38), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    ));
  }

Widget _dropdownLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );
}

  InputDecoration _inputDeco(String h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26, fontSize: 13), filled: true, fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16));
}
