import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/game_screen.dart';
import 'models/level_data.dart';
import 'services/supabase_service.dart';
import 'services/ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AdManager.initialize(); // Initialize AdMob SDK and pre-load rewarded ad
  runApp(const ZipperApp());
}

class ZipperApp extends StatelessWidget {
  const ZipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zipper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A66C2),
          primary: const Color(0xFF0A66C2),
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.openSans().fontFamily,
        textTheme: GoogleFonts.openSansTextTheme(),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF323232),
          contentTextStyle: GoogleFonts.openSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 6,
        ),
      ),
      home: GameScreen(
        level: LevelData.levels.first,
      ),
    );
  }
}

