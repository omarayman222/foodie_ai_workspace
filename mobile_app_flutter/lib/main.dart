import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth_screen.dart';
import 'utils/theme_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FoodieAiApp());
}

class FoodieAiApp extends StatelessWidget {
  const FoodieAiApp({super.key});

  static ThemeData _buildTheme(ColorScheme cs) => ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(),
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: cs.onSurface, fontSize: 18),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (_, mode, __) => MaterialApp(
        title: 'Foodie AI',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _buildTheme(ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B00),
          primary: const Color(0xFFFF6B00),
          secondary: const Color(0xFF2ECC71),
          brightness: Brightness.light,
        )),
        darkTheme: _buildTheme(ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B00),
          primary: const Color(0xFFFF8C40),
          secondary: const Color(0xFF2ECC71),
          brightness: Brightness.dark,
        )),
        home: const AuthScreen(),
      ),
    );
  }
}
