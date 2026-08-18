// ============================================================
// RS AUTO — Тема приложения (Material 3), собранная из токенов бренда.
// ============================================================
// Все значения берутся из lib/core/theme/app_brand.dart — зеркала
// сайта lib/brand.ts. В этом файле НЕТ собственных цветов, размеров
// и радиусов: он только раскладывает токены по слотам ThemeData.
// Правка бренда делается в brand.ts → app_brand.dart, сюда она
// приходит автоматически.
//
// Шрифт: Montserrat (кириллица + латиница) из assets/fonts —
// обязательное требование сербского рынка (sr latin + ru).
//
// ЗАЧЕМ ЭТО НУЖНО: экраны обращаются к теме через Theme.of(context)
// (textTheme.titleMedium, colorScheme.onSurfaceVariant и т.д.).
// Настроив слоты здесь, мы выравниваем экраны по бренду до того, как
// начнём их править руками.
// ============================================================

import 'package:flutter/material.dart';

import '../../shared/widgets/app_button_colors.dart';
import 'app_brand.dart';

class AppTheme {
  AppTheme._();

  // ------------------------------------------------------------
  // Отображение ролей Material на типографскую шкалу сайта.
  // ------------------------------------------------------------
  // Material оперирует ролями (headlineSmall, titleMedium…), сайт —
  // шкалой h1…small. Соответствие выведено из того, КАК роли реально
  // используются в экранах, а не по формальному совпадению размеров:
  //   headlineSmall — заголовок экрана/карточки авто      → h3 (20/28)
  //   titleMedium   — подзаголовок секции «Описание»      → h4 (18/28)
  //   bodyLarge     — основной текст, названия полей      → body (16/24)
  //   bodySmall     — вторичный текст, подписи            → caption (14/20)
  // Ступени, которые экраны не используют, всё равно заполнены: сторонние
  // виджеты Material (ListTile, SnackBar, диалоги) берут их сами, и
  // незаполненная ступень выпала бы из шкалы бренда.
  static const TextTheme _textTheme = TextTheme(
    // Крупные заголовки. h1 — самая большая ступень бренда.
    displayLarge: AppBrandText.h1,
    displayMedium: AppBrandText.h1,
    displaySmall: AppBrandText.h2,

    headlineLarge: AppBrandText.h1,
    headlineMedium: AppBrandText.h2,
    // Заголовок экрана входа и названия «Марка Модель, год».
    headlineSmall: AppBrandText.h3,

    titleLarge: AppBrandText.h3,
    // Подзаголовки секций: «Описание», «Фотографии», «Характеристики».
    titleMedium: AppBrandText.h4,
    titleSmall: AppBrandText.body,

    bodyLarge: AppBrandText.body,
    bodyMedium: AppBrandText.body,
    // Вторичный текст: подписи под карточкой, служебные пояснения.
    bodySmall: AppBrandText.caption,

    labelLarge: AppBrandText.body,
    labelMedium: AppBrandText.caption,
    labelSmall: AppBrandText.small,
  );

