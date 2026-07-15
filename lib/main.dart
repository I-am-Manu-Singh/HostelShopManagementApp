import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'screens/room_inventory_screen.dart';
import 'screens/shop_browse_screen.dart';
import 'screens/student/attendance_screen.dart';
import 'screens/user/complaint_screen.dart';
import 'services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/web_landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  final isDark = await PreferencesService().getTheme();
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CartProvider()),
    ],
    child: const AppInitializer(
      child: HostelShopMgmtApp(),
    ),
  ),
);
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class HostelShopMgmtApp extends StatelessWidget {
  const HostelShopMgmtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return OverlaySupport.global(
          child: MaterialApp(
            title: 'Campus Connect',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              primaryColor: const Color(0xFF6366F1),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6366F1),
                secondary: const Color(0xFFA855F7),
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                centerTitle: false,
              ),
              textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).copyWith(
                bodyLarge: const TextStyle(fontSize: 17, height: 1.4),
                bodyMedium: const TextStyle(fontSize: 15, height: 1.4),
                bodySmall: const TextStyle(fontSize: 13, height: 1.3),
                labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                labelMedium: const TextStyle(fontSize: 13),
                labelSmall: const TextStyle(fontSize: 11),
                titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF08090A),
              primaryColor: const Color(0xFF6366F1),
              colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark,
                seedColor: const Color(0xFF6366F1),
                secondary: const Color(0xFFA855F7),
                surface: const Color(0xFF16181A),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF08090A),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
              ),
              textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
                bodyLarge: const TextStyle(fontSize: 17, height: 1.4, color: Colors.white),
                bodyMedium: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white70),
                bodySmall: const TextStyle(fontSize: 13, height: 1.3, color: Colors.white60),
                labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                labelMedium: const TextStyle(fontSize: 13, color: Colors.white70),
                labelSmall: const TextStyle(fontSize: 11, color: Colors.white60),
                titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                titleSmall: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              useMaterial3: true,
            ),
            home: const AuthGuard(),
            routes: {
              '/rooms': (context) => const RoomInventoryScreen(),
              '/shop': (context) => const ShopBrowseScreen(),
              '/complaints': (context) => const ComplaintScreen(),
              '/attendance_hostel': (context) => const AttendanceScreen(type: 'hostel'),
              '/attendance_mess': (context) => const AttendanceScreen(type: 'mess'),
            },
          ),
        );
      },
    );
  }
}


class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});
  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _webLandingShown = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session != null) {
          return const HomeScreen();
        }
        
        // Unauthenticated flow
        if (kIsWeb && !_webLandingShown) {
          return WebLandingScreen(
            onLaunchApp: () {
              setState(() {
                _webLandingShown = true;
              });
            },
          );
        }
        
        // Show HomeScreen in Guest mode
        return const HomeScreen(isGuest: true);
      },
    );
  }
}
class AppInitializer extends StatefulWidget {
  final Widget child;
  const AppInitializer({super.key, required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;

 @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initPlugins();
  });
}
Future<void> _initPlugins() async {
  try {
    await Future.delayed(const Duration(milliseconds: 300));

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );

    await NotificationService.initialize();

    print("Plugins initialized safely");
  } catch (e) {
    print("Init error: $e");
  }

  if (mounted) setState(() => _initialized = true);
}

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
