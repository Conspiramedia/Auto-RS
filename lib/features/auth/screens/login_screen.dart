// ============================================================
// AUTO.RS — Экран входа по телефону + код из SMS (OTP).
// Пароля и регистрации нет: пользователь получает SMS с кодом, вводит
// код — Supabase создаёт/находит аккаунт по номеру.
//
// Два режима захода:
//   • С префиллом номера (из формы объявления) — шаг телефона ПРОПУСКАЕТСЯ:
//     код отправляется сразу, открывается поле ввода кода.
//   • Без префилла (вход через редирект-гард) — сперва ввод телефона.
//
// Код проверяется АВТОМАТИЧЕСКИ при наборе всех цифр (_codeLength) — кнопки
// «Подтвердить» нет. При успехе показываем «Номер подтверждён» и возвращаем
// true вызывающему (форма продолжает публикацию) либо уходим в каталог.
// «Изменить номер» — назад к вводу телефона. «Продолжить как гость» — в каталог.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_strings.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../legal/consent_service.dart';
import '../../legal/screens/policy_screen.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/utils/serbian_phone.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/pill_back_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillPhone});

  // Необязательный префилл телефона (например, контакт из формы объявления).
  final String? prefillPhone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthRepository();

  // Длина кода из SMS. Должна совпадать с настройкой Supabase (по умолч. 6).
  // При наборе этого числа цифр код проверяется автоматически, без кнопки.
  static const int _codeLength = 6;

  // Шаг: false — ввод телефона, true — ввод кода из SMS.
  bool _codeStage = false;
  bool _loading = false;
  // Идёт авто-проверка кода (спиннер вместо поля-кнопки).
  bool _verifying = false;

  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeCtrl = TextEditingController();

  // Номер в формате E.164 (+3816…), на который отправлен код.
  String _sentToE164 = '';

  // Обратный отсчёт до повторной отправки кода.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_onPhoneFocus);
    // Авто-проверка кода: как только введено _codeLength цифр — проверяем.
    _codeCtrl.addListener(_onCodeChanged);
    // Префилл номера из формы объявления (если передан) — прогоняем через
    // тот же форматтер, чтобы вид совпал с маской «+381 …».
    final pre = widget.prefillPhone?.trim();
    if (pre != null && pre.isNotEmpty) {
      _phoneCtrl.value = SerbianPhoneFormatter().formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(text: pre),
      );
      // Номер уже есть — шаг ввода телефона пропускаем: сразу шлём код и
      // открываем экран ввода кода. Делаем после первого кадра.
      if (serbianPhoneToE164(pre) != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
      }
    }
  }

  // Автоматическая проверка кода при наборе нужного числа цифр.
  void _onCodeChanged() {
    final code = _codeCtrl.text.trim();
    if (code.length == _codeLength && !_verifying) {
      _verifyCode();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneFocus.removeListener(_onPhoneFocus);
    _phoneFocus.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.removeListener(_onCodeChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  // При фокусе на пустом поле подставляем «+381 »; при уходе с одним
  // префиксом (без цифр номера) — очищаем, чтобы hint снова был виден.
  void _onPhoneFocus() {
    if (_phoneFocus.hasFocus) {
      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = '+381 ';
        _phoneCtrl.selection =
            TextSelection.collapsed(offset: _phoneCtrl.text.length);
      }
    } else {
      final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits == '381') _phoneCtrl.clear();
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    showAppSnack(context, msg, success: success);
  }

  // Запуск 60-секундного таймера кнопки «Отправить снова».
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  // ---------- Шаг 1: отправка кода ----------
  Future<void> _sendCode() async {
    final e164 = serbianPhoneToE164(_phoneCtrl.text);
    if (e164 == null) {
      _snack(context.t.loginPhoneInvalid);
      return;
    }

    // Согласие с политикой — единая точка на входе. Спрашиваем ОДИН раз,
    // до отправки SMS: аккаунт создаётся входом, поэтому политику логично
    // принять здесь. Согласие фиксируется под ключом гостя, а после успешной
    // проверки кода переносится на uid (см. _verifyCode → migrateGuestToUser).
    // Если пользователь не принял — SMS не отправляем.
    final agreed = await PolicyScreen.ensureAccepted(context);
    if (!mounted || !agreed) return;

    setState(() => _loading = true);
    try {
      await _auth.sendOtp(e164);
      _sentToE164 = e164;
      _startResendTimer();
      if (mounted) setState(() => _codeStage = true);
    } catch (e) {
      _snack(humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Повторная отправка кода (когда таймер истёк).
  Future<void> _resendCode() async {
    if (_resendIn > 0) return;
    // Строку берём ДО await: после него виджет мог быть снят с дерева,
    // и обращение к context стало бы небезопасным.
    final sentMessage = context.t.loginResent;
    setState(() => _loading = true);
    try {
      await _auth.resendOtp(_sentToE164);
      _startResendTimer();
      _snack(sentMessage, success: true);
    } catch (e) {
      _snack(humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Шаг 2: проверка кода (автоматически при наборе всех цифр) ----------
  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < _codeLength || _verifying) return;

    // Строки берём ДО await — см. пояснение в _resendCode.
    final verifyFailed = context.t.loginVerifyFailed;

    setState(() => _verifying = true);
    try {
      final res = await _auth.verifyOtp(phone: _sentToE164, token: code);
      if (res.session == null) {
        _snack(verifyFailed);
        _codeCtrl.clear(); // даём ввести заново
        return;
      }
      // Согласие давалось под ключом гостя (до создания аккаунта) —
      // переносим его на реальный uid, чтобы политику не спрашивали снова.
      final uid = _auth.currentUser?.id;
      if (uid != null) {
        await ConsentService.instance.migrateGuestToUser(uid);
      }
      if (!mounted) return;
      _snack(context.t.loginPhoneConfirmed, success: true); // зелёный фон — успех
      // Экран открыт поверх формы объявления (Navigator.push) — возвращаем true,
      // чтобы вызывающий продолжил свой сценарий (загрузка фото / публикация).
      // Если возвращаться некуда (вход через редирект-гард роутера) — в каталог.
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(true);
      } else {
        context.go('/catalog');
      }
    } catch (e) {
      _snack(_humanOtpError(e));
      _codeCtrl.clear(); // неверный/истёкший код — очищаем для повторного ввода
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // Человеческие тексты для типичных ошибок OTP.
  String _humanOtpError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('expired')) return context.t.loginCodeExpired;
    if (s.contains('invalid') || s.contains('incorrect')) {
      return context.t.loginCodeInvalid;
    }
    return humanizeError(e);
  }

  // Вернуться к вводу номера.
  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _codeStage = false;
      _resendIn = 0;
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Auto RS')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  _codeStage ? context.t.loginCodeLabel : context.t.loginTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _codeStage
                      ? context.t.codeSentTo(_sentToE164)
                      : context.t.loginHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (!_codeStage) ..._phoneStage() else ..._codeStageWidgets(),

                const Divider(height: 32),

                // Гостевой режим — сразу в каталог
                TextButton(
                  onPressed: _loading ? null : () => context.go('/catalog'),
                  child: Text(context.t.loginAsGuest),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Виджеты шага «телефон».
  List<Widget> _phoneStage() => [
        TextField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [SerbianPhoneFormatter()],
          onSubmitted: (_) => _sendCode(),
          decoration: InputDecoration(
            labelText: context.t.loginPhoneLabel,
            hintText: '+381 6X XXX XXX',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        // Главное действие — фирменная плашка-пилюля (зелёный вариант),
        // как «Опубликовать»/«Позвонить» в остальном приложении.
        DarkPillButton(
          label: _loading ? context.t.loginSending : context.t.loginSendCode,
          variant: PillVariant.green,
          expand: true,
          onTap: _loading ? null : _sendCode,
        ),
      ];

  // Виджеты шага «код». Кнопки «Подтвердить» нет: код проверяется сам,
  // как только введены все _codeLength цифр. Пока идёт проверка — спиннер.
  List<Widget> _codeStageWidgets() => [
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          enabled: !_verifying, // на время проверки ввод блокируем
          maxLength: _codeLength,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '·' * _codeLength,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // Индикатор авто-проверки (вместо кнопки подтверждения).
        SizedBox(
          height: 24,
          child: _verifying
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Spinner(),
                    const SizedBox(width: 10),
                    Text(context.t.loginChecking),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _verifying ? null : _changeNumber,
              child: Text(context.t.loginChangeNumber),
            ),
            TextButton(
              onPressed:
                  (_verifying || _loading || _resendIn > 0) ? null : _resendCode,
              child: Text(
                _resendIn > 0
                    ? context.t.resendIn(_resendIn)
                    : context.t.loginResend,
              ),
            ),
          ],
        ),
      ];
}

// Компактный индикатор загрузки внутри кнопки.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
