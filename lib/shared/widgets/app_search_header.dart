// ============================================================
// RS AUTO — Общая шапка приложения.
// ============================================================
// Зеркало components/SiteHeader.tsx сайта, один в один: логотип-название,
// переключатель языка SR/RU, зелёный CTA продавцу и меню в самом правом
// краю. Высота ряда 56 (h-14 сайта), снизу граница neutral10.
//
// Раньше шапка состояла из картинки-логотипа высотой 60 и строки поиска —
// она не совпадала с сайтом ни по составу, ни по высоте, ни по виду знака.
//
// СТРОКИ ПОИСКА ЗДЕСЬ БОЛЬШЕ НЕТ. Свободный поиск переехал в форму
// фильтров первым полем — ровно как на сайте, где единственное поле
// свободного ввода живёт в панели фильтров, а не в шапке.
//
// ВСЯ НАВИГАЦИЯ — В ЭТОМ МЕНЮ. Нижней панели вкладок больше нет: на
// сайте её нет тоже, а разделы открываются из бургера. Меню держит и
// основные разделы (каталог, избранное, сообщения, профиль), и то, что
// раньше пряталось в профиле (мои объявления, кошелёк).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_brand.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import 'brand_logo.dart';
import 'locale_switch.dart';

class AppSearchHeader extends StatelessWidget {
  const AppSearchHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppBrandColors.bg,
        border: Border(
          bottom: BorderSide(color: AppBrandColors.neutral10),
        ),
      ),
      child: SizedBox(
        // h-14 сайта.
        height: 56,
        child: Padding(
          // pl-3 слева; справа отступа НЕТ: у кнопки меню есть свой
          // внутренний паддинг, и внешний добавлялся бы к нему — бургер
          // стоял бы в 16px от края вместо 8, как на сайте.
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              // Логотип уступает место первым и только он: Expanded с
              // выравниванием влево занимает всю свободную ширину и сам
              // же обрезает знак, если места мало. Правая группа при
              // этом всегда получает свою натуральную ширину — раньше
              // CTA стояла в Flexible и обрезалась до «Продать а…».
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.go('/catalog'),
                    behavior: HitTestBehavior.opaque,
                    child: const BrandLogo(),
                  ),
                ),
              ),

              // Зазоры внутри группы одинаковые (gap-1.5 = 6 на сайте):
              // раньше между языком и CTA было 8, а между CTA и бургером
              // 4, и группа выглядела неровной.
              const LocaleSwitch(),
              const SizedBox(width: 6),

              // Сильный CTA продавцу — главная бизнес-цель площадки,
              // единственный акцентный элемент шапки.
              _SellButton(label: t.navSell),
              const SizedBox(width: 6),

              // Меню — у самого правого края, как бургер на сайте.
              const AppMenuButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// Зелёная кнопка «Продать авто». Компактная (size xs сайта): в ряду с
// логотипом и языком она обязана поместиться на 360px.
class _SellButton extends StatelessWidget {
  const _SellButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrandColors.green,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: () => context.push('/create-car'),
        borderRadius: AppBrandRadius.controlAll,
        child: Padding(
          // px-2.5 py-2.5 сайта. Прежние 8×6 делали кнопку ниже и уже
          // сайтовой — на скриншотах это было первым, что бросалось.
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            // Перенос на две строки ломает высоту ряда.
            overflow: TextOverflow.ellipsis,
            style: AppBrandText.small.copyWith(
              color: Colors.white,
              fontWeight: AppBrandFont.semibold,
            ),
          ),
        ),
      ),
    );
  }
}

// Кнопка меню. Держит бейдж непрочитанных сообщений: раньше он висел на
// вкладке «Сообщения» внизу, а без нижней панели о новых сообщениях было
// бы неоткуда узнать, не открыв меню.
/// Кнопка меню — вся навигация приложения. Публичная: нужна не только в
/// шапке каталога, но и в AppBar разделов без неё (профиль).
class AppMenuButton extends StatefulWidget {
  const AppMenuButton({super.key});

  @override
  State<AppMenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<AppMenuButton> {
  // Репозитории создаются ЛЕНИВО, внутри initState, и только когда есть
  // залогиненный пользователь. Поля с инициализацией прямо в классе
  // требовали бы живого Supabase при каждой отрисовке шапки — включая
  // случаи, где его нет (виджет-тесты, ранний кадр до инициализации).
  ChatRepository? _chats;

  StreamSubscription<void>? _sub;
  int _unread = 0;

  @override
  void initState() {
    super.initState();

    // Гостю сообщения не приходят — счётчик ему не нужен, а лишний
    // запрос к бэкенду тем более.
    try {
      if (AuthRepository().currentUser == null) return;
      _chats = ChatRepository();
    } catch (_) {
      // Supabase недоступен (например, в тестах) — шапка обязана
      // отрисоваться и без счётчика.
      return;
    }

    _refresh();
    _sub = _chats!.unreadSignals().listen((_) => _refresh());
  }

  // Счётчик считает сервер (get_unread_count): он учитывает участие в чате
  // и исключает заблокированных отправителей. Повторить это на клиенте
  // нельзя — данных о блокировках в потоке нет.
  Future<void> _refresh() async {
    try {
      final value = await _chats!.totalUnread();
      if (!mounted) return;
      if (value != _unread) setState(() => _unread = value);
    } catch (_) {
      // Бейдж не критичен: при сбое сети оставляем прежнее значение.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      customBorder: const CircleBorder(),
      child: Padding(
        // Справа 8 = pr-2 контейнера сайта: этот отступ и отделяет
        // иконку от края экрана, внешнего у ряда нет.
        padding: const EdgeInsets.fromLTRB(
          AppBrandSpacing.sm,
          AppBrandSpacing.sm,
          AppBrandSpacing.sm,
          AppBrandSpacing.sm,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.menu, size: 24, color: AppBrandColors.neutral100),
            if (_unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppBrandColors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unread > 99 ? '99+' : '$_unread',
                    textAlign: TextAlign.center,
                    // Мельче ступени small: цифра должна уместиться
                    // в кружок 16px поверх иконки.
                    style: AppBrandText.small.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: AppBrandFont.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final t = context.t;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppBrandColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBrandRadius.card),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Основные разделы — те же, что раньше были вкладками внизу.
              // go, а не push: это переключение раздела, а не переход
              // вглубь, и стек экранов копиться не должен.
              _MenuItem(
                icon: Icons.grid_view_outlined,
                label: t.navCatalog,
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/catalog');
                },
              ),
              _MenuItem(
                icon: Icons.favorite_border,
                label: t.navFavorites,
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/favorites');
                },
              ),
              _MenuItem(
                icon: Icons.chat_bubble_outline,
                label: t.navMessages,
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/chats');
                },
              ),
              _MenuItem(
                icon: Icons.person_outline,
                label: t.navProfile,
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/profile');
                },
              ),

              const Divider(height: 1, color: AppBrandColors.neutral10),

              // Разделы второго уровня: раньше открывались только из
              // профиля.
              _MenuItem(
                icon: Icons.list_alt_outlined,
                label: t.myCarsTitle,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/my-cars');
                },
              ),
              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: t.profileBalance,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/wallet');
                },
              ),
              const SizedBox(height: AppBrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: AppBrandColors.neutral60),
      title: Text(
        label,
        style: AppBrandText.body.copyWith(
          color: AppBrandColors.neutral100,
          fontWeight: AppBrandFont.medium,
        ),
      ),
    );
  }
}
