import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/receipt_service.dart';

class FiscalCalendarScreen extends StatefulWidget {
  final String? studentId; // If null, use current user
  final String? studentName;
  const FiscalCalendarScreen({super.key, this.studentId, this.studentName});

  @override
  State<FiscalCalendarScreen> createState() => _FiscalCalendarScreenState();
}

class _FiscalCalendarScreenState extends State<FiscalCalendarScreen> {
  final _client = Supabase.instance.client;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final targetId = widget.studentId ?? _client.auth.currentUser!.id;
    try {
      final fiscalRes = await _client.from('fiscal_collections').select().eq('user_id', targetId).order('created_at', ascending: false);
      final messAttRes = await _client.from('mess_attendance').select().eq('user_id', targetId).order('punched_at', ascending: false);
      final hostelAttRes = await _client.from('attendance_logs').select().eq('user_id', targetId).order('timestamp', ascending: false);
      final walletTxnRes = await _client.from('wallet_transactions').select().eq('user_id', targetId).order('created_at', ascending: false);
      
      Map<DateTime, List<dynamic>> eventMap = {};
      
      // Fiscal Events
      for (var r in fiscalRes) {
         final date = DateTime.parse(r['created_at']);
         final day = DateTime(date.year, date.month, date.day);
         if (eventMap[day] == null) eventMap[day] = [];
         eventMap[day]!.add({'type': 'FISCAL', 'data': r, 'time': date});
      }

      // Mess Attendance (Meal Punching)
      for (var m in messAttRes) {
         final date = DateTime.parse(m['punched_at']);
         final day = DateTime(date.year, date.month, date.day);
         if (eventMap[day] == null) eventMap[day] = [];
         eventMap[day]!.add({'type': 'MESS_PUNCH', 'data': m, 'time': date});
      }

      // Hostel Attendance (In/Out)
      for (var h in hostelAttRes) {
         final date = DateTime.parse(h['timestamp']);
         final day = DateTime(date.year, date.month, date.day);
         if (eventMap[day] == null) eventMap[day] = [];
         eventMap[day]!.add({'type': 'HOSTEL_MOVE', 'data': h, 'time': date});
      }

      if (mounted) {
        setState(() {
          _events = eventMap;
          _isLoading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.studentName != null ? '${widget.studentName!.toUpperCase()} LEDGER' : 'FISCAL CALENDAR', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Column(
            children: [
               _buildCalendar(theme, textColor),
               const SizedBox(height: 24),
               Expanded(child: _buildEventList(theme, textColor)),
            ],
          ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Color textColor) {
     final isDark = theme.brightness == Brightness.dark;
     return Container(
       margin: const EdgeInsets.all(24),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.02), borderRadius: BorderRadius.circular(30), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
       child: TableCalendar(
         firstDay: DateTime(2023),
         lastDay: DateTime.now().add(const Duration(days: 365)),
         focusedDay: _focusedDay,
         calendarFormat: _calendarFormat,
         eventLoader: _getEventsForDay,
         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
         onDaySelected: (sel, foc) {
            setState(() { _selectedDay = sel; _focusedDay = foc; });
         },
         onFormatChanged: (fmt) {
            setState(() { _calendarFormat = fmt; });
         },
         calendarStyle: CalendarStyle(
           markerDecoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
           todayDecoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.5), shape: BoxShape.circle),
           selectedDecoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
           defaultTextStyle: TextStyle(color: textColor),
           weekendTextStyle: TextStyle(color: textColor.withOpacity(0.4)),
           outsideTextStyle: TextStyle(color: textColor.withOpacity(0.2)),
         ),
         headerStyle: HeaderStyle(
           titleTextStyle: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold),
           formatButtonVisible: false,
           leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.indigoAccent),
           rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.indigoAccent),
         ),
       ),
     );
  }

  Widget _buildEventList(ThemeData theme, Color textColor) {
     final dayEvents = _getEventsForDay(_selectedDay!);
     if (dayEvents.isEmpty) {
        return Center(child: Text('NO ACTIVITY LOGGED FOR THIS DATE', style: TextStyle(color: textColor.withOpacity(0.1), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)));
     }
     dayEvents.sort((a,b) => (b['time'] as DateTime).compareTo(a['time']));

     return ListView.builder(
       padding: const EdgeInsets.symmetric(horizontal: 24),
       itemCount: dayEvents.length,
       itemBuilder: (context, i) {
          final event = dayEvents[i];
          final type = event['type'];
          final data = event['data'];
          final time = event['time'] as DateTime;
          
          IconData icon = Icons.event;
          Color color = Colors.indigoAccent;
          String label = '';
          String sub = DateFormat('hh:mm a').format(time);
          String trailing = '';

          if (type == 'FISCAL') {
             icon = Icons.add_card_rounded;
             color = Colors.greenAccent;
             label = data['collection_type']?.toString().toUpperCase() ?? 'RELOAD';
             trailing = '+₹${(data['amount'] as num).toInt()}';
          } else if (type == 'WALLET') {
             icon = Icons.shopping_basket_rounded;
             color = Colors.pinkAccent;
             label = data['transaction_type']?.toString().toUpperCase() ?? 'SHOP';
             trailing = '-₹${(data['amount'] as num).toInt()}';
          } else if (type == 'MESS_PUNCH') {
             icon = Icons.restaurant_rounded;
             final meal = data['meal_type']?.toString().toUpperCase() ?? 'MEAL';
             label = 'MESS: $meal';
             color = Colors.orangeAccent;
          } else if (type == 'HOSTEL_MOVE') {
             final move = data['log_type']?.toString().toUpperCase() ?? data['type']?.toString().toUpperCase() ?? 'MOVE';
             icon = move == 'IN' ? Icons.login_rounded : Icons.logout_rounded;
             color = move == 'IN' ? Colors.blueAccent : Colors.redAccent;
             label = 'TRANSIT: $move';
          }

          return FadeInUp(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.05))),
              child: Row(children: [
                 Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 16)),
                 const SizedBox(width: 16),
                 Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(sub, style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold)),
                 ])),
                 if (trailing.isNotEmpty) 
                   Row(children: [
                     if (type == 'FISCAL') 
                       IconButton(
                         icon: const Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 18),
                         onPressed: () => ReceiptService.generateFiscalReceipt(data, widget.studentName),
                       ),
                     Text(trailing, style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)),
                   ]),
              ]),
            ),
          );
       },
     );
  }
}
