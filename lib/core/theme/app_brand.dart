// ============================================================
// RS AUTO — Дизайн-токены бренда (зеркало сайта).
// ============================================================
// ИСТОЧНИК ИСТИНЫ: D:\Project\Auto RS Website\lib\brand.ts
// Этот файл — построчное зеркало brand.ts во Flutter. Имена токенов
// совпадают 1:1 с сайтом, значения не пересчитываются: типографика
// в brand.ts задана в px именно для того, чтобы переноситься в
// TextStyle без преобразований (в Flutter logical pixels).
//
// ПРАВИЛО: цвета, радиусы, тени и размеры шрифтов не хардкодятся
// в экранах и виджетах. Любая правка бренда делается в brand.ts на
// сайте и синхронно переносится сюда — и только сюда.
//
// Отношение к AppTheme: AppTheme (app_theme.dart) собирает ThemeData
// из этих токенов, AppButtonColors остаётся тонким слоем ролей кнопок
// поверх AppBrandColors. Токены — база, тема — производная.
// ============================================================

import 'package:flutter/material.dart';

// ------------------------------------------------------------
// Цвета.
// ------------------------------------------------------------
/// Палитра бренда: brand.colors + neutral + surface + semantic.
///
/// Нейтральная шкала построена на полупрозрачном чёрном, а не на
/// сплошных серых: карточки и плашки лежат на подложках разной
/// светлоты, и прозрачный текст сохраняет на них правильный контраст.
class AppBrandColors {
  AppBrandColors._();

  // ---------- Брендовые (brand.colors) ----------

  /// Основной цвет бренда — seed Material 3.
  static const Color primary = Color(0xFF1565C0);

  /// Главное/подтверждающее действие: «Опубликовать», «Позвонить».
  /// Единственный акцент экрана — второго яркого CTA быть не должно.
  static const Color green = Color(0xFF22C063);

  /// Связь и второстепенные действия: «Написать», «Войти».
  static const Color blue = Color(0xFF1E9AF0);

  /// Бренд-красный: сброс фильтров, деструктив, ошибки.
  static const Color red = Color(0xFFE01E23);

  /// Нейтральные тёмные плашки (кнопка фильтров, шапка).
  static const Color dark = Color(0xFF2B2B2E);

  /// Золотой акцент: иконки на тёмном фоне, бейдж продвижения (VIP).
  static const Color gold = Color(0xFFE8A73C);

  /// Базовый фон. Совпадает с фоном логотипа, чтобы логотип не
  /// выделялся прямоугольником.
  static const Color bg = Color(0xFFFFFFFF);

  // ---------- Нейтральная шкала (brand.neutral) ----------
  // Ступень = процент непрозрачности чёрного: neutral100 = alpha 1.0.

  /// Основной текст.
  static const Color neutral100 = Color(0xFF000000);

  /// Описание объявления.
  static const Color neutral80 = Color(0xCC000000);

  /// Абзацы юридических документов.
  static const Color neutral75 = Color(0xBF000000);

  /// Подпись согласия с условиями.
  static const Color neutral70 = Color(0xB3000000);

  /// Вторичный текст — самая частая ступень.
  static const Color neutral60 = Color(0x99000000);

  /// Неактивная вкладка сегмента «Продажа | Аренда»: на 50 она
  /// проваливается относительно активной, на 60 — спорит с ней.
  static const Color neutral55 = Color(0x8C000000);

  /// Подписи, метки характеристик.
  static const Color neutral50 = Color(0x80000000);

  /// Третьестепенное: копирайт, многоточие.
  static const Color neutral40 = Color(0x66000000);

  /// Текст-заглушка («нет фото») и граница поля при наведении —
  /// на сайте это одно и то же значение.
  static const Color neutral30 = Color(0x4D000000);

  /// Границы полей ввода и вторичных кнопок.
  static const Color neutral15 = Color(0x26000000);

  /// Границы карточек и разделители.
  static const Color neutral10 = Color(0x1A000000);

  // ---------- Подложки и состояния (brand.surface) ----------
  // Заливки, а не цвет текста. Держатся отдельно от neutral намеренно.

  /// Секции-подложки (герой на главной, подвал).
  static const Color surfaceSubtle = Color(0x05000000);

  /// Плейсхолдер фотографии.
  static const Color surfaceMuted = Color(0x0D000000);

  /// Наведение на вторичные элементы.
  static const Color surfaceHover = Color(0x08000000);

  /// Наведение на кнопки — чуть заметнее обычного.
  static const Color surfaceHoverStrong = Color(0x0A000000);

  /// Наведение на чипсы сортировки.
  static const Color surfaceHoverChip = Color(0x0D000000);

  /// Активное (нажатое) состояние.
  static const Color surfaceActive = Color(0x0F000000);

  /// Наведение на уже активный чипс применённого фильтра.
  static const Color surfaceActiveHover = Color(0x1A000000);

  /// Затемнение под модальным слоем: шторка фильтров, пикер.
  /// Плотность 40% — содержимое угадывается, но не отвлекает.
  static const Color surfaceOverlay = Color(0x66000000);

  // ---------- Семантические роли (brand.semantic) ----------
  // Ссылаются на брендовые цвета, а не переопределяют их: «успех» и
  // «главное действие» — один и тот же зелёный, разъехаться не должны.

