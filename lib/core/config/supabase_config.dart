// ============================================================
// AUTO.RS — Конфигурация подключения к Supabase.
// Ключи читаются из .env (flutter_dotenv), НЕ хардкодятся.
// ============================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Приватный конструктор — класс используется как статический контейнер.
  SupabaseConfig._();

  // URL проекта из .env
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  // Публичный анонимный ключ из .env (безопасен только при включённом RLS)
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Инициализация клиента Supabase. Вызывается один раз в main().
  static Future<void> init() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Не заданы SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Скопируйте .env.example в .env и заполните значения.',
      );
    }

    await Supabase.initialize(
      url: url,
      // anonKey рабочий во всех версиях 2.x. В новых пакетах его переименовали
      // в publishableKey, но anonKey оставлен для обратной совместимости —
      // сознательно используем его, чтобы код собирался на любой версии 2.x.
      // ignore: deprecated_member_use
      anonKey: anonKey,
    );
  }

  // Быстрый доступ к клиенту из любого места приложения
  static SupabaseClient get client => Supabase.instance.client;
}
