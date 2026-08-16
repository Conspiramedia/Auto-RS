// ============================================================
// AUTO.RS — Точка входа приложения.
// Инициализирует .env и клиент Supabase до запуска UI, затем
// поднимает MaterialApp.router с go_router.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/supabase_config.dart';
import 'core/i18n/app_language.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_service.dart';

Future<void> main() async {
  // Гарантируем инициализацию биндингов Flutter до асинхронных операций
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем секреты из .env
  await dotenv.load(fileName: '.env');

  // Поднимаем клиент Supabase (auth, БД, RPC, storage)
  await SupabaseConfig.init();

  // Читаем сохранённый выбор языка ДО первого кадра, чтобы интерфейс сразу
  // поднялся на нужном языке (иначе был бы кадр на языке по умолчанию).
  await AppLanguageService.instance.load();

  // Проходил ли пользователь онбординг. Читаем здесь, а не в redirect
  // роутера: проверка асинхронная (диск), а redirect синхронный. Значение
  // должно быть готово до создания GoRouter — он берёт initialLocation один
  // раз при инициализации.
  AppRouter.showOnboarding = !await OnboardingService.instance.isCompleted();

  runApp(const AutoRsApp());
}

class AutoRsApp extends StatelessWidget {
  const AutoRsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Перестраиваем приложение при смене языка в настройках профиля:
    // сервис — ChangeNotifier, MaterialApp пересобирается с новой локалью.
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Auto RS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: AppRouter.router,

          // Языки интерфейса: сербский (рынок) и русский.
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // null при выборе «Как в телефоне» — тогда язык подбирает резолвер
          // ниже по локалям устройства.
          locale: AppLanguageService.instance.materialLocale,

          // Своя логика подбора: штатная берёт первую поддерживаемую локаль
          // (нам подходит), но при незнакомом языке телефона Flutter выдал бы
          // supportedLocales.first вслепую. Здесь запасной язык задан явно.
          localeResolutionCallback: (deviceLocale, supported) {
            return AppLanguageService.resolveLocale(
              AppLanguageService.instance.selection,
              deviceLocale == null ? const [] : [deviceLocale],
            );
          },
        );
      },
    );
  }
}
