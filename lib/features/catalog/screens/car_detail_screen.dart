// ============================================================
// AUTO.RS — Экран деталей автомобиля.
// Фото-галерея + характеристики + цена + контакт продавца.
// Связь по объявлению — телефон и чат (аренда и продажа одинаково).
// ============================================================

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/enums/car_status.dart';
import '../../../data/models/car_image_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/models/dealer_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/pill_back_button.dart';

class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  final _carsRepo = CarsRepository();
  final _chatRepo = ChatRepository();
  final _profileRepo = ProfileRepository();
  final _auth = AuthRepository();

  bool _startingChat = false;

  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Грузим машину + фото + витрину продавца.
  //
  // Текст ошибки берём ДО первого await: обращаться к context после
  // асинхронного разрыва нельзя — виджет мог быть уже размонтирован.
  Future<_DetailData> _load() async {
    final notFoundMessage = context.t.carNotFound;

    final car = await _carsRepo.fetchById(widget.carId);
    if (car == null) {
      throw Exception(notFoundMessage);
    }

    // Фото и профиль продавца независимы — запускаем оба запроса сразу,
    // не дожидаясь первого.
    final imagesFuture = _carsRepo.fetchImages(widget.carId);
    final sellerFuture = _loadSeller(car.userId);

    return _DetailData(
      car: car,
      images: await imagesFuture,
      seller: await sellerFuture,
    );
  }

  // Витрина продавца. Ошибку гасим: не загрузился профиль (сеть, удалённый
  // пользователь) — карточку объявления это рушить не должно, просто не
  // покажем блок продавца.
  Future<DealerProfileModel?> _loadSeller(String userId) async {
    try {
      return await _profileRepo.fetchDealerProfile(userId);
    } catch (_) {
      return null;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    showAppSnack(context, msg);
  }

  // Позвонить продавцу: открываем набор номера (tel:). Единая точка события
  // «звонок» — сюда позже подключим серверную аналитику/конверсию (цель).
  Future<void> _call(CarModel car) async {
    // Обе подсказки читаем до await по той же причине, что и в _load.
    final noPhoneMessage = context.t.carNoPhone;
    final callFailedMessage = context.t.carCallFailed;

    final phone = car.contactPhone;
    if (phone == null || phone.trim().isEmpty) {
      _snack(noPhoneMessage);
      return;
    }
    // Звонок гостю свободен: набор номера (tel:) сам по себе данные не
    // собирает. Согласие с политикой берётся один раз на SMS-входе.
    // TODO(analytics): отправить событие phone_call (car.id, user) на бэкенд.
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack(callFailedMessage);
    }
  }

  // Начать чат с продавцом (RPC start_chat) и перейти в комнату
  Future<void> _startChat(CarModel car) async {
    if (_auth.currentUser == null) {
      _snack(context.t.authRequiredWrite);
      return;
    }
    // Согласие с политикой уже получено на SMS-входе (чат требует входа),
    // поэтому отдельно здесь его не спрашиваем.
    setState(() => _startingChat = true);
    try {
      final chatId = await _chatRepo.startChat(car.id);
      if (mounted) {
        context.push('/chat/$chatId', extra: '${car.brand} ${car.model}');
      }
    } catch (e) {
      // Напр.: «Нельзя начать чат с самим собой» (очищаем от тех-деталей)
      _snack(humanizeError(e));
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: Text(context.t.carListingTitle)),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(_DetailData data) {
    final car = data.car;

    return ListView(
      children: [
        // ---------- Галерея фото ----------
        _Gallery(images: data.images),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Text(
                '${car.brand} ${car.model}, ${car.year}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  Text(car.city),
                  if (car.reviewsCount > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text('${car.ratingAvg.toStringAsFixed(1)} '
                        '(${car.reviewsCount})'),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Характеристики ----------
              _SpecsGrid(car: car),
              const SizedBox(height: 16),

              // ---------- Цены (нет цены → «Договорная») ----------
              if (car.isForSale)
                _PriceLine(
                  label: 'Цена продажи',
                  value: car.salePrice != null
                      ? '${_money(car.salePrice!)} ${car.currency.value}'
                      : 'Договорная',
                ),
              if (car.isForRent)
                _PriceLine(
                  label: 'Аренда в сутки',
                  value: car.rentPriceDaily != null
                      ? '${_money(car.rentPriceDaily!)} ${car.currency.value}'
                      : 'Договорная',
                ),

              // ---------- Описание ----------
              if (car.description != null &&
                  car.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Описание',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(car.description!),
              ],

              // ---------- Продавец ----------
              // У дилера строка ведёт на витрину, у частника — просто имя.
              if (data.seller != null) ...[
                const Divider(height: 32),
                _SellerBlock(seller: data.seller!),
              ],

              // ---------- Связь с продавцом: Позвонить + Написать ----------
              // У ПРОДАННОГО объявления связь скрыта: беспокоить продавца
              // по закрытой сделке незачем. Вместо кнопок — плашка-статус.
              const Divider(height: 32),
              if (car.status == CarStatus.sold)
                const _SoldNotice()
              else
                Row(
                  children: [
                    // Позвонить — зелёная (главное действие). Только если есть номер.
                    if (car.contactPhone != null &&
                        car.contactPhone!.trim().isNotEmpty)
                      Expanded(
                        child: DarkPillButton(
                          label: context.t.carCall,
                          icon: Icons.phone,
                          expand: true,
                          variant: PillVariant.green,
                          onTap: () => _call(car),
                        ),
                      ),
                    if (car.contactPhone != null &&
                        car.contactPhone!.trim().isNotEmpty)
                      const SizedBox(width: 10),
                    // Написать — синяя (связь).
                    Expanded(
                      child: DarkPillButton(
                        label: _startingChat ? context.t.carOpening : context.t.carWrite,
                        icon: Icons.chat_bubble_outline,
                        expand: true,
                        variant: PillVariant.blue,
                        onTap: _startingChat ? null : () => _startChat(car),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// Данные экрана
class _DetailData {
  final CarModel car;
  final List<CarImageModel> images;
  // Витрина продавца. null — профиль не загрузился; блок просто не рисуем.
  final DealerProfileModel? seller;
  const _DetailData({
    required this.car,
    required this.images,
    this.seller,
  });
}

// ============================================================
// Блок продавца в карточке объявления.
//
// У ДИЛЕРА строка кликабельна и ведёт на витрину /dealer/{id}: покупателю
// важно посмотреть, что ещё есть у салона и давно ли он на площадке.
// У ЧАСТНИКА — просто имя без ссылки: у него нет витрины, а страница с
// одним объявлением и нулями в счётчиках только запутала бы.
// ============================================================
class _SellerBlock extends StatelessWidget {
  const _SellerBlock({required this.seller});

  final DealerProfileModel seller;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final image = seller.imageUrl;
    final isDealer = seller.isDealer;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(isDealer ? 10 : 22),
            child: SizedBox(
              width: 44,
              height: 44,
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        seller.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isDealer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppButtonColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.carDealerBadge,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t.memberSince(_formatMonthYear(context, seller.memberSince)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isDealer)
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
        ],
      ),
    );

    // Частник кликабельным не делаем — витрины у него нет.
    if (!isDealer) return content;

    return InkWell(
      onTap: () => context.push('/dealer/${seller.id}'),
      child: content,
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          seller.isDealer ? Icons.storefront : Icons.person,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );

  // «август 2025» — названия месяцев из словаря (в intl нет русской локали).
  static String _formatMonthYear(BuildContext context, DateTime date) {
    final months = context.t.monthNames;
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.year}';
  }
}

// Галерея фото (горизонтальная прокрутка). Плейсхолдер, если фото нет.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.images});
  final List<CarImageModel> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      // Нет фото — та же заглушка-лого, что в карточках каталога.
      return Container(
        height: 300,
        color: const Color(0xFFFFFFFF),
        alignment: Alignment.center,
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      );
    }
    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) => _GalleryItem(url: images[i].imageUrl),
      ),
    );
  }
}

// Один кадр галереи. Форматы фото у клиентов разные (вертикальные,
// квадратные, широкие), поэтому подгоняем универсально:
//   • фон — то же фото, растянутое на весь кадр (cover) и РАЗМЫТОЕ;
//   • поверх — то же фото ЦЕЛИКОМ (contain).
// Так фото видно полностью, без обрезки, а пустые поля по бокам залиты
// размытой копией — без «чёрных полос». Ничего не нужно знать о пропорциях.
class _GalleryItem extends StatelessWidget {
  const _GalleryItem({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    // Фото не загрузилось — та же заглушка-лого.
    final placeholder = Container(
      color: const Color(0xFFFFFFFF),
      alignment: Alignment.center,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Фон: размытая растянутая копия фото
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.15)),
        ),
        // Само фото — целиком, по центру
        Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ],
    );
  }
}

