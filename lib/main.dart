import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'services/preferences/shared_prefs_service.dart';
import 'services/storage/hive_service.dart';
import 'services/data/data_seeder_service.dart'; 
import 'services/data/test_data_seeding.dart';
import 'services/ai/openai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  await SharedPrefsService.init();
  
  // Initialize Hive
  await HiveService.init();
  
  // Initialize OpenAI Service
  try {
    await OpenAIService().initialize();
    print('✅ OpenAI service initialized');
  } catch (e) {
    print('⚠️ OpenAI initialization failed: $e');
    print('💡 Make sure to add your API key to .env file');
  }
  
  // Seed data on first launch or re-seed on version change
  final isDataSeeded = DataSeederService.isDataSeeded;
  final needsReseed = SharedPrefsService.needsReseed;
  if (!isDataSeeded || needsReseed) {
    print(needsReseed ? '🔄 Seed version changed - re-seeding data...' : '📦 First launch detected - seeding data...');
    final seeder = DataSeederService();
    await seeder.seedAllData();
    await SharedPrefsService.setSeedVersion();

    testDataSeeding();

    // Print stats
    final stats = await seeder.getSeedingStats();
    print('📊 Seeding complete:');
    print('   Topics: ${stats['topics']}');
    print('   Lessons: ${stats['lessons']}');
  } else {
    print('✅ Data already seeded, skipping...');
  }
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    const ProviderScope(
      child: SCIBotApp(),
    ),
  );
}

class SCIBotApp extends StatelessWidget {
  const SCIBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textScale = SharedPrefsService.textScaleFactor;

    return MaterialApp.router(
      title: 'SCI-Bot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
    );
  }
}