import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/supabase_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'screens/campus/room_inventory_screen.dart';
import 'screens/shop/shop_browse_screen.dart';
import 'screens/student/attendance_screen.dart';
import 'screens/user/complaint_screen.dart';
import 'services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/home/web_landing_screen.dart';
import 'services/network_connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  final isDark = await PreferencesService().getTheme();
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // JustAudioBackground MUST be initialised before runApp()
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    // Ignore on platforms that don't support background audio (web, etc.)
    print('JustAudioBackground init skipped: $e');
  }

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

            // Warm creamy background instead of cold blue-white
            scaffoldBackgroundColor: const Color(0xFFF7F3EC),

            primaryColor: const Color(0xFF6366F1),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.light,

              // Main accent
              primary: const Color(0xFF5B5CE2),
              secondary: const Color(0xFFA855F7),

              // Creamy surfaces
              surface: const Color(0xFFFFFCF7),
              surfaceContainerHighest: const Color(0xFFEDE8DF),

              // Better contrast
              onSurface: const Color(0xFF202124),
              onPrimary: Colors.white,
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF7F3EC),
              foregroundColor: Color(0xFF202124),
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 0,
            ),

            cardTheme: const CardThemeData(
              color: Color(0xFFFFFCF7),
              elevation: 0,
              margin: EdgeInsets.zero,
              surfaceTintColor: Colors.transparent,
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFFFCF7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE2DDD4),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE2DDD4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 1.5,
                ),
              ),
            ),

            dividerTheme: const DividerThemeData(
              color: Color(0xFFE5E0D8),
              thickness: 1,
            ),

            textTheme: GoogleFonts.outfitTextTheme(
              Theme.of(context).textTheme,
            ).copyWith(
              bodyLarge: const TextStyle(
                fontSize: 17,
                height: 1.4,
                color: Color(0xFF202124),
              ),
              bodyMedium: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF4B4B4B),
              ),
              bodySmall: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Color(0xFF77736D),
              ),
              labelLarge: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF202124),
              ),
              labelMedium: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5F5B56),
              ),
              labelSmall: const TextStyle(
                fontSize: 11,
                color: Color(0xFF77736D),
              ),
              titleLarge: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18181B),
              ),
              titleMedium: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18181B),
              ),
              titleSmall: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18181B),
              ),
            ),

            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,

            // Near-black, but not dead-black
            scaffoldBackgroundColor: const Color(0xFF090A0C),

            primaryColor: const Color(0xFF7779FF),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,

              primary: const Color(0xFF7779FF),
              secondary: const Color(0xFFB56CFF),

              // Subtle charcoal surfaces
              surface: const Color(0xFF111316),
              surfaceContainer: const Color(0xFF15171A),
              surfaceContainerHigh: const Color(0xFF1B1E22),
              surfaceContainerHighest: const Color(0xFF22252A),

              onSurface: const Color(0xFFF4F4F5),
              onPrimary: Colors.white,
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF090A0C),
              foregroundColor: Color(0xFFF4F4F5),
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 0,
            ),

            cardTheme: const CardThemeData(
              color: Color(0xFF111316),
              elevation: 0,
              margin: EdgeInsets.zero,
              surfaceTintColor: Colors.transparent,
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF15171A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF292D33),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF292D33),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF7779FF),
                  width: 1.5,
                ),
              ),
            ),

            dividerTheme: const DividerThemeData(
              color: Color(0xFF25282D),
              thickness: 1,
            ),

            textTheme: GoogleFonts.outfitTextTheme(
              ThemeData.dark().textTheme,
            ).copyWith(
              bodyLarge: const TextStyle(
                fontSize: 17,
                height: 1.4,
                color: Color(0xFFF4F4F5),
              ),
              bodyMedium: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFFC5C7CC),
              ),
              bodySmall: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Color(0xFF92959C),
              ),
              labelLarge: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF4F4F5),
              ),
              labelMedium: const TextStyle(
                fontSize: 13,
                color: Color(0xFFC5C7CC),
              ),
              labelSmall: const TextStyle(
                fontSize: 11,
                color: Color(0xFF92959C),
              ),
              titleLarge: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF8F8F8),
              ),
              titleMedium: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF8F8F8),
              ),
              titleSmall: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF8F8F8),
              ),
            ),

            useMaterial3: true,
          ),
            home: const AuthGuard(),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                ...const MaterialScrollBehavior().dragDevices,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
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
          return const HomeScreen(key: ValueKey('home_authenticated'));
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
    await NotificationService.initialize();
    NetworkConnectivityService().startMonitoring();
    print('Plugins initialized safely');
  } catch (e) {
    print('Init error: $e');
  }
  if (mounted) setState(() => _initialized = true);
}

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
