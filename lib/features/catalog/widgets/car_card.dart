// ============================================================
// RS AUTO — Карточка объявления в списке.
// ============================================================
// Зеркало components/CarCard.tsx сайта: белая карточка с рамкой
// neutral10, фото 4:3, заголовок body semibold, цена primary, мета и
// город — caption нейтральных ступеней.
//
// Раньше карточка жила прямо в catalog_screen.dart и хардкодила свои
// цвета (#FFFFFF, #CCCCCC, #F0F0F0, радиус 3px). Вынесена в отдельный
// файл по образцу сайта: она нужна и в каталоге, и в избранном, и в
// «похожих», и вид у неё должен быть один.
//
// ВЫСОТА. Карточка не задаёт себе фиксированных высот текстовых блоков:
// раньше под заголовок резервировался SizedBox(height: 40), а сетка
// считала общую высоту от константы textBlockH = 140 — при другом
// размере шрифта или масштабе текста системы контент переставал
// помещаться, и появлялось «BOTTOM OVERFLOWED BY 2.5 PIXELS». Теперь
// текстовый блок занимает столько, сколько нужно (Column + mainAxisSize
// .min), а фото отдаёт лишнее место через Flexible — переполнение
// невозможно по построению.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/enums/car_status.dart';
import '../../../shared/widgets/status_badge.dart';

class CarCard extends StatelessWidget {
  const CarCard({
    super.key,
    required this.car,
    required this.isFavorite,
    required this.isViewed,
    required this.onOpen,
    required this.onToggleFavorite,
    this.onHide,
    this.onHideCity,
    this.photoUrl,
  });

  final CarModel car;
  final bool isFavorite;
  final bool isViewed; // true → плашка «Просмотрено» на фото
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  /// «Не интересует объявление». null — меню «три точки» не показывается
  /// (в избранном скрывать нечего).
  final VoidCallback? onHide;

  /// «Не подходит город или регион».
  final VoidCallback? onHideCity;

  /// Готовая ссылка на фото. null — карточка загрузит её сама.
  /// Передаётся там, где список уже знает свои фотографии.
  final String? photoUrl;

  // Число с разделителем разрядов пробелом: 1000000 → «1 000 000».
  static String _money(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // Меню «три точки» — «Скрыть рекомендацию».
  void _openHideMenu(BuildContext context) {
    final t = context.t;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppBrandSpacing.md,
                AppBrandSpacing.md,
                AppBrandSpacing.md,
                AppBrandSpacing.sm,
              ),
              child: Text(
                t.catalogHideRecommendation,
                style: AppBrandText.h4
                    .copyWith(color: AppBrandColors.neutral100),
              ),
            ),
            if (onHide != null)
              ListTile(
                title: Text(t.catalogHideCar, style: AppBrandText.body),
                onTap: () {
                  Navigator.pop(ctx);
                  onHide!();
                },
              ),
            if (onHideCity != null)
              ListTile(
                title: Text(t.catalogHideCity, style: AppBrandText.body),
                onTap: () {
                  Navigator.pop(ctx);
                  onHideCity!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // Какая цена главная. Машина только в аренду — суточная ставка;
    // иначе цена продажи. Нет цены → «Договорная».
    final rentOnly = car.isForRent && !car.isForSale;
    // Суточная ставка — «45 EUR / сутки», как formatRentPrice на сайте:
    // единица одним коротким словом (carPerDay), а не подписью «Аренда в
    // сутки» — она не помещалась в строку и обрезалась многоточием.
    final priceText = rentOnly && car.rentPriceDaily != null
        ? '${_money(car.rentPriceDaily!)} ${car.currency.value} / ${t.carPerDay}'
        : car.salePrice != null
            ? '${_money(car.salePrice!)} ${car.currency.value}'
            : t.priceNegotiable;

    // Мета «год · пробег» одной строкой, как на сайте.
    final meta = car.mileage != null
        ? '${car.year} · ${_money(car.mileage!)} км'
        : '${car.year}';

    // Рейтинг приписывается к городу, если отзывы есть.
    final rating = car.reviewsCount > 0
        ? ' · ⭐ ${car.ratingAvg.toStringAsFixed(1)}'
        : '';

    return Material(
      color: AppBrandColors.bg,
      borderRadius: AppBrandRadius.cardAll,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppBrandRadius.cardAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppBrandColors.bg,
            borderRadius: AppBrandRadius.cardAll,
            border: Border.all(color: AppBrandColors.neutral10),
            boxShadow: AppBrandElevation.card,
          ),
          child: ClipRRect(
            borderRadius: AppBrandRadius.cardAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Фото 4:3. Flexible, а не жёсткий AspectRatio: если сетка
                // выделила карточке меньше высоты, чем нужно тексту, ужимается
                // фотография, а не появляется overflow.
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CarThumb(
                          carId: car.id,
                          brand: car.brand,
                          photoUrl: photoUrl,
                        ),
                        if (isViewed)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: StatusBadge(
                              label: t.catalogViewed,
                              background: AppBrandColors.neutral60,
                            ),
                          ),
                        // Продвижение — золотой бейдж слева снизу, чтобы не
                        // столкнуться с «Просмотрено» в том же углу.
                        if (car.isPromoted)
                          Positioned(
                            left: AppBrandSpacing.sm,
                            bottom: AppBrandSpacing.sm,
                            child: StatusBadge(
                              label: t.catalogPromoted,
                              background: AppBrandColors.gold,
                            ),
                          ),
                        // Аренда — синий бейдж: в смешанной ленте продажа и
                        // аренда стоят рядом, и «/сутки» в строке цены
                        // различить труднее, чем цвет и слово.
                        if (car.isForRent && !car.isForSale)
                          Positioned(
                            right: AppBrandSpacing.sm,
                            top: AppBrandSpacing.sm,
                            child: StatusBadge(
                              label: t.badgeRent,
                              background: AppBrandColors.blue,
                            ),
                          ),
                        if (car.status == CarStatus.sold)
                          Positioned(
                            right: AppBrandSpacing.sm,
                            bottom: AppBrandSpacing.sm,
                            child: StatusBadge(
                              label: t.carSold,
                              background: AppBrandColors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Текстовый блок. mainAxisSize.min — занимает ровно свою
                // высоту; именно это убирает переполнение сетки.
                Padding(
                  // 12px — p-3 карточки на сайте. Ступени sm (8) не хватало:
                  // текст лип к краям и к фотографии.
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок + избранное. Заголовок в ОДНУ строку, как
                      // на сайте: две строки требовали резервировать высоту
                      // под самый длинный вариант у всех карточек сразу.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${car.brand} ${car.model}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppBrandText.body.copyWith(
                                color: AppBrandColors.neutral100,
                                fontWeight: AppBrandFont.semibold,
                              ),
                            ),
                          ),
                          _IconAction(
                            icon: isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isFavorite
                                ? AppBrandColors.red
                                : AppBrandColors.neutral60,
                            onTap: onToggleFavorite,
                          ),
                        ],
                      ),