  // ------------------------------------------------------------
  // Цветовая схема.
  // ------------------------------------------------------------
  // База — ColorScheme.fromSeed на брендовом primary: Material сам
  // построит согласованные производные (контейнеры, состояния), которые
  // используют стандартные виджеты. Поверх переопределяются ровно те
  // слоты, для которых у бренда есть собственное значение.
  //
  // secondary = green: в приложении второй по значимости цвет — это
  // цвет главного действия («Позвонить», «Опубликовать»), а не
  // автоматический производный оттенок синего.
  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: AppBrandColors.primary,
  ).copyWith(
    primary: AppBrandColors.primary,
    onPrimary: Colors.white,

    secondary: AppBrandColors.green,
    onSecondary: Colors.white,

    // Связь и второстепенные действия («Написать», «Войти»).
    tertiary: AppBrandColors.blue,
    onTertiary: Colors.white,

    error: AppBrandColors.red,
    onError: Colors.white,

    // Поверхность = фон страницы: карточки лежат на белом, как на сайте.
    surface: AppBrandColors.bg,
    onSurface: AppBrandColors.neutral100,

    // Приподнятая поверхность — подложка бренда (плейсхолдер фото,
    // пузырь входящего сообщения). Раньше сюда попадал сиреневатый
    // оттенок из seed, чужой для белого макета сайта.
    surfaceContainerHighest: AppBrandColors.surfaceMuted,
    // Вторичный текст — самая частая ступень нейтральной шкалы.
    onSurfaceVariant: AppBrandColors.neutral60,

    // Границы карточек и разделители.
    outline: AppBrandColors.neutral15,
    outlineVariant: AppBrandColors.neutral10,
  );

  // ------------------------------------------------------------
  // Поля ввода.
  // ------------------------------------------------------------
  // Рамка задаётся сразу по состояниям (enabled/focused/error/disabled),
  // а не только через border. Причина практическая: экраны в большинстве
  // мест пишут `border: OutlineInputBorder()` локально, и одиночный
  // border из темы был бы перекрыт. Состояния же локальным border не
  // отменяются — поля получают брендовый радиус и цвета уже сейчас,
  // без правок экранов (это задача пакетов А2-А6).
  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppBrandRadius.controlAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // Высота контрола. На сайте это h-11 = 44px, здесь — 48.
  //
  // ЭТО ЕДИНСТВЕННОЕ ОСОЗНАННОЕ ОТКЛОНЕНИЕ ОТ САЙТА, и оно намеренное:
  // 48dp — минимальная зона касания по гайдлайнам Material/Android, её
  // обеспечивает MaterialTapTargetSize.padded. Ужать поле до 44 можно
  // только отключив padded, то есть за счёт доступности на реальных
  // пальцах. Сайт живёт с курсором, приложение — с касанием, и здесь
  // выигрывает платформа. Внутренние отступы (16 по горизонтали) при
  // этом брендовые, поэтому визуальный ритм совпадает.
  static const EdgeInsets _fieldPadding =
      EdgeInsets.symmetric(horizontal: AppBrandSpacing.md, vertical: 12);

  /// Высота контролов: поля и кнопки в одной строке обязаны совпадать.
  static const double controlHeight = 48;

  static final InputDecorationTheme _inputTheme = InputDecorationTheme(
    isDense: true,
    contentPadding: _fieldPadding,
    border: _fieldBorder(AppBrandColors.neutral15),
    enabledBorder: _fieldBorder(AppBrandColors.neutral15),
    // Фокус — брендовый синий в 2px: это единственное состояние, где
    // поле должно притягивать взгляд.
    focusedBorder: _fieldBorder(AppBrandColors.primary, width: 2),
    errorBorder: _fieldBorder(AppBrandColors.error),
    focusedErrorBorder: _fieldBorder(AppBrandColors.error, width: 2),
    disabledBorder: _fieldBorder(AppBrandColors.neutral10),
    labelStyle: AppBrandText.caption.copyWith(color: AppBrandColors.neutral60),
    hintStyle: AppBrandText.body.copyWith(color: AppBrandColors.neutral30),
    errorStyle: AppBrandText.small.copyWith(color: AppBrandColors.error),
  );

  // ------------------------------------------------------------
  // Сборка темы.
  // ------------------------------------------------------------
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: AppBrandColors.bg,
        fontFamily: AppBrandFont.family,
        textTheme: _textTheme,

        // Шапка: белая, без тени в покое — тень появляется при прокрутке
        // (scrolledUnderElevation), как sticky-тень на сайте.
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: AppBrandColors.bg,
          foregroundColor: AppBrandColors.neutral100,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppBrandColors.neutral10,
          titleTextStyle:
              AppBrandText.h4.copyWith(color: AppBrandColors.neutral100),
        ),

        // Карточка: радиус 16 и граница вместо тени в покое. На сайте
        // карточка объявления лежит на белом с рамкой neutral-10, а тень
        // card появляется только при наведении — на мобильном наведения
        // нет, поэтому базовое состояние остаётся плоским.
        cardTheme: const CardThemeData(
          color: AppBrandColors.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: AppBrandRadius.cardAll,
            side: BorderSide(color: AppBrandColors.neutral10),
          ),
        ),

        inputDecorationTheme: _inputTheme,

        // Чипсы фильтров: капсула, подложка и границы из brand.surface.
        // Выбранный чипс — тёмная плашка бренда с белым текстом, ровно
        // как активный чипс применённого фильтра на сайте.
        chipTheme: ChipThemeData(
          backgroundColor: AppBrandColors.bg,
          selectedColor: AppBrandColors.dark,
          disabledColor: AppBrandColors.surfaceMuted,
          checkmarkColor: Colors.white,
          side: const BorderSide(color: AppBrandColors.neutral15),
          shape: const RoundedRectangleBorder(
            borderRadius: AppBrandRadius.pillAll,
          ),
          labelStyle:
              AppBrandText.caption.copyWith(color: AppBrandColors.neutral100),
          secondaryLabelStyle:
              AppBrandText.caption.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(
            horizontal: AppBrandSpacing.sm,
            vertical: AppBrandSpacing.xs,
          ),
        ),

        // Главное действие — зелёная кнопка (единый стиль с «Позвонить»
        // и «Опубликовать»). Радиус control, высота 44 как у полей:
        // кнопка и поле в одной строке обязаны совпадать по высоте.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppButtonColors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppBrandSpacing.md),
            textStyle: AppBrandText.body.copyWith(
              fontWeight: AppBrandFont.semibold,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppBrandRadius.controlAll,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppButtonColors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppBrandSpacing.md),
            textStyle: AppBrandText.body.copyWith(
              fontWeight: AppBrandFont.semibold,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppBrandRadius.controlAll,
            ),
          ),
        ),

        // Вторичная кнопка: контур neutral-15, текст обычным цветом —
        // на сайте это «Сбросить фильтры» и парные кнопки в диалогах.
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppBrandColors.neutral100,
            minimumSize: const Size(0, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppBrandSpacing.md),
            textStyle: AppBrandText.body.copyWith(
              fontWeight: AppBrandFont.medium,
            ),
            side: const BorderSide(color: AppBrandColors.neutral15),
            shape: const RoundedRectangleBorder(
              borderRadius: AppBrandRadius.controlAll,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppBrandColors.primary,
            textStyle: AppBrandText.body.copyWith(
              fontWeight: AppBrandFont.medium,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppBrandRadius.controlAll,
            ),
          ),
        ),

        // Разделители — та же ступень, что границы карточек на сайте.
        dividerTheme: const DividerThemeData(
          color: AppBrandColors.neutral10,
          thickness: 1,
          space: 1,
        ),

        // Модальные шторки: радиус card только сверху — низ прижат к краю.
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppBrandColors.bg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppBrandRadius.card),
            ),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppBrandColors.bg,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: AppBrandRadius.cardAll,
          ),
          titleTextStyle:
              AppBrandText.h4.copyWith(color: AppBrandColors.neutral100),
          contentTextStyle:
              AppBrandText.body.copyWith(color: AppBrandColors.neutral80),
        ),

        // Уведомление внизу экрана: тёмная плашка бренда, радиус control.
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppBrandColors.dark,
          contentTextStyle: AppBrandText.caption.copyWith(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: AppBrandRadius.controlAll,
          ),
        ),
      );
}