  /// Успех = green.
  static const Color success = green;

  /// Предупреждение = gold.
  static const Color warning = gold;

  /// Ошибка = red.
  static const Color error = red;

  /// Информация = blue.
  static const Color info = blue;
}

// ------------------------------------------------------------
// Типографика.
// ------------------------------------------------------------
/// Шкала из brand.typography. Размеры в px переносятся напрямую:
/// в Flutter fontSize задаётся в logical pixels, что соответствует
/// CSS-пикселю сайта.
///
/// height в TextStyle — множитель, поэтому lineHeight из brand.ts
/// делится на размер (например h1: 36/30 = 1.2). Значения оставлены
/// вычисленными явно, чтобы совпадение с сайтом читалось глазами.
class AppBrandText {
  AppBrandText._();

  /// 30/36, bold. Заголовок страницы.
  static const TextStyle h1 = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w700,
  );

  /// 24/32, bold. Заголовок секции.
  static const TextStyle h2 = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );

  /// 20/28, semibold. Заголовок карточки/блока.
  static const TextStyle h3 = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  /// 18/28, semibold. Подзаголовок: «Характеристики», «Условия аренды».
  static const TextStyle h4 = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
  );

  /// 16/24, regular. Основной текст.
  static const TextStyle body = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// 14/20, regular. Вторичный текст, подписи полей.
  static const TextStyle caption = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 12/16, regular. Бейджи, метки, мелкая служебная информация.
  static const TextStyle small = TextStyle(
    fontFamily: AppBrandFont.family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );
}

/// Шрифт из brand.font. Montserrat поддерживает кириллицу и латиницу —
/// обязательное требование сербского рынка (sr latin + ru).
class AppBrandFont {
  AppBrandFont._();

  static const String family = 'Montserrat';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

// ------------------------------------------------------------
// Радиусы.
// ------------------------------------------------------------
/// Из brand.radius. Две базовые ступени: 12 — контролы (кнопки, поля,
/// чипсы), 16 — контейнеры (карточки, модальные окна).
class AppBrandRadius {
  AppBrandRadius._();

  /// 8 — мелкие бейджи поверх фотографии («Продано», «Аренда»):
  /// на плашке высотой 24 радиус 12 превратил бы её в капсулу.
  static const double sm = 8;

  /// 12 — кнопки, поля ввода, чипсы.
  static const double control = 12;

  /// 16 — карточки, модальные окна, шторки.
  static const double card = 16;

  /// Капсула: счётчики и круглые индикаторы.
  static const double pill = 999;

  // Готовые BorderRadius — чтобы в разметке не писать circular(...).
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius controlAll =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

// ------------------------------------------------------------
// Отступы.
// ------------------------------------------------------------
/// Из brand.spacing. Сетка кратна 4 — это то, что делает вёрстку
/// ритмичной. Все интервалы берутся отсюда.
class AppBrandSpacing {
  AppBrandSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

// ------------------------------------------------------------
// Тени (elevation).
// ------------------------------------------------------------
/// Из brand.shadow. Четыре ступени по назначению, а не по размеру.
///
/// Перенос CSS box-shadow во Flutter: `0 4px 6px -1px rgba(...)`
/// раскладывается как offset (0, 4), blurRadius 6, spreadRadius -1.
/// Порядок слоёв сохранён — в CSS первым идёт верхний слой, в списке
/// BoxShadow отрисовка идёт в том же порядке.
class AppBrandElevation {
  AppBrandElevation._();

  /// Карточка объявления при наведении/подъёме (= CSS shadow-md).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.1)
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// Выпадающие списки: пикер марки, панель фильтров.
  static const List<BoxShadow> dropdown = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -4,
    ),
  ];

  /// Модальные окна и шторка фильтров.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];

  /// Залипающая шапка: тень появляется только при прокрутке.
  static const List<BoxShadow> sticky = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
}

// ------------------------------------------------------------
// Слои по оси Z.
// ------------------------------------------------------------
/// Из brand.zIndex. Во Flutter порядок задаётся деревом виджетов, но
/// шкала нужна для Stack, Overlay и elevation модальных слоёв, чтобы
/// приоритеты совпадали с сайтом: шторка фильтров перекрывает шапку.
class AppBrandZ {
  AppBrandZ._();

  static const double header = 40;
  static const double filterSheet = 50;
  static const double modal = 60;
  static const double tooltip = 70;
}

// ------------------------------------------------------------
// Анимации.
// ------------------------------------------------------------
/// Из brand.motion. Две длительности: мгновенная реакция на действие
/// (наведение, нажатие) и переход слоя (открытие шторки). Кривая одна —
/// ease-out: быстрый старт и мягкая остановка ощущаются отзывчивее
/// симметричной ease-in-out.
class AppBrandMotion {
  AppBrandMotion._();

  /// 150ms — нажатие, смена состояния контрола.
  static const Duration fast = Duration(milliseconds: 150);

  /// 300ms — открытие шторки, переход слоя.
  static const Duration normal = Duration(milliseconds: 300);

  /// cubic-bezier(0, 0, 0.2, 1) — CSS ease-out.
  static const Cubic easing = Cubic(0, 0, 0.2, 1);
}