                      // Цена и меню «три точки» в одном ряду. Цена в
                      // Expanded с ellipsis — длинная сумма ужимается,
                      // а не выдавливает кнопку за край.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              priceText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppBrandText.body.copyWith(
                                color: AppBrandColors.primary,
                                fontWeight: AppBrandFont.semibold,
                              ),
                            ),
                          ),
                          if (onHide != null || onHideCity != null)
                            _IconAction(
                              icon: Icons.more_horiz,
                              color: AppBrandColors.neutral60,
                              onTap: () => _openHideMenu(context),
                            ),
                        ],
                      ),

                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppBrandText.caption
                            .copyWith(color: AppBrandColors.neutral60),
                      ),
                      Text(
                        '${car.city}$rating',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppBrandText.caption
                            .copyWith(color: AppBrandColors.neutral60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Иконка-действие в карточке (избранное, «три точки»). Область нажатия
// шире самой иконки: 22px — меньше минимальной цели касания.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.only(left: AppBrandSpacing.xs),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

// Фотография объявления. Пока грузится или если фото нет — подложка
// surfaceMuted с названием марки, как на сайте (раньше здесь на всю
// площадь растягивался логотип, и карточка без фото выглядела как
// объявление о продаже логотипа).
//
// Ссылку можно передать снаружи (photoUrl) — тогда карточка ничего не
// запрашивает. Это нужно там, где список уже знает свои фотографии, и
// делает карточку пригодной для отрисовки без бэкенда.
class _CarThumb extends StatefulWidget {
  const _CarThumb({
    required this.carId,
    required this.brand,
    this.photoUrl,
  });

  final String carId;
  final String brand;
  final String? photoUrl;

  @override
  State<_CarThumb> createState() => _CarThumbState();
}

class _CarThumbState extends State<_CarThumb> {
  String? _url;

  @override
  void initState() {
    super.initState();

    // Ссылка известна заранее — запрашивать нечего.
    if (widget.photoUrl != null) {
      _url = widget.photoUrl;
      return;
    }

    CarsRepository().fetchImages(widget.carId).then((imgs) {
      if (mounted && imgs.isNotEmpty) {
        setState(() => _url = imgs.first.imageUrl);
      }
    }).catchError((_) {
      // Молча: остаётся подложка с маркой.
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppBrandColors.surfaceMuted,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(AppBrandSpacing.sm),
        child: Text(
          widget.brand,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppBrandText.caption
              .copyWith(color: AppBrandColors.neutral30),
        ),
      ),
    );

    if (_url == null) return placeholder;

    return Image.network(
      _url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
