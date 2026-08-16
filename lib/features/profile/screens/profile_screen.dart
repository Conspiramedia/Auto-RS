// ============================================================
// AUTO.RS — Экран профиля: данные, баланс вендора, «Мои объявления»,
// панель модерации (админ), выход. Все действия — плашки одной ширины.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/utils/serbian_phone.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/notif_bell.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/language_picker.dart';
import '../../../shared/widgets/pill_back_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthRepository();
  final _profileRepo = ProfileRepository();
  final _walletRepo = WalletRepository();
  final _admin = AdminRepository();
  final _picker = ImagePicker();

  bool _loading = false;
  bool _isAdmin = false;
  bool _savingAvatar = false; // идёт загрузка/сохранение аватара

  late Future<_ProfileData> _future;

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    showAppSnack(context, msg, success: success);
  }

  // Выбрать фото из галереи → загрузить в Storage → записать avatar_url.
  Future<void> _pickAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512, // аватар небольшой — не грузим тяжёлые файлы
      imageQuality: 85,
    );
    if (file == null) return;

    // Текст читаем до await: после асинхронного разрыва обращаться к
    // context нельзя — экран мог быть закрыт.
    if (!mounted) return;
    final okMessage = context.t.profilePhotoUpdated;

    setState(() => _savingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await _profileRepo.uploadAvatar(bytes);
      await _profileRepo.updateProfile(avatarUrl: url);
      _snack(okMessage, success: true);
      _reload();
    } catch (e) {
      _snack('Не удалось обновить фото: ${humanizeError(e)}');
    } finally {
      if (mounted) setState(() => _savingAvatar = false);
    }
  }

  // Диалог ввода/изменения имени пользователя.
  Future<void> _editName(String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t.profileYourName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: context.t.profileNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null) return; // отмена
    if (!mounted) return;
    final savedMessage = context.t.profileNameSaved;

    try {
      await _profileRepo.updateProfile(fullName: name);
      _snack(savedMessage, success: true);
      _reload();
    } catch (e) {
      _snack('Не удалось сохранить имя: ${humanizeError(e)}');
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Грузим профиль + баланс + флаг админа
  Future<_ProfileData> _load() async {
    final profile = await _profileRepo.fetchMyProfile();
    final uid = _auth.currentUser?.id;

    double balance = 0;
    bool admin = false;
    if (uid != null) {
      // Баланс КОШЕЛЬКА (get_balance = сумма wallet_transactions), а не
      // прежний getVendorBalance — тот считает завершённые выплаты по
      // арендным броням и к личному балансу отношения не имеет.
      balance = await _walletRepo.getBalance();
      admin = await _admin.isAdmin();
    }
    _isAdmin = admin;
    return _ProfileData(profile: profile, balance: balance);
  }

  // ВАЖНО: блочная форма — колбэк setState НЕ должен возвращать значение.
  // Стрелка `=> _future = _load()` возвращала бы Future, и Flutter кидал бы
  // «setState() callback argument returned a Future».
  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  // Пополнение баланса. Платёжный провайдер не подключён (TODO Этапа 0):
  // на площадке нет платных услуг — продвижение сейчас работает в режиме
  // «подарок». Честно сообщаем, что функция появится позже.
  void _topUp() {
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.profileTopUp),
        content: Text(t.profileTopUpSoon),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    // Подтверждение — защита от случайного выхода одним тапом.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t.profileLogoutTitle),
        content: Text(context.t.profileLogoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Выйти',
              style: TextStyle(color: Color(0xFFE01E23)), // фирменный красный
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _auth.signOut();
      if (mounted) context.go('/catalog');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    // Гость
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const PillBackButton(),
          title: Text(context.t.profileTitle),
          // Язык доступен и без входа: иначе гость с чужим системным языком
          // не смог бы переключиться до авторизации.
          actions: const [LangButton(), SizedBox(width: 8)],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                  radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              Text(context.t.profileGuest),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const PillBackButton(),
        title: const Text('Профиль'),
        actions: [
          // Глобус — выбор языка (лист «Язык / Jezik»). Стоит слева от
          // колокольчика: колокольчик остаётся на привычном крайнем месте.
          const LangButton(),
          // Колокольчик: красный и покачивается при непрочитанных (не-чат).
          NotifBell(onTap: () => context.push('/notifications')),
          const SizedBox(width: 8), // отступ от правого края
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            // LayoutBuilder даёт доступную высоту экрана. Контент кладём в
            // Column с minHeight = высоте вьюпорта: основной блок сверху,
            // Spacer отталкивает «Выйти» к самому низу. Если контента больше
            // высоты экрана — SingleChildScrollView прокручивает всё целиком.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 32),
                    // IntrinsicHeight даёт Column определённую высоту в скролле,
                    // чтобы Spacer (Expanded) корректно распределил свободное
                    // место и увёл «Выйти» к низу.
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Шапка. Подсказки-значки (камера/карандаш) показываем ТОЛЬКО
                          // пока данные не заданы — как приглашение заполнить. Когда фото
                          // и имя есть, значки убираем, но тап по ним всё равно открывает
                          // редактирование (замену).
                          ...(() {
                            final hasAvatar =
                                (data.profile?.avatarUrl?.trim().isNotEmpty ??
                                    false);
                            final hasName =
                                (data.profile?.fullName?.trim().isNotEmpty ??
                                    false);
                            return [
                              Center(
                                child: Column(
                                  children: [
                                    // Аватар — тап всегда открывает выбор фото. Значок
                                    // камеры — только если фото ещё нет (или идёт загрузка).
                                    GestureDetector(
                                      onTap: _savingAvatar ? null : _pickAvatar,
                                      child: Stack(
                                        children: [
                                          _Avatar(
                                            url: data.profile?.avatarUrl,
                                            busy: _savingAvatar,
                                          ),
                                          if (!hasAvatar && !_savingAvatar)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppButtonColors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .scaffoldBackgroundColor,
                                                      width: 2),
                                                ),
                                                child: const Icon(
                                                    Icons.photo_camera,
                                                    size: 16,
                                                    color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Имя — тап всегда открывает редактирование. Карандаш
                                    // (и приглашение «Добавьте имя») — только пока имени нет.
                                    InkWell(
                                      onTap: () =>
                                          _editName(data.profile?.fullName),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              hasName
                                                  ? data.profile!.fullName!
                                                      .trim()
                                                  : 'Добавьте имя',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            if (!hasName) ...[
                                              const SizedBox(width: 6),
                                              const Icon(Icons.edit, size: 16),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Телефон (нормализованный, с +381 и группами) —
                                    // тап копирует в буфер. Если телефона нет — email.
                                    () {
                                      final rawPhone =
                                          data.profile?.phone ?? user.phone;
                                      if (rawPhone != null &&
                                          rawPhone.trim().isNotEmpty) {
                                        final display =
                                            serbianPhoneDisplay(rawPhone);
                                        return InkWell(
                                          onTap: () async {
                                            await Clipboard.setData(
                                                ClipboardData(text: display));
                                            _snack('Номер скопирован',
                                                success: true);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  display,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(Icons.copy,
                                                    size: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      if (user.email != null) {
                                        return Text(
                                          user.email!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ];
                          }()),

                          // Баланс, «Мои объявления» (+ модерация админу) — доступны всем.
                          ...[
                            // Баланс — самым верхом блока. Сумма + кнопка «+»
                            // (пополнение; функционал монетизации — позже).
                            Card(
                              child: ListTile(
                                leading:
                                    const Icon(Icons.account_balance_wallet),
                                title: Text(context.t.profileBalance),
                                // Вся плашка ведёт в историю операций —
                                // естественный жест «нажать на баланс, чтобы
                                // посмотреть, откуда он взялся».
                                onTap: () async {
                                  await context.push('/wallet');
                                  _reload();
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${data.balance.toStringAsFixed(2)} EUR',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(width: 8),
                                    // Пополнить баланс (зелёный «+»).
                                    // Провайдер не подключён — показываем
                                    // честное «скоро», кнопку не прячем,
                                    // чтобы было видно, что она появится.
                                    IconButton(
                                      onPressed: _topUp,
                                      icon: const Icon(Icons.add_circle,
                                          color: AppButtonColors.green),
                                      tooltip: context.t.profileTopUp,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Icon(Icons.chevron_right,
                                        size: 20, color: Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Плашки-пилюли одной ширины (expand: на всю ширину).
                            DarkPillButton(
                              label: 'Мои объявления',
                              variant: PillVariant.green,
                              expand: true,
                              onTap: () async {
                                await context.push('/my-cars');
                                _reload();
                              },
                            ),
                            // «Модерация объявлений» — только админу, сразу под «Мои
                            // объявления». Та же плашка-пилюля, синий вариант.
                            if (_isAdmin) ...[
                              const SizedBox(height: 12),
                              DarkPillButton(
                                label: 'Модерация объявлений',
                                variant: PillVariant.blue,
                                expand: true,
                                onTap: () => context.push('/moderation'),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // «Политика и условия» — просмотр документа (режим
                            // без обязательного принятия). Нейтральная тёмная
                            // плашка, той же ширины.
                            DarkPillButton(
                              label: 'Политика и условия',
                              variant: PillVariant.dark,
                              expand: true,
                              onTap: () => context.push('/policy'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Отталкивает «Выйти» к низу экрана (если контент короче
                          // вьюпорта). При длинном контенте Spacer схлопывается в 0.
                          const Spacer(),

                          // «Выйти из аккаунта» — красная плашка, той же ширины, внизу.
                          DarkPillButton(
                            label: _loading ? 'Выходим…' : 'Выйти из аккаунта',
                            variant: PillVariant.red,
                            expand: true,
                            onTap: _loading ? null : _signOut,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileData {
  final ProfileModel? profile;
  final double balance;
  const _ProfileData({
    required this.profile,
    required this.balance,
  });
}

// Кружок аватара: текущее фото или иконка-заглушка. При busy — затемнение
// и спиннер (идёт загрузка).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.busy});
  final String? url;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.black12,
            backgroundImage: hasUrl ? NetworkImage(url!) : null,
            child: hasUrl
                ? null
                : const Icon(Icons.person, size: 44, color: Colors.white),
          ),
          if (busy)
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