// Сетка характеристик
class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final specs = <MapEntry<String, String>>[
      if (car.mileage != null)
        MapEntry('Пробег', '${_money(car.mileage!)} км'),
      if (car.bodyType != null) MapEntry('Кузов', car.bodyType!.value),
      if (car.transmission != null)
        MapEntry('КПП', car.transmission!.value),
      if (car.fuel != null) MapEntry('Топливо', car.fuel!.value),
    ];
    if (specs.isEmpty) return const SizedBox.shrink();

    // По 2 характеристики в ряд, ячейки равной ширины (Expanded).
    // Разбиваем список на пары и рендерим строками.
    final rows = <Widget>[];
    for (int i = 0; i < specs.length; i += 2) {
      final left = specs[i];
      final right = (i + 1 < specs.length) ? specs[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: _specChip(left)),
            const SizedBox(width: 8),
            // Пустая ячейка, если характеристика без пары — ширина колонок ровная.
            Expanded(
              child: right != null
                  ? _specChip(right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  // Ячейка характеристики фиксированного вида (одинаковая высота/оформление).
  Widget _specChip(MapEntry<String, String> e) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${e.key}: ${e.value}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// Строка «метка — значение» для цен
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ПЛАШКА «ПРОДАНО» — заменяет кнопки связи у закрытого объявления.
// Нейтральный серый блок: не призыв к действию, а констатация статуса.
// ============================================================
class _SoldNotice extends StatelessWidget {
  const _SoldNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Объявление продано — связь с продавцом закрыта',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Число с разделителем разрядов пробелом: 1000000 → «1 000 000».
String _money(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
