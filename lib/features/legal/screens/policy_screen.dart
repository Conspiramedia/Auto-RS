// ============================================================
// AUTO.RS — Экран политики конфиденциальности и условий использования.
//
// Два режима (флаг requireAccept):
//   • requireAccept = false — ПРОСМОТР (открыт из профиля). Стрелки «назад»
//     нет; внизу — зелёная кнопка «Хорошо», которой экран и закрывается.
//     В конце текста — статус согласия (принято/не принято + версия).
//   • requireAccept = true  — СОГЛАСИЕ (перед входом по SMS, если ещё
//     не принято). Кнопки «назад» нет, системная «назад» заблокирована —
//     закрыть экран можно ТОЛЬКО кнопкой «Принять». После принятия
//     согласие фиксируется и экран закрывается через Navigator.pop(true).
//
// Хелпер PolicyScreen.ensureAccepted(context) — открыть экран в режиме
// согласия и вернуть true, если пользователь принял.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../consent_service.dart';
import '../policy_content.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({
    super.key,
    this.requireAccept = false,
    this.flowAccept = false,
  });

  /// true — режим согласия с КРАТКИМ резюме (открыт при входе по SMS).
  /// Внизу «Принять», по принятию pop(true). Статуса нет.
  final bool requireAccept;

  /// true — ПОЛНЫЙ текст, открытый ИЗ ПОТОКА согласия (по ссылке «Читать
  /// полный текст»). Ведёт себя как шаг согласия: внизу «Принять», по
  /// принятию pop(true) — резюме над ним тоже закроется и продолжит вход.
  /// Статус согласия не показываем — здесь его принимают, а не смотрят.
  final bool flowAccept;

  /// Гарантирует согласие с текущей версией политики.
  ///
  /// Если пользователь (или гость) уже принял текущую версию — сразу
  /// возвращает true, экран не показывается. Иначе открывает экран в
  /// режиме согласия и возвращает true только после нажатия «Принять».
  /// false — пользователь не принял (закрыть иначе, чем приняв, нельзя,
  /// но подстраховываемся на случай программного закрытия).
  static Future<bool> ensureAccepted(BuildContext context) async {
    final uid = AuthRepository().currentUser?.id;
    final accepted = await ConsentService.instance.hasAcceptedCurrent(uid);
    if (accepted) return true;
    if (!context.mounted) return false;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PolicyScreen(requireAccept: true),
        fullscreenDialog: true,
      ),
    );
    return result == true;
  }

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final _auth = AuthRepository();
  bool _accepting = false;

  // Принята ли текущая версия (для статуса в режиме просмотра). null — ещё
  // грузится.
  bool? _accepted;

  // Экран требует принятия: краткое согласие ИЛИ полный текст в потоке входа.
  bool get _isAcceptFlow => widget.requireAccept || widget.flowAccept;

  @override
  void initState() {
    super.initState();
    // Статус (принято/не принято) показываем только в чистом просмотре из
    // профиля — не в потоке согласия.
    if (!_isAcceptFlow) _loadStatus();
  }

  Future<void> _loadStatus() async {
    final accepted = await ConsentService.instance
        .hasAcceptedCurrent(_auth.currentUser?.id);
    if (mounted) setState(() => _accepted = accepted);
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ConsentService.instance.accept(_auth.currentUser?.id);
      if (!mounted) return;
      if (_isAcceptFlow) {
        // Поток согласия (резюме при входе или полный текст по ссылке из него):
        // закрываем экран с true — вызывающий продолжит сценарий (ввод кода).
        Navigator.of(context).pop(true);
      } else {
        // Чистый просмотр из профиля: не выходим, обновляем статус — кнопка
        // внизу сменится с «Принять» на «Хорошо».
        setState(() {
          _accepting = false;
          _accepted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = false);
        showAppSnack(context, 'Не удалось сохранить согласие: ${humanizeError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Пока статус не загружен (_accepted == null) в просмотре — считаем
    // «не принято», чтобы случайно не дать выйти без согласия.
    final acceptedNow = _accepted == true;

    // В потоке согласия внизу «Принять». В чистом просмотре: «Принять» пока
    // не принято, иначе «Хорошо».
    final showAccept = _isAcceptFlow || !acceptedNow;

    // Выход системной «назад» запрещён, пока политика не принята (в потоке
    // согласия и в просмотре с непринятой). Принято → «назад» свободна.
    final canLeave = !_isAcceptFlow && acceptedNow;

    return PopScope(
      canPop: canLeave,
      child: Scaffold(
        appBar: AppBar(
          // Стрелки «назад» нет ни в одном режиме: выход — нижней кнопкой.
          automaticallyImplyLeading: false,
          title: const Text('Политика и условия'),
        ),
        // Краткое резюме — только в режиме requireAccept; иначе полный текст.
        body: widget.requireAccept
            ? _buildConsentBody(theme)
            : _buildFullBody(theme),
        bottomNavigationBar:
            showAccept ? _buildAcceptBar(theme) : _buildOkBar(theme),
      ),
    );
  }

  // Полный текст политики и условий — режим просмотра (из профиля или по
  // ссылке «Читать полностью»).
  Widget _buildFullBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text(
          'Обновлено: $kPolicyUpdatedLabel',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text(
          'Политика конфиденциальности',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          kPrivacyPolicyBodyRu,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 20),
        Text(
          'Условия использования',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          kTermsBodyRu,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
        // Статус согласия — только в чистом просмотре из профиля (не в
        // потоке согласия, где политику принимают, а не смотрят).
        if (!widget.flowAccept) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          _buildStatus(theme),
        ],
      ],
    );
  }

  // Статус согласия: принято (зелёная галочка + версия) или нет.
  // Пока грузится (_accepted == null) — ничего не показываем.
  Widget _buildStatus(ThemeData theme) {
    final accepted = _accepted;
    if (accepted == null) return const SizedBox.shrink();

    final color = accepted ? AppButtonColors.green : AppButtonColors.red;
    final icon = accepted ? Icons.check_circle : Icons.info_outline;
    final title = accepted
        ? 'Политика принята'
        : 'Политика ещё не принята';
    final subtitle = accepted
        ? 'Версия $kPolicyVersion • от $kPolicyUpdatedLabel'
        : 'Согласие запрашивается при входе по SMS.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Нижняя панель режима просмотра: зелёная кнопка «Хорошо» — ею и выходим.
  Widget _buildOkBar(ThemeData theme) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DarkPillButton(
        label: 'Хорошо',
        variant: PillVariant.green,
        expand: true,
        onTap: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  // Компактное резюме для режима согласия: короткие тезисы вместо простыни,
  // чтобы кнопка «Принять» была видна без прокрутки. Полный текст — по ссылке.
  Widget _buildConsentBody(ThemeData theme) {
    // Открыть ПОЛНЫЙ текст в потоке согласия (flowAccept). Там внизу «Принять»;
    // по принятию полный текст закрывается с true и мы сразу закрываем это
    // резюме тоже с true — вход продолжится (ввод кода), без лишнего «Хорошо».
    Future<void> openFull() async {
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PolicyScreen(flowAccept: true)),
      );
      if (accepted == true && mounted) Navigator.of(context).pop(true);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Text(
          'Коротко о главном',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Обновлено: $kPolicyUpdatedLabel',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _bullet(theme, 'Auto RS — площадка объявлений об авто. Приложение не '
            'участвует в сделках; вы общаетесь с продавцами напрямую.'),
        _bullet(theme, 'Ваш номер телефона используется для входа по SMS-коду '
            'и показывается как контакт в ваших объявлениях.'),
        _bullet(theme, 'Вы отвечаете за содержание своих объявлений и '
            'сообщений. Запрещён незаконный и вводящий в заблуждение контент.'),
        _bullet(theme, 'Данные хранятся защищённо; вы можете отредактировать '
            'профиль или запросить удаление аккаунта.'),
        _bullet(theme, 'Сервис доступен лицам 18+. Применяется '
            'законодательство Республики Сербия.'),
        const SizedBox(height: 12),
        // Ссылка на полный текст — для тех, кто хочет прочитать целиком.
        InkWell(
          onTap: () => openFull(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Читать полный текст политики и условий',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Пункт списка-резюме: аккуратная «точка» слева + текст.
  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptBar(ThemeData theme) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Нажимая «Принять», вы соглашаетесь с Политикой '
            'конфиденциальности и Условиями использования.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          DarkPillButton(
            label: _accepting ? 'Сохраняем…' : 'Принять',
            variant: PillVariant.green,
            expand: true,
            onTap: _accepting ? null : _accept,
          ),
        ],
      ),
    );
  }
}
