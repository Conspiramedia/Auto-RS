// ============================================================
// AUTO.RS — Точка входа приложения.
// Инициализирует .env и клиент Supabase до запуска UI, затем
// поднимает MaterialApp.router с go_router.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Гарантируем инициализацию биндингов Flutter до асинхронных операций
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем секреты из .env
  await dotenv.load(fileName: '.env');

  // Поднимаем клиент Supabase (auth, БД, RPC, storage)
  await SupabaseConfig.init();

  runApp(const AutoRsApp());
}

class AutoRsApp extends StatelessWidget {
  const AutoRsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Auto RS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
