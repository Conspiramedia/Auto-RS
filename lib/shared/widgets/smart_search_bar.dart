// ============================================================
// AUTO.RS — SmartSearchBar: строка поиска с «живой» подсказкой.
//
// Пока поле пустое и не в фокусе — по кругу крутятся примеры запросов
// (марки/модели/города авто-рынка Сербии). Короткая фраза стоит 3,5 с
// и сменяется следующей со случайным эффектом (растворение / выезд
// сверху-снизу / масштаб). Длинная фраза не влезает — плавно катится
// бегущей строкой (стиль Apple Music), даёт дочитать и уезжает.
//
// Тап по строке превращает её в активное поле ввода прямо в шапке
// (без отдельного экрана): вызывается onChanged/onSubmitted, лента
// фильтруется по введённому тексту. Крестик очищает и возвращает
// «живые» подсказки.
//
// Стиль под бренд: тёмная плашка с градиентом, золотая иконка-лупа,
// скругление 16, высота 49 — как у кнопок «Фильтри» и языка в шапке.
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Золотой акцент иконки на тёмных плашках бренда.
const Color _kGold = Color(0xFFE8A73C);

// Подсказки ПО УМОЛЧАНИЮ — примеры запросов авто-рынка Сербии (каталог).
// Экран может передать свой список через параметр hints (поиск по избранному,
// по диалогам и т.п.). Короткие стоят статично, длинные — бегущей строкой.
const List<String> kDefaultCatalogHints = [
  'Golf 7 1.6 TDI',
  'Audi A4 B8 quattro',
  'BMW 320d Beograd',
  'Škoda Octavia karavan',
  'Mercedes C klasa',
  'Passat B8 automatik',
  'Fiat Punto do 3000€',
  'Opel Astra 2015',
  'Renault Clio benzin',
  'Toyota Yaris hitno',
  'Peugeot 308 dizel',
  'Ford Focus Novi Sad',
  'Volkswagen Polo prvi vlasnik',
  'Dacia Duster 4x4',
  'Kia Sportage Niš',
  'Hyundai i30 na ime kupca',
  'Citroën C3 automatik',
  'Nissan Qashqai 2018',
  'Seat Leon FR',
  'Mazda CX-5 zamena',
  'Golf 6 do 5000 evra',
  'BMW X5 full oprema',
  'Mercedes GLA registrovan',
  'Audi Q5 S-line',
  'Škoda Superb 2.0 TDI',
];

/// Эффект смены подсказки в AnimatedSwitcher.
enum _HintTransition {
  fade, // плавное растворение
  slideUp, // старая улетает вверх, новая выезжает снизу
  slideDown, // старая улетает вниз, новая выезжает сверху
  scale, // появление с лёгким увеличением
}

