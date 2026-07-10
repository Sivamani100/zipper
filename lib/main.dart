import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/game_screen.dart';
import 'models/level_data.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const LinkedInZipApp(),
    ),
  );
}

class LinkedInZipApp extends StatelessWidget {
  const LinkedInZipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Zipper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A66C2),
          primary: const Color(0xFF0A66C2),
        ),
        useMaterial3: true,
      ),
      home: GameScreen(
        level: LevelData.levels.first,
      ),
    );
  }
}
