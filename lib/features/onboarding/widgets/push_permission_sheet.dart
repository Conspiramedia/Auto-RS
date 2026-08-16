// ============================================================
// AUTO.RS — Запрос разрешения на уведомления.
//
// ПОКАЗЫВАЕТСЯ ТОЛЬКО ПОСЛЕ ТРЕТЬЕГО ШАГА ОНБОРДИНГА — когда человек уже
// выбрал город и марки и понимает, о чём его собираются уведомлять.
// Системный диалог iOS показывается ОДИН раз за установку: спросив его
// вслепую на первом экране, отказ уже не переиграть.
//
// Поэтому сначала свой экран-объяснение («зачем»), и только по согласию —
// системный запрос. Это стандартный приём pre-permission priming.
//
// По согласию вызывается PushService: он запрашивает системное разрешение,
// получает токен устройства и регистрирует его на сервере. Экран о деталях
// работы с Firebase не знает.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/push/push_service.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../onboarding_service.dart';

// Показывает лист один раз за установку. Возвращает true, если пользователь
// согласился получать уведомления.
Future<bool> maybeAskPushPermission(BuildContext context) async {
  // Уже спрашивали — второй раз не беспокоим.
  if (await OnboardingService.instance.wasPushAsked()) return false;
  if (!context.mounted) return false;

  final agreed = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: true,
        showDragHandle: true,
        builder: (ctx) => const _PushPermissionSheet(),
      ) ??
      false;

  await OnboardingService.instance.markPushAsked();

  if (agreed) {
    await _requestSystemPermission();
  }
  return agreed;
}

// ------------------------------------------------------------
// Системный запрос разрешения на уведомления.
//
// Вся работа с FCM — в PushService: запрос разрешения, получение токена и
// его регистрация на сервере (RPC register_push_token). Здесь только вызов,
// чтобы экраны не знали деталей работы с Firebase.
// ------------------------------------------------------------
Future<void> _requestSystemPermission() async {
  await PushService.instance.requestPermission();
}

class _PushPermissionSheet extends StatelessWidget {
  const _PushPermissionSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppButtonColors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                size: 32,
                color: AppButtonColors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.onboardingPushTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              t.onboardingPushBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  t.onboardingPushAllow,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.onboardingPushLater),
            ),
          ],
        ),
      ),
    );
  }
}