class SmartSearchBar extends StatefulWidget {
  const SmartSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.hints = kDefaultCatalogHints,
  });

  /// Текущий текст запроса (null/пусто — крутим подсказки).
  final String? value;

  /// Список «живых» подсказок под тему экрана. По умолчанию — каталог авто.
  final List<String> hints;

  /// Живой ввод: вызывается на каждое изменение текста.
  final ValueChanged<String> onChanged;

  /// Отправка запроса (Enter/иконка поиска на клавиатуре).
  final ValueChanged<String>? onSubmitted;

  @override
  State<SmartSearchBar> createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<SmartSearchBar> {
  /// Длительность анимации перехода между подсказками.
  static const Duration _switchDuration = Duration(milliseconds: 300);

  final Random _random = Random();
  final FocusNode _focus = FocusNode();
  late final TextEditingController _controller;

  // Текущая подсказка и эффект её появления.
  late int _hintIndex;
  _HintTransition _transition = _HintTransition.fade;

  // Ротация приостановлена (поле в фокусе или введён текст).
  bool _hintsPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
    // Стартуем со случайной фразы, чтобы подсказки не приедались.
    _hintIndex =
        widget.hints.isEmpty ? 0 : _random.nextInt(widget.hints.length);
  }

  @override
  void didUpdateWidget(covariant SmartSearchBar old) {
    super.didUpdateWidget(old);
    // Внешний сброс запроса (например, кнопкой очистки фильтров).
    final v = widget.value ?? '';
    if (v != _controller.text && !_focus.hasFocus) {
      _controller.text = v;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  void _onTextChanged() {
    setState(() {}); // показать/скрыть крестик и подсказки
    widget.onChanged(_controller.text);
  }

  void _onFocusChanged() {
    // В фокусе подсказки не крутим; при выходе без текста — возобновляем.
    _hintsPaused = _focus.hasFocus;
    if (!_focus.hasFocus && !_hasText) {
      _nextHint();
    }
    setState(() {});
  }

  /// Фраза «дожила» цикл показа — показываем следующую.
  void _onHintCycleDone() {
    if (!mounted || _hintsPaused || _hasText) return;
    _nextHint();
  }

  /// Следующая подсказка: случайный индекс БЕЗ повтора текущего и
  /// случайный эффект перехода.
  void _nextHint() {
    // Меньше 2 фраз — крутить нечего (цикл не меняет индекс).
    if (widget.hints.length < 2) return;
    var next = _random.nextInt(widget.hints.length - 1);
    if (next >= _hintIndex) next++;
    setState(() {
      _hintIndex = next;
      _transition =
          _HintTransition.values[_random.nextInt(_HintTransition.values.length)];
    });
  }

  void _clear() {
    _controller.clear(); // слушатель сам вызовет onChanged('')
    _focus.unfocus();
  }

  /// Переход для AnimatedSwitcher. Уходящий ребёнок проигрывает анимацию
  /// в реверсе, поэтому направление слайда задаём по роли (входящий/
  /// уходящий — различаем по ключу): старая улетает вверх, новая снизу.
  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    final bool incoming = child.key == ValueKey<int>(_hintIndex);

    switch (_transition) {
      case _HintTransition.fade:
        return FadeTransition(opacity: animation, child: child);

      case _HintTransition.slideUp:
        final begin = incoming ? const Offset(0, 1) : const Offset(0, -1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );

      case _HintTransition.slideDown:
        final begin = incoming ? const Offset(0, -1) : const Offset(0, 1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );

      case _HintTransition.scale:
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    // Показываем «живые» подсказки, только когда поле пустое и не в фокусе.
    final showHint = !_focus.hasFocus && !_hasText && widget.hints.isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        // Фирменный тёмный градиент — как у DarkPillButton.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A3E), Color(0xFF242427)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 49,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            children: [
              const Icon(Icons.search, color: _kGold, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Реальное поле ввода: невидимую подсказку прячем,
                    // чтобы своя анимированная не дублировалась.
                    TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: _kGold,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                      ),
                    ),
                    // Анимированная подсказка поверх пустого поля.
                    // IgnorePointer — тапы проходят в TextField под ней.
                    if (showHint)
                      IgnorePointer(
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: _switchDuration,
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: _transitionBuilder,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            child: _MarqueeHint(
                              key: ValueKey<int>(_hintIndex),
                              text: widget.hints[
                                  _hintIndex.clamp(0, widget.hints.length - 1)],
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF9A9AA0),
                              ),
                              onCycleDone: _onHintCycleDone,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Крестик — только когда есть что очищать.
              if (_hasText)
                GestureDetector(
                  onTap: _clear,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.close, size: 20, color: Color(0xFF9A9AA0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// БЕГУЩАЯ СТРОКА ПОДСКАЗКИ (стиль Apple Music / Spotify)
//
// Короткая фраза (влезает в поле) стоит 3,5 с и уступает место следующей.
// Длинная: пауза 2 с → плавно катится влево до конца (постоянная скорость)
// → замирает 1,5 с → мягко возвращается в начало → пауза — и только потом
// сообщает о завершении цикла (onCycleDone). Прокрутка программная
// (NeverScrollableScrollPhysics): палец поле не скроллит.
// -------------------------------------------------------------

class _MarqueeHint extends StatefulWidget {
  const _MarqueeHint({
    super.key,
    required this.text,
    required this.style,
    required this.onCycleDone,
  });

  final String text;
  final TextStyle style;
  final VoidCallback onCycleDone;

  @override
  State<_MarqueeHint> createState() => _MarqueeHintState();
}

class _MarqueeHintState extends State<_MarqueeHint> {
  final ScrollController _scroll = ScrollController();

  /// Сколько стоит короткая фраза (шаг ротации).
  static const Duration _shortDisplay = Duration(milliseconds: 3500);

  /// Пауза перед стартом прокатки длинной фразы.
  static const Duration _startHold = Duration(seconds: 2);

  /// Пауза в конце фразы («дочитать хвост»).
  static const Duration _endHold = Duration(milliseconds: 1500);

  /// Скорость прокатки, px/с — спокойная, читабельная.
  static const double _speed = 40;

  @override
  void initState() {
    super.initState();
    // Замер переполнения возможен только после первой отрисовки.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCycle());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _runCycle() async {
    if (!mounted) return;
    final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;

    // Фраза влезает целиком — просто стоим положенное время.
    if (max <= 0) {
      await Future.delayed(_shortDisplay);
      if (mounted) widget.onCycleDone();
      return;
    }

    // Длинная: пауза → прокатка до конца → пауза → возврат → пауза.
    await Future.delayed(_startHold);
    if (!mounted) return;
    await _scroll.animateTo(
      max,
      // Постоянная скорость: длительность пропорциональна расстоянию.
      duration: Duration(milliseconds: (max / _speed * 1000).round()),
      curve: Curves.linear,
    );
    if (!mounted) return;
    await Future.delayed(_endHold);
    if (!mounted) return;
    await _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) widget.onCycleDone();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    );
  }
}
