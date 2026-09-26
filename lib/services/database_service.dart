import 'package:flutter/foundation.dart';
import '../models/hostel.dart';
import '../models/shop.dart';
import 'supabase_service.dart';
import 'preferences_service.dart';

class DatabaseService {
  final _client = SupabaseService().client;

  // --- PROFILE METHODS ---

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      final profile = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile != null) {
        PreferencesService().saveCachedProfile(profile);
        return profile;
      }

      // If profile is missing in the database table, insert it dynamically
      final meta = user.userMetadata ?? {};
      final String fullName = meta['full_name'] ?? user.email?.split('@').first ?? 'New User';
      final String role = meta['role'] ?? 'store_customer';

      final newProfile = {
        'id': user.id,
        'full_name': fullName,
        'role': role,
        'balance': 0.0,
        'xp': 0,
        'created_at': DateTime.now().toIso8601String(),
        'is_verified': false,
        'loyalty_rank': 1,
        'student_level': 1,
      };

      await _client.from('profiles').insert(newProfile);
      final inserted = await _client.from('profiles').select().eq('id', user.id).maybeSingle() ?? newProfile;
      PreferencesService().saveCachedProfile(inserted);
      return inserted;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Offline fallback: load from cached profile to avoid indefinite loading
      final cached = await PreferencesService().getCachedProfile();
      if (cached != null) return cached;
      return null;
    }
  }

  // --- HOSTEL METHODS ---

  Future<List<HostelRoom>> fetchRooms() async {
    try {
      final response = await _client.from('hostel_rooms').select().eq('is_active', true);
      return (response as List).map((e) => HostelRoom.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      return [];
    }
  }

  Future<bool> bookRoom({required String roomId, required double price}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('hostel_enrollments').insert({
        'user_id': user.id,
        'room_id': roomId,
        'check_in_date': DateTime.now().toIso8601String(),
        'total_price': price,
        'payment_status': 'Pending',
        'status': 'Active',
      });
      return true;
    } catch (e) {
      debugPrint('Error booking room: $e');
      return false;
    }
  }

  // --- SHOP METHODS ---

  Future<List<ShopItem>> fetchShopItems() async {
    try {
      final response = await _client.from('shop_items').select().eq('is_available', true);
      return (response as List).map((e) => ShopItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching shop items: $e');
      return [];
    }
  }

  Future<ShopItem?> fetchItemByQR(String code) async {
    try {
      final clean = code.trim();
      // Try barcode column
      var item = await _client.from('shop_items').select().eq('barcode', clean).maybeSingle();
      // Try sku_qr column
      item ??= await _client.from('shop_items').select().eq('sku_qr', clean).maybeSingle();
      // Try id
      item ??= await _client.from('shop_items').select().eq('id', clean).maybeSingle();
      return item != null ? ShopItem.fromJson(item) : null;
    } catch (e) {
      debugPrint('Error fetching item by QR/Barcode: $e');
      return null;
    }
  }

  Future<bool> placeOrder({required List<OrderItem> items, required double total}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('shop_orders').insert({
        'user_id': user.id,
        'items': items.map((e) => e.toJson()).toList(),
        'total_price': total,
        'payment_status': 'Pending',
        'order_status': 'Placed',
      });
      return true;
    } catch (e) {
      debugPrint('Error placing order: $e');
      return false;
    }
  }

  // --- ATTENDANCE METHODS ---

  Future<bool> markAttendance({required String type, String? studentId, String? mealType, String status = 'Present', DateTime? date}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      final targetId = studentId ?? user.id;

      // Standardize types to avoid constraint violations
      String finalType = type.toLowerCase();
      if (finalType == 'hostel') finalType = 'gate';
      if (mealType?.toLowerCase() == 'tea') mealType = 'Tea';
      if (mealType?.toLowerCase() == 'snack') mealType = 'Tea';
      if (mealType?.toLowerCase() == 'hi-tea') mealType = 'Tea';

      final dateStr = (date ?? DateTime.now()).toIso8601String().split('T')[0];

      // Use upsert to prevent unique constraint violations for same day/type
      await _client.from('attendance').upsert({
        'user_id': targetId,
        'attendance_type': finalType,
        'meal_type': (finalType == 'mess') ? (mealType ?? 'Breakfast') : null,
        'status': status,
        'date': dateStr,
      }, onConflict: 'user_id, date, attendance_type, meal_type');
      
      return true;
    } catch (e) {
      debugPrint('Attendance Protocol Error (Type: $type): $e');
      return false;
    }
  }

  // --- BIOMETRIC TELEMETRY ---

  Future<bool> registerFaceData(List<double> embedding) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('profiles').update({
        'face_embedding': embedding,
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('Error registering face: $e');
      return false;
    }
  }

  Future<bool> registerFingerprintMapping(String biometricId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('profiles').update({
        'biometric_id': biometricId,
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('Error registering fingerprint: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBiometricTelemetry() async {
    try {
      final res = await _client.rpc('get_biometric_telemetry');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching biometric telemetry: $e');
      return [];
    }
  }

  Future<List<Attendance>> fetchMyAttendance(String type) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      final response = await _client.from('attendance').select().eq('user_id', user.id).eq('attendance_type', type).order('date', ascending: false);
      return (response as List).map((e) => Attendance.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      return [];
    }
  }

  // --- COMPLAINTS ---

  Future<bool> submitComplaint(String title, String desc, String category) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('complaints').insert({
        'user_id': user.id,
        'title': title,
        'description': desc,
        'category': category,
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting complaint: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserComplaints() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final response = await _client.from('user_complaints').select().eq('user_id', user.id).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching complaints: $e');
      return [];
    }
  }

  // --- MESSAGES ---

  Future<void> sendMessage(String roomId, String content, {String? recipientId}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.from('messages').insert({
        'room_id': roomId,
        'sender_id': user.id,
        'recipient_id': recipientId,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> incrementXP(int amount) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      await _client.rpc('increment_xp_only', params: {
        'user_id': user.id,
        'p_xp': amount,
      });
    } catch (e) {
      debugPrint('Error incrementing XP: $e');
    }
  }
  // --- LEADERBOARD & XP ---

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final response = await _client.from('profiles').select().order('xp', ascending: false).limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  // --- PERSONNEL MANAGEMENT ---

  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    try {
      final response = await _client.from('profiles').select().order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      return [];
    }
  }

  Future<bool> updateProfileRole(String userId, String role) async {
    try {
      await _client.from('profiles').update({'role': role}).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error updating role: $e');
      return false;
    }
  }

  Future<Map<String, int>> fetchBiometricStats() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {'present': 0, 'skipped': 0};
      
      final res = await _client.rpc('get_attendance_summary', params: {'p_user_id': user.id}).maybeSingle();
      if (res != null) {
        return {
          'present': (res['present_count'] as num).toInt(),
          'skipped': (res['skipped_count'] as num).toInt(),
        };
      }
      return {'present': 0, 'skipped': 0};
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return {'present': 0, 'skipped': 0};
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudents({List<String>? roles}) async {
    try {
      final queryRoles = roles ?? ['hostel_student', 'mess_student'];
      final response = await _client.from('profiles').select().inFilter('role', queryRoles).order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching students: $e');
      return [];
    }
  }

  Future<bool> markMessAttendance({required String studentId, required String mealType, required DateTime date, String status = 'Present'}) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      String finalMeal = mealType;
      if (finalMeal.toLowerCase() == 'hi-tea') finalMeal = 'Tea';

      await _client.from('attendance').upsert({
        'user_id': studentId,
        'attendance_type': 'mess',
        'meal_type': finalMeal,
        'status': status,
        'date': dateStr,
      });
      return true;
    } catch (e) {
      debugPrint('Error marking mess attendance: $e');
      return false;
    }
  }

  Future<bool> issueMessCard(String userId) async {
    try {
      await _client.from('profiles').update({'role': 'mess_student'}).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error issuing mess card: $e');
      return false;
    }
  }

  Future<bool> issueMessCardComplex({
    required String userId,
    required String type,
    required String meals,
    required DateTime expiry,
  }) async {
    try {
      // 1. Upsert mess card details
      await _client.from('mess_cards').upsert({
        'user_id': userId,
        'card_type': type,
        'meal_plan': meals,
        'expiry_date': expiry.toIso8601String(),
        'status': 'Active',
      }, onConflict: 'user_id');

      // 2. Ensure user role is updated to mess_student
      await _client.from('profiles').update({'role': 'mess_student'}).eq('id', userId);
      
      return true;
    } catch (e) {
      debugPrint('Error issuing complex mess card: $e');
      return false;
    }
  }
  Future<List<Map<String, dynamic>>> fetchAllComplaints() async {
    try {
      // Specify user_id as foreign key source to avoid ambiguity with resolved_by
      var response = await _client.from('complaints').select('*, profiles:user_id(full_name, avatar_url, room_number)').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      try {
        final altRes = await _client.from('complaints').select('*, profiles(*)').order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(altRes);
      } catch (_) {
        debugPrint('Error fetching all complaints: $e');
        return [];
      }
    }
  }

  Future<bool> updateComplaintStatus(String id, String status) async {
    try {
      await _client.from('complaints').update({'status': status}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating complaint status: $e');
      return false;
    }
  }

  Future<bool> updateComplaintResponse(String id, String response) async {
    try {
      // 🧠 FIXED: Use 'complaints' table instead of 'user_complaints' view to ensure persistence
      await _client.from('complaints').update({'admin_response': response, 'status': 'In-Progress'}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating response: $e');
      return false;
    }
  }

  // --- FISCAL RELOADING ---

  Future<double> fetchUserBalance() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0.0;
      final res = await _client.from('profiles').select('balance').eq('id', user.id).single();
      return (res['balance'] as num).toDouble();
    } catch (e) {
      debugPrint('Error fetching balance: $e');
      return 0.0;
    }
  }

  Future<bool> reloadWallet(double amount, String type) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // 1. Atomic Adjustment + Transaction Entry (Bypasses RLS via RPC)
      await _client.rpc('adjust_balance', params: {
        'input_user_id': user.id,
        'input_amount': amount,
        'input_type': type
      });
      
      return true;
    } catch (e) {
      debugPrint('Error reloading wallet: $e');
      return false;
    }
  }

  // --- GUEST INVITATION ---

  Future<List<Map<String, dynamic>>> fetchMyVisitorLogs() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      return await _client.from('visitor_logs').select().eq('user_id', user.id).order('created_at', ascending: false);
    } catch (e) {
      debugPrint('Error fetching visitor logs: $e');
      return [];
    }
  }

  Future<bool> createVisitorInvitation(String name, String phone, String purpose) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('visitor_logs').insert({
        'user_id': user.id,
        'visitor_name': name,
        'visitor_phone': phone,
        'purpose': purpose,
        'qr_code': 'VIS-${DateTime.now().millisecondsSinceEpoch}',
      });
      return true;
    } catch (e) {
      debugPrint('Error creating visitor: $e');
      return false;
    }
  }

  // --- ANNOUNCEMENTS ---

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String role) async {
    try {
      return await _client.from('announcements').select().or('target_role.eq.$role,target_role.eq.all').eq('is_active', true).order('created_at', ascending: false);
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  Future<bool> createAnnouncement(String title, String content, String target, String priority) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('announcements').insert({
        'author_id': user.id,
        'title': title,
        'content': content,
        'target_role': target,
        'priority': priority,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      return false;
    }
  }

  // --- EMERGENCY RESPONSE ---

  Future<bool> triggerEmergency(String type, String detail, String location) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('emergency_alerts').insert({
        'user_id': user.id,
        'emergency_type': type,
        'location_type': location,
        'location_detail': detail,
      });
      return true;
    } catch (e) {
      debugPrint('Error triggering emergency: $e');
      return false;
    }
  }

  // --- EMPLOYEE TASKS ---

  Future<List<Map<String, dynamic>>> fetchMyTasks() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      return await _client.from('employee_tasks').select().eq('user_id', user.id).order('priority', ascending: false);
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      return [];
    }
  }

  Future<bool> updateTaskStatus(String taskId, String status, {String? proofUrl}) async {
    try {
      await _client.from('employee_tasks').update({
        'status': status,
        'proof_url': proofUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (e) {
      debugPrint('Error updating task: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTasks() async {
    try {
      return await _client.from('employee_tasks').select('*, profiles(*)').order('created_at', ascending: false);
    } catch (e) {
      debugPrint('Error fetching all tasks: $e');
      return [];
    }
  }

  // --- STUDENT TIMETABLE & TASKS ---

  Future<List<Map<String, dynamic>>> fetchStudentTasks(DateTime date) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];
      final dateStr = date.toIso8601String().split('T')[0];
      return await _client.from('student_tasks')
          .select()
          .eq('user_id', user.id)
          .eq('task_date', dateStr)
          .order('start_time');
    } catch (e) {
      debugPrint('Error fetching student tasks: $e');
      return [];
    }
  }

  Future<bool> addStudentTask(Map<String, dynamic> task) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      task['user_id'] = user.id;
      await _client.from('student_tasks').insert(task);
      return true;
    } catch (e) {
      debugPrint('Error adding student task: $e');
      return false;
    }
  }

  Future<bool> updateStudentTask(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('student_tasks').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating student task: $e');
      return false;
    }
  }

  Future<bool> completeStudentTask(String id) async {
    try {
      await _client.from('student_tasks').update({'is_completed': true}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error completing student task: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchStudentDailyStats() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {};
      final res = await _client.from('student_tasks').select('is_completed').eq('user_id', user.id);
      final tasks = res as List;
      final completed = tasks.where((t) => t['is_completed'] == true).length;
      return {
        'total': tasks.length,
        'completed': completed,
        'rate': tasks.isEmpty ? 0 : (completed / tasks.length),
      };
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
      return {};
    }
  }

  Future<bool> updateStudyStatus(String status) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.from('profiles').update({'study_status': status}).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  Future<bool> incrementPerformanceWithLog({
    required String type,
    required int value,
    required int xp,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await _client.rpc('increment_performance_with_log', params: {
        'user_id': user.id,
        'p_type': type,
        'p_value': value,
        'p_xp': xp,
      });
      return true;
    } catch (e) {
      debugPrint('Error incrementing performance with log: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMeditationLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_meditation_logs').select().eq('user_id', user.id).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchWorkoutLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_workout_logs').select().eq('user_id', user.id).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchFocusLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_focus_logs').select().eq('user_id', user.id).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  // ACADEMIC INTEL METHODS
  Future<List<Map<String, dynamic>>> fetchAcademicTargets() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_academic_targets').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createAcademicTarget(String type, String content) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_academic_targets').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'target_type': type, 
        'content': content
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchKnowledgeVault() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_knowledge_vault').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createVaultEntry(String cat, String title, String content, String subj, List<String> tags) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_knowledge_vault').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'category': cat, 
        'title': title, 
        'content': content, 
        'subject': subj,
        'tags': tags
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDoubts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_doubts').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createDoubt(String subj, String q, List<String> tags) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_doubts').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'subject': subj, 
        'question': q,
        'doubt': q,
        'tags': tags
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSyllabus() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_syllabus').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('test_date', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createSyllabus(String subj, DateTime date, List<String> topics, List<String> tags) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_syllabus').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'subject': subj, 
        'test_date': date.toIso8601String().split('T')[0], 
        'topics': topics, 
        'tags': tags
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRevisionQueue() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_knowledge_vault')
          .select()
          .or('user_id.eq.${user.id},student_id.eq.${user.id}')
          .lte('next_revision_date', DateTime.now().toIso8601String())
          .order('next_revision_date', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> completeVaultRevision(String vaultId) async {
    try {
      await _client.rpc('complete_knowledge_revision', params: {'vault_id': vaultId});
      return true;
    } catch(e) { return false; }
  }

  Future<bool> createReflection(String achievements, int rating, String feeling, int satisfaction, List<String> goals) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_reflections').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'achievements': achievements, 
        'focus_rating': rating,
        'feeling': feeling,
        'satisfaction_rating': satisfaction,
        'goals_met': goals
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReflections() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_reflections').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('log_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  // COMPETITIVE EXAM METHODS
  Future<List<Map<String, dynamic>>> fetchMockScores() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_mock_scores').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('mock_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createMockScore(String exam, String subj, double score, double total) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_mock_scores').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'exam_name': exam, 
        'subject': subj, 
        'score_obtained': score, 
        'total_score': total
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchExamDeadlines() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_exam_deadlines').select().or('user_id.eq.${user.id},student_id.eq.${user.id}').order('exam_date', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createExamDeadline(String title, DateTime date) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('student_exam_deadlines').insert({
        'user_id': user.id, 
        'student_id': user.id,
        'exam_title': title, 
        'exam_date': date.toIso8601String()
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // REMINDER METHODS
  Future<List<Map<String, dynamic>>> fetchReminders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_reminders').select().eq('user_id', user.id).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createReminder(String title, String type, String time, List<int> days) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    await _client.from('student_reminders').insert({'user_id': user.id, 'title': title, 'reminder_type': type, 'scheduled_time': time, 'recurring_days': days});
    return true;
  }

  Future<bool> toggleReminder(String id, bool status) async {
     await _client.from('student_reminders').update({'is_active': status}).eq('id', id);
     return true;
  }

  // DAILY ROUTINE METHODS
  Future<List<Map<String, dynamic>>> fetchDailyRoutine() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('student_daily_routines').select().eq('user_id', user.id).order('start_time');
      return List<Map<String, dynamic>>.from(res);
    } catch(e) { return []; }
  }

  Future<bool> createRoutineBlock(String title, String start, String end, String icon) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    await _client.from('student_daily_routines').insert({
      'user_id': user.id, 
      'title': title, 
      'start_time': start, 
      'end_time': end, 
      'icon_name': icon
    });
    return true;
  }

  Future<bool> deleteRoutineBlock(String id) async {
    await _client.from('student_daily_routines').delete().eq('id', id);
    return true;
  }

  Future<bool> updateRoutineBlock(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('student_daily_routines').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating routine: $e');
      return false;
    }
  }

  // --- WISHLIST ---
  Future<List<Map<String, dynamic>>> fetchWishlist() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _client.from('user_wishlist_details').select().eq('user_id', user.id);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<bool> isWishlisted(String pid) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _client.from('wishlist').select().eq('user_id', user.id).eq('product_id', pid).maybeSingle();
      return res != null;
    } catch (e) { return false; }
  }

  Future<bool> toggleWishlist(String pid) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final currentlyIn = await isWishlisted(pid);
    try {
      if (currentlyIn) {
        await _client.from('wishlist').delete().eq('user_id', user.id).eq('product_id', pid);
      } else {
        await _client.from('wishlist').insert({'user_id': user.id, 'product_id': pid});
      }
      return true;
    } catch (e) { return false; }
  }
}
