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
import '../../../core/theme/app_brand.dart';
import '../onboarding_service.dart';

// Показывает лист один раз за установку. Возвращает true, если пользователь
// согласился получать уведомления.
//
// ТОЧКИ ВЫЗОВА (первая сработавшая закрывает вопрос):
//   1) конец онбординга — основной путь;
//   2) подписка «Сообщить, когда появится» в пустом каталоге;
//   3) первое добавление объявления в избранное.
//
// Пункты 2–3 нужны тем, кто нажал «Пропустить»: без них человек подписался
// бы на уведомления, которые физически не могут прийти. Момент в обоих
// случаях уместный — пользователь только что попросил его уведомлять.
Future<bool> maybeAskPushPermission(BuildContext context) async {
  // Уже спрашивали — второй раз не беспокоим.
  if (await OnboardingService.instance.wasPushAsked()) return false;

  // Разрешение уже выдано (например, через системные настройки) —
  // объяснять смысл уведомлений незачем, просто фиксируем факт и
  // убеждаемся, что токен зарегистрирован.
  if (await PushService.instance.hasPermission()) {
    await OnboardingService.instance.markPushAsked();
    await PushService.instance.syncToken();
    return true;
  }

  if (!context.mounted) return false;

  // null = лист смахнули, не нажав ни одной кнопки.
  final choice = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (ctx) => const _PushPermissionSheet(),
  );

  // Флаг ставим только при ОСОЗНАННОМ выборе — «Включить» или «Позже».
  // Смахнутый лист выбором не считается: иначе случайный свайп навсегда
  // лишал бы человека уведомлений, и следующая точка вызова (избранное,
  // подписка) уже не сработала бы.
  if (choice == null) return false;

  await OnboardingService.instance.markPushAsked();

  if (choice) {
    await _requestSystemPermission();
  }
  return choice;
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppBrandColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                size: 32,
                color: AppBrandColors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.onboardingPushTitle,
              textAlign: TextAlign.center,
              style: AppBrandText.h3
                  .copyWith(color: AppBrandColors.neutral100),
            ),
            const SizedBox(height: 8),
            Text(
              t.onboardingPushBody,
              textAlign: TextAlign.center,
              style: AppBrandText.body
                  .copyWith(color: AppBrandColors.neutral60),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppBrandColors.green,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBrandRadius.controlAll,
                  ),
                ),
                child: Text(
                  t.onboardingPushAllow,
                  style: AppBrandText.body
                      .copyWith(fontWeight: AppBrandFont.semibold),
                ),
              ),
            ),
            // «Позже» — ghost: отказ не должен выглядеть равным согласию.
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppBrandColors.neutral60,
              ),
              child: Text(
                t.onboardingPushLater,
                style: AppBrandText.caption
                    .copyWith(fontWeight: AppBrandFont.medium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
