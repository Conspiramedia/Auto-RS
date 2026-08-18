// ============================================================
// AUTO.RS — Словари интерфейса RU / SR (латиница).
//
// ПОЧЕМУ НЕ .arb + flutter gen-l10n: генератор требует отдельного шага сборки
// и кодогенерации, а локаль в проекте уже резолвится вручную через
// AppLanguageService (см. app_language.dart) — MaterialApp получает готовый
// Locale, свои делегаты не нужны. Простая карта строк даёт то же самое без
// генерации и без риска рассинхрона сгенерированных файлов с исходником.
//
// КАК ПОЛЬЗОВАТЬСЯ В ЭКРАНЕ:
//   final t = context.t;            // расширение на BuildContext
//   Text(t.onboardingBuy)
//
// Локаль берётся из Localizations.localeOf(context), поэтому строки
// переключаются вместе с интерфейсом без перезапуска.
//
// СЕРБСКИЙ — ЛАТИНИЦА. На рынке Сербии латиница преобладает в вебе и
// мобильных интерфейсах; кириллица остаётся для официальных документов.
// Поиск при этом двуалфавитный (f_normalize на сервере), так что выбор
// алфавита интерфейса на результаты не влияет. [[language-plan]]
// ============================================================

import 'package:flutter/widgets.dart';

import 'app_language.dart';

// ------------------------------------------------------------
// Набор строк одного языка. Все поля обязательны: пропуск строки в одном
// из языков превращается в ошибку компиляции, а не в пустой экран у
// пользователя. Это главная причина держать словарь классом, а не Map.
// ------------------------------------------------------------
class AppStrings {
  const AppStrings({
    required this.commonCancel,
    required this.commonContinue,
    required this.commonSkip,
    required this.commonDone,
    required this.commonSave,
    required this.commonDelete,
    required this.commonEdit,
    required this.commonRetry,
    required this.commonError,
    required this.commonLoading,
    required this.commonNotSpecified,
    required this.commonAll,
    required this.commonClose,
    required this.commonBack,
    required this.commonSoon,
    required this.commonFrom,
    required this.commonUpTo,
    required this.filterSale,
    required this.catalogFound,
    required this.catalogSort,
    required this.sortFresh,
    required this.sortPriceAsc,
    required this.sortPriceDesc,
    required this.sortYearDesc,
    required this.sortYearAsc,
    required this.sortMileageAsc,
    required this.filterSearch,
    required this.filterSearchHint,
    required this.filterRent,
    // Навигация
    required this.navCatalog,
    required this.navFavorites,
    required this.navCreate,
    required this.navSell,
    required this.navMessages,
    required this.navProfile,
    // Онбординг
    required this.onboardingStepOf,
    required this.onboardingGoalTitle,
    required this.onboardingGoalSubtitle,
    required this.onboardingBuy,
    required this.onboardingBuyHint,
    required this.onboardingSell,
    required this.onboardingSellHint,
    required this.onboardingCityTitle,
    required this.onboardingCitySubtitle,
    required this.onboardingCitySearch,
    required this.onboardingCityAny,
    required this.onboardingBrandsTitle,
    required this.onboardingBrandsSubtitle,
    required this.onboardingBrandsHint,
    required this.onboardingFinish,
    required this.onboardingPushTitle,
    required this.onboardingPushBody,
    required this.onboardingPushAllow,
    required this.onboardingPushLater,
    required this.onboardingSaved,
    required this.onboardingSearchesEnabled,
    // Каталог
    required this.catalogTitle,
    required this.catalogSearchHint,
    required this.catalogFilters,
    required this.catalogFiltersReset,
    required this.catalogEmptyTitle,
    required this.catalogEmptyBody,
    required this.catalogEmptyNotify,
    required this.catalogEmptyResetFilters,
    required this.catalogNotifySaved,
    required this.catalogNotifyExists,
    required this.catalogViewed,
    required this.catalogPromoted,
    // Карточка объявления
    required this.carSold,
    required this.carCall,
    required this.carWrite,
    required this.carShare,
    required this.carYear,
    required this.carMileage,
    required this.carFuel,
    required this.carTransmission,
    required this.carBody,
    required this.carDescription,
    required this.carSeller,
    required this.carMemberSince,
    required this.carDealerBadge,
    required this.carAllListings,
    // Страница дилера
    required this.dealerActiveCars,
    required this.dealerSoldCars,
    required this.dealerRecentlySold,
    required this.dealerNoListings,
    required this.monthNames,
    // Кабинет продавца
    required this.myCarsTitle,
    required this.myCarsEmpty,
    required this.myCarsCreate,
    required this.statsViews,
    required this.statsFavorites,
    required this.statsContacts,
    required this.statsTotal,
    required this.actionEdit,
    required this.actionDuplicate,
    required this.actionMarkSold,
    required this.actionPromote,
    required this.promoteTitle,
    required this.promoteBody,
    required this.promoteConfirm,
    required this.promoteSuccess,
    required this.promoteActiveUntil,
    required this.markSoldTitle,
    required this.markSoldBody,
    required this.markSoldSuccess,
    required this.duplicateSuccess,
    // Статусы объявления
    required this.statusModeration,
    required this.statusActive,
    required this.statusArchived,
    required this.statusRejected,
    required this.statusSold,
    // Чат
    required this.chatsTitle,
    required this.chatsEmpty,
    required this.chatMessageHint,
    required this.chatTemplates,
    required this.chatTemplateStillAvailable,
    required this.chatTemplateNegotiable,
    required this.chatTemplateWhereToSee,
    required this.chatTemplateExchange,
    // Профиль и баланс
    required this.profileTitle,
    required this.profileBalance,
    required this.profileTopUp,
    required this.profileTopUpSoon,
    required this.profileTransactions,
    required this.profileTransactionsEmpty,
    required this.profileMySearches,
    required this.profileMySearchesEmpty,
    required this.profileLanguage,
    required this.profileLogout,
    required this.txTopup,
    required this.txBonus,
    required this.txGift,
    required this.txSpend,
    required this.txRefund,
    // Избранное
    required this.favoritesTitle,
    required this.favoritesEmpty,
    required this.favoritesEmptyBody,
    required this.favoritesGoToCatalog,
    // Топ-экраны: действия, требующие входа, и ошибки
    required this.authRequiredFavorite,
    required this.authRequiredHide,
    required this.authRequiredWrite,
    required this.catalogLoadError,
    required this.catalogNoConnection,
    required this.catalogHideRecommendation,
    required this.catalogHideCar,
    required this.catalogHideCity,
    required this.priceNegotiable,
    required this.carListingTitle,
    required this.carNotFound,
    required this.carNoPhone,
    required this.carCallFailed,
    required this.carSalePrice,
    required this.carRentDaily,
    required this.carPerDay,
    required this.carOpening,
    // Профиль
    required this.profileGuest,
    required this.profileYourName,
    required this.profileNameHint,
    required this.profileNameSaved,
    required this.profilePhotoUpdated,
    required this.profileLogoutTitle,
    required this.profileLogoutBody,
    // Чат
    required this.chatsSearchHint,
    required this.chatPinned,
    required this.chatUnpinned,
    required this.chatBlockConfirmTitle,
    required this.chatBlockConfirmBody,
    required this.chatBlock,
  });

  final String commonCancel;
  final String commonContinue;
  final String commonSkip;
  final String commonDone;
  final String commonSave;
  final String commonDelete;
  final String commonEdit;
  final String commonRetry;
  final String commonError;
  final String commonLoading;
  final String commonNotSpecified;
  final String commonAll;
  final String commonClose;
  final String commonBack;
  final String commonSoon;
  final String commonFrom;   // «от» в диапазонах: «от 2015»
  final String commonUpTo;   // «до» в диапазонах: «до 10000 EUR»
  final String filterSale;

  /// Подпись счётчика результатов: «Найдено» + число.
  final String catalogFound;

  /// Порядок выдачи каталога. Подписи 1:1 с SORT_OPTIONS сайта —
  /// пользователь видит одни и те же формулировки в обоих клиентах.
  final String catalogSort;
  final String sortFresh;
  final String sortPriceAsc;
  final String sortPriceDesc;
  final String sortYearDesc;
  final String sortYearAsc;
  final String sortMileageAsc;

  /// Подпись и плейсхолдер поля свободного поиска на экране фильтров —
  /// те же формулировки, что filter_search / filter_search_ph на сайте.
  final String filterSearch;
  final String filterSearchHint;
  final String filterRent;

  final String navCatalog;
  final String navFavorites;
  final String navCreate;

  /// CTA продавцу в шапке — та же формулировка, что на сайте (nav_sell).
  /// Отдельно от navCreate («Разместить» в нижнем меню): в шапке нужен
  /// призыв, а не название раздела.
  final String navSell;
  final String navMessages;
  final String navProfile;

  final String onboardingStepOf;
  final String onboardingGoalTitle;
  final String onboardingGoalSubtitle;
  final String onboardingBuy;
  final String onboardingBuyHint;
  final String onboardingSell;
  final String onboardingSellHint;
  final String onboardingCityTitle;
  final String onboardingCitySubtitle;
  final String onboardingCitySearch;
  final String onboardingCityAny;
  final String onboardingBrandsTitle;
  final String onboardingBrandsSubtitle;
  final String onboardingBrandsHint;
  final String onboardingFinish;
  final String onboardingPushTitle;
  final String onboardingPushBody;
  final String onboardingPushAllow;
  final String onboardingPushLater;
  final String onboardingSaved;
  final String onboardingSearchesEnabled;

  final String catalogTitle;
  final String catalogSearchHint;
  final String catalogFilters;
  final String catalogFiltersReset;
  final String catalogEmptyTitle;
  final String catalogEmptyBody;
  final String catalogEmptyNotify;
  final String catalogEmptyResetFilters;
  final String catalogNotifySaved;
  final String catalogNotifyExists;
  final String catalogViewed;
  final String catalogPromoted;

  final String carSold;
  final String carCall;
  final String carWrite;
  final String carShare;
  final String carYear;
  final String carMileage;
  final String carFuel;
  final String carTransmission;
  final String carBody;
  final String carDescription;
  final String carSeller;
  final String carMemberSince;
  final String carDealerBadge;
  final String carAllListings;

  final String dealerActiveCars;
  final String dealerSoldCars;
  final String dealerRecentlySold;
  final String dealerNoListings;

  // Названия месяцев в именительном падеже, январь..декабрь.
  // Держим в словаре, а не берём из intl: пакет не содержит русской локали,
  // и DateFormat с 'ru' падает в рантайме. [[intl-no-russian-locale]]
  final List<String> monthNames;

  final String myCarsTitle;
  final String myCarsEmpty;
  final String myCarsCreate;
  final String statsViews;
  final String statsFavorites;
  final String statsContacts;
  final String statsTotal;
  final String actionEdit;
  final String actionDuplicate;
  final String actionMarkSold;
  final String actionPromote;
  final String promoteTitle;
  final String promoteBody;
  final String promoteConfirm;
  final String promoteSuccess;
  final String promoteActiveUntil;
  final String markSoldTitle;
  final String markSoldBody;
  final String markSoldSuccess;
  final String duplicateSuccess;

  final String statusModeration;
  final String statusActive;
  final String statusArchived;
  final String statusRejected;
  final String statusSold;

  final String chatsTitle;
  final String chatsEmpty;
  final String chatMessageHint;
  final String chatTemplates;
  final String chatTemplateStillAvailable;
  final String chatTemplateNegotiable;
  final String chatTemplateWhereToSee;
  final String chatTemplateExchange;

  final String profileTitle;
  final String profileBalance;
  final String profileTopUp;
  final String profileTopUpSoon;
  final String profileTransactions;
  final String profileTransactionsEmpty;
  final String profileMySearches;
  final String profileMySearchesEmpty;
  final String profileLanguage;
  final String profileLogout;
  final String txTopup;
  final String txBonus;
  final String txGift;
  final String txSpend;
  final String txRefund;

  final String favoritesTitle;
  final String favoritesEmpty;
  final String favoritesEmptyBody;
  final String favoritesGoToCatalog;

  final String authRequiredFavorite;
  final String authRequiredHide;
  final String authRequiredWrite;
  final String catalogLoadError;
  final String catalogNoConnection;
  final String catalogHideRecommendation;
  final String catalogHideCar;
  final String catalogHideCity;
  final String priceNegotiable;
  final String carListingTitle;
  final String carNotFound;
  final String carNoPhone;
  final String carCallFailed;
  final String carSalePrice;
  final String carRentDaily;

  /// Короткая единица суточной ставки для строки цены: «45 € / сутки».
  /// Отдельно от carRentDaily («Аренда в сутки»): полная подпись не
  /// помещается в карточку каталога и обрезается многоточием.
  final String carPerDay;

  final String carOpening;

  final String profileGuest;
  final String profileYourName;
  final String profileNameHint;
  final String profileNameSaved;
  final String profilePhotoUpdated;
  final String profileLogoutTitle;
  final String profileLogoutBody;

  final String chatsSearchHint;
  final String chatPinned;
  final String chatUnpinned;
  final String chatBlockConfirmTitle;
  final String chatBlockConfirmBody;
  final String chatBlock;

  // «Заблокировать Ивана?» — имя подставляется в готовую фразу.
  String blockConfirmTitle(String name) =>
      chatBlockConfirmTitle.replaceAll('{name}', name);

  // ----------------------------------------------------------
  // Строки с подстановкой. Держим методами, а не полями: подстановка
  // порядкового номера и склонение зависят от языка, и метод позволяет
  // каждому словарю решать это по-своему.
  // ----------------------------------------------------------

  // «Шаг 2 из 3»
  String stepOf(int current, int total) =>
      onboardingStepOf.replaceAll('{current}', '$current').replaceAll('{total}', '$total');

  // «Продвигается до 23.08»
  String promotedUntil(String date) =>
      promoteActiveUntil.replaceAll('{date}', date);

  // «На площадке с августа 2025»
  String memberSince(String date) =>
      carMemberSince.replaceAll('{date}', date);

  // Подпись типа транзакции по её коду из БД.
  String transactionType(String type) {
    switch (type) {
      case 'topup':
        return txTopup;
      case 'bonus':
        return txBonus;
      case 'gift':
        return txGift;
      case 'spend':
        return txSpend;
      case 'refund':
        return txRefund;
      default:
        return type;
    }
  }

  // Подпись статуса объявления по коду из БД.
  String carStatus(String status) {
    switch (status) {
      case 'moderation':
        return statusModeration;
      case 'active':
        return statusActive;
      case 'archived':
        return statusArchived;
      case 'rejected':
        return statusRejected;
      case 'sold':
        return statusSold;
      default:
        return status;
    }
  }

  // Быстрые шаблоны сообщений для чата — порядок фиксирован.
  List<String> get chatTemplateList => [
        chatTemplateStillAvailable,
        chatTemplateNegotiable,
        chatTemplateWhereToSee,
        chatTemplateExchange,
      ];
}

// ============================================================
// РУССКИЙ
// ============================================================
const AppStrings _ru = AppStrings(
  commonCancel: 'Отмена',
  commonContinue: 'Продолжить',
  commonSkip: 'Пропустить',
  commonDone: 'Готово',
  commonSave: 'Сохранить',
  commonDelete: 'Удалить',
  commonEdit: 'Редактировать',
  commonRetry: 'Повторить',
  commonError: 'Что-то пошло не так',
  commonLoading: 'Загрузка…',
  commonNotSpecified: 'Не указано',
  commonAll: 'Все',
  commonClose: 'Закрыть',
  commonBack: 'Назад',
  commonSoon: 'Скоро',
  commonFrom: 'от',
  commonUpTo: 'до',
  filterSale: 'Продажа',
  catalogFound: 'Найдено',
  catalogSort: 'Сортировка',
  sortFresh: 'Сначала новые',
  sortPriceAsc: 'Цена: по возрастанию',
  sortPriceDesc: 'Цена: по убыванию',
  sortYearDesc: 'Год: новее',
  sortYearAsc: 'Год: старше',
  sortMileageAsc: 'Пробег: меньше',
  filterSearch: 'Поиск',
  filterSearchHint: 'Марка, модель или город',
  filterRent: 'Аренда',

  navCatalog: 'Каталог',
  navFavorites: 'Избранное',
  navCreate: 'Разместить',
  navSell: 'Продать авто',
  navMessages: 'Сообщения',
  navProfile: 'Профиль',

  onboardingStepOf: 'Шаг {current} из {total}',
  onboardingGoalTitle: 'Что вас интересует?',
  onboardingGoalSubtitle: 'Подберём то, что нужно именно вам',
  onboardingBuy: 'Покупаю',
  onboardingBuyHint: 'Ищу автомобиль',
  onboardingSell: 'Продаю',
  onboardingSellHint: 'Хочу разместить объявление',
  onboardingCityTitle: 'Ваш город',
  onboardingCitySubtitle: 'Покажем объявления рядом с вами',
  onboardingCitySearch: 'Найти город',
  onboardingCityAny: 'Вся Сербия',
  onboardingBrandsTitle: 'Любимые марки',
  onboardingBrandsSubtitle: 'Сообщим, когда появится подходящее авто',
  onboardingBrandsHint: 'Выберите одну или несколько',
  onboardingFinish: 'Начать',
  onboardingPushTitle: 'Не пропустите нужное авто',
  onboardingPushBody:
      'Пришлём уведомление, когда появится объявление по вашему запросу или подешевеет авто из избранного',
  onboardingPushAllow: 'Включить уведомления',
  onboardingPushLater: 'Позже',
  onboardingSaved: 'Сохранили ваши предпочтения',
  onboardingSearchesEnabled: 'Подписки на поиск включены',

  // Заголовок раздела — тот же текст, что h1 на сайте (catalog_mixed_title).
  catalogTitle: 'Автомобили в Сербии',
  catalogSearchHint: 'Марка, модель или город',
  catalogFilters: 'Фильтры',
  catalogFiltersReset: 'Сбросить',
  catalogEmptyTitle: 'Пока ничего не нашлось',
  catalogEmptyBody: 'Попробуйте изменить фильтры или подпишитесь на новые объявления',
  catalogEmptyNotify: 'Сообщить, когда появится',
  catalogEmptyResetFilters: 'Сбросить фильтры',
  catalogNotifySaved: 'Сообщим, когда появится',
  catalogNotifyExists: 'Вы уже подписаны на этот поиск',
  catalogViewed: 'Просмотрено',
  catalogPromoted: 'Продвигается',

  carSold: 'Продано',
  carCall: 'Позвонить',
  carWrite: 'Написать',
  carShare: 'Поделиться',
  carYear: 'Год выпуска',
  carMileage: 'Пробег',
  carFuel: 'Топливо',
  carTransmission: 'Коробка',
  carBody: 'Кузов',
  carDescription: 'Описание',
  carSeller: 'Продавец',
  carMemberSince: 'На площадке с {date}',
  carDealerBadge: 'Автосалон',
  carAllListings: 'Все объявления продавца',

  dealerActiveCars: 'В продаже',
  dealerSoldCars: 'Продано',
  dealerRecentlySold: 'Недавно проданные',
  dealerNoListings: 'Пока нет активных объявлений',
  monthNames: [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ],

  myCarsTitle: 'Мои объявления',
  myCarsEmpty: 'У вас пока нет объявлений',
  myCarsCreate: 'Разместить объявление',
  statsViews: 'Просмотры',
  statsFavorites: 'В избранном',
  statsContacts: 'Контакты',
  statsTotal: 'Всего',
  actionEdit: 'Редактировать',
  actionDuplicate: 'Дублировать',
  actionMarkSold: 'Продано',
  actionPromote: 'Продвинуть',
  promoteTitle: 'Продвинуть объявление?',
  promoteBody:
      'Объявление будет показываться в начале каталога 7 дней. Сейчас это бесплатно — как подарок от платформы.',
  promoteConfirm: 'Продвинуть',
  promoteSuccess: 'Объявление продвигается',
  promoteActiveUntil: 'Продвигается до {date}',
  markSoldTitle: 'Отметить проданным?',
  markSoldBody:
      'Объявление исчезнет из каталога, но останется доступным по прямой ссылке.',
  markSoldSuccess: 'Объявление отмечено проданным',
  duplicateSuccess: 'Копия создана — проверьте и опубликуйте',

  statusModeration: 'На проверке',
  statusActive: 'Опубликовано',
  statusArchived: 'В архиве',
  statusRejected: 'Отклонено',
  statusSold: 'Продано',

  chatsTitle: 'Сообщения',
  chatsEmpty: 'Пока нет диалогов',
  chatMessageHint: 'Сообщение…',
  chatTemplates: 'Быстрые ответы',
  chatTemplateStillAvailable: 'Ещё актуально?',
  chatTemplateNegotiable: 'Торг уместен?',
  chatTemplateWhereToSee: 'Где можно посмотреть?',
  chatTemplateExchange: 'Обмен рассматриваете?',

  profileTitle: 'Профиль',
  profileBalance: 'Баланс',
  profileTopUp: 'Пополнить',
  profileTopUpSoon: 'Пополнение скоро заработает',
  profileTransactions: 'История операций',
  profileTransactionsEmpty: 'Операций пока не было',
  profileMySearches: 'Мои подписки',
  profileMySearchesEmpty: 'Вы пока не подписались ни на один поиск',
  profileLanguage: 'Язык',
  profileLogout: 'Выйти',
  txTopup: 'Пополнение',
  txBonus: 'Бонус',
  txGift: 'Подарок',
  txSpend: 'Списание',
  txRefund: 'Возврат',

  favoritesTitle: 'Избранное',
  favoritesEmpty: 'В избранном пусто',
  favoritesEmptyBody: 'Добавляйте объявления сердечком — они появятся здесь',
  favoritesGoToCatalog: 'Перейти в каталог',

  authRequiredFavorite: 'Войдите, чтобы добавить в избранное',
  authRequiredHide: 'Войдите, чтобы скрывать объявления',
  authRequiredWrite: 'Войдите, чтобы написать',
  catalogLoadError: 'Не удалось загрузить каталог.\nПопробуйте ещё раз.',
  catalogNoConnection:
      'Нет связи с сервером.\nПроверьте интернет и попробуйте снова.',
  catalogHideRecommendation: 'Скрыть рекомендацию',
  catalogHideCar: 'Не интересует это объявление',
  catalogHideCity: 'Не подходит город или регион',
  priceNegotiable: 'Договорная',
  carListingTitle: 'Объявление',
  carNotFound: 'Объявление не найдено',
  carNoPhone: 'У этого объявления нет номера телефона',
  carCallFailed: 'Не удалось открыть набор номера',
  carSalePrice: 'Цена продажи',
  carRentDaily: 'Аренда в сутки',
  carPerDay: 'сутки',
  carOpening: 'Открываем…',

  profileGuest: 'Гость',
  profileYourName: 'Ваше имя',
  profileNameHint: 'Как вас показывать другим',
  profileNameSaved: 'Имя сохранено',
  profilePhotoUpdated: 'Фото профиля обновлено',
  profileLogoutTitle: 'Выйти из аккаунта?',
  profileLogoutBody: 'Для повторного входа понадобится номер телефона.',

  chatsSearchHint: 'Поиск по диалогам',
  chatPinned: 'Диалог закреплён',
  chatUnpinned: 'Диалог откреплён',
  chatBlockConfirmTitle: 'Заблокировать {name}?',
  chatBlockConfirmBody:
      'Пользователь больше не сможет писать вам сообщения. '
      'Блокировку можно снять в любой момент свайпом по диалогу.',
  chatBlock: 'Заблокировать',
);

// ============================================================
// СЕРБСКИЙ (латиница)
// ============================================================
const AppStrings _sr = AppStrings(
  commonCancel: 'Otkaži',
  commonContinue: 'Nastavi',
  commonSkip: 'Preskoči',
  commonDone: 'Gotovo',
  commonSave: 'Sačuvaj',
  commonDelete: 'Obriši',
  commonEdit: 'Izmeni',
  commonRetry: 'Pokušaj ponovo',
  commonError: 'Nešto nije u redu',
  commonLoading: 'Učitavanje…',
  commonNotSpecified: 'Nije navedeno',
  commonAll: 'Sve',
  commonClose: 'Zatvori',
  commonBack: 'Nazad',
  commonSoon: 'Uskoro',
  commonFrom: 'od',
  commonUpTo: 'do',
  filterSale: 'Prodaja',
  catalogFound: 'Pronađeno',
  catalogSort: 'Sortiranje',
  sortFresh: 'Najnovije',
  sortPriceAsc: 'Cena: rastuće',
  sortPriceDesc: 'Cena: opadajuće',
  sortYearDesc: 'Godište: novije',
  sortYearAsc: 'Godište: starije',
  sortMileageAsc: 'Kilometraža: manja',
  filterSearch: 'Pretraga',
  filterSearchHint: 'Marka, model ili grad',
  filterRent: 'Iznajmljivanje',

  navCatalog: 'Katalog',
  navFavorites: 'Omiljeno',
  navCreate: 'Postavi',
  navSell: 'Prodaj auto',
  navMessages: 'Poruke',
  navProfile: 'Profil',

  onboardingStepOf: 'Korak {current} od {total}',
  onboardingGoalTitle: 'Šta vas zanima?',
  onboardingGoalSubtitle: 'Pronaći ćemo baš ono što vam treba',
  onboardingBuy: 'Kupujem',
  onboardingBuyHint: 'Tražim automobil',
  onboardingSell: 'Prodajem',
  onboardingSellHint: 'Želim da postavim oglas',
  onboardingCityTitle: 'Vaš grad',
  onboardingCitySubtitle: 'Prikazaćemo oglase u vašoj blizini',
  onboardingCitySearch: 'Pronađi grad',
  onboardingCityAny: 'Cela Srbija',
  onboardingBrandsTitle: 'Omiljene marke',
  onboardingBrandsSubtitle: 'Javićemo kada se pojavi odgovarajući automobil',
  onboardingBrandsHint: 'Izaberite jednu ili više',
  onboardingFinish: 'Započni',
  onboardingPushTitle: 'Ne propustite pravi automobil',
  onboardingPushBody:
      'Poslaćemo obaveštenje kada se pojavi oglas po vašoj pretrazi ili kada pojeftini automobil iz omiljenih',
  onboardingPushAllow: 'Uključi obaveštenja',
  onboardingPushLater: 'Kasnije',
  onboardingSaved: 'Sačuvali smo vaše želje',
  onboardingSearchesEnabled: 'Pretrage su uključene',

  catalogTitle: 'Automobili u Srbiji',
  catalogSearchHint: 'Marka, model ili grad',
  catalogFilters: 'Filteri',
  catalogFiltersReset: 'Poništi',
  catalogEmptyTitle: 'Za sada nema rezultata',
  catalogEmptyBody: 'Promenite filtere ili se prijavite na nove oglase',
  catalogEmptyNotify: 'Obavesti me kada se pojavi',
  catalogEmptyResetFilters: 'Poništi filtere',
  catalogNotifySaved: 'Javićemo vam kada se pojavi',
  catalogNotifyExists: 'Već ste prijavljeni na ovu pretragu',
  catalogViewed: 'Pregledano',
  catalogPromoted: 'Promovisano',

  carSold: 'Prodato',
  carCall: 'Pozovi',
  carWrite: 'Pošalji poruku',
  carShare: 'Podeli',
  carYear: 'Godište',
  carMileage: 'Kilometraža',
  carFuel: 'Gorivo',
  carTransmission: 'Menjač',
  carBody: 'Karoserija',
  carDescription: 'Opis',
  carSeller: 'Prodavac',
  carMemberSince: 'Na platformi od {date}',
  carDealerBadge: 'Auto-salon',
  carAllListings: 'Svi oglasi prodavca',

  dealerActiveCars: 'U prodaji',
  dealerSoldCars: 'Prodato',
  dealerRecentlySold: 'Nedavno prodato',
  dealerNoListings: 'Još nema aktivnih oglasa',
  monthNames: [
    'januar', 'februar', 'mart', 'april', 'maj', 'jun',
    'jul', 'avgust', 'septembar', 'oktobar', 'novembar', 'decembar',
  ],

  myCarsTitle: 'Moji oglasi',
  myCarsEmpty: 'Još nemate oglase',
  myCarsCreate: 'Postavi oglas',
  statsViews: 'Pregledi',
  statsFavorites: 'U omiljenim',
  statsContacts: 'Kontakti',
  statsTotal: 'Ukupno',
  actionEdit: 'Izmeni',
  actionDuplicate: 'Dupliraj',
  actionMarkSold: 'Prodato',
  actionPromote: 'Promoviši',
  promoteTitle: 'Promovisati oglas?',
  promoteBody:
      'Oglas će se prikazivati na vrhu kataloga 7 dana. Trenutno je besplatno — kao poklon platforme.',
  promoteConfirm: 'Promoviši',
  promoteSuccess: 'Oglas se promoviše',
  promoteActiveUntil: 'Promoviše se do {date}',
  markSoldTitle: 'Označiti kao prodato?',
  markSoldBody:
      'Oglas će nestati iz kataloga, ali će ostati dostupan preko direktnog linka.',
  markSoldSuccess: 'Oglas je označen kao prodat',
  duplicateSuccess: 'Kopija je napravljena — proverite i objavite',

  statusModeration: 'Na proveri',
  statusActive: 'Objavljeno',
  statusArchived: 'Arhivirano',
  statusRejected: 'Odbijeno',
  statusSold: 'Prodato',

  chatsTitle: 'Poruke',
  chatsEmpty: 'Još nema razgovora',
  chatMessageHint: 'Poruka…',
  chatTemplates: 'Brzi odgovori',
  chatTemplateStillAvailable: 'Da li je još aktuelno?',
  chatTemplateNegotiable: 'Ima li cenkanja?',
  chatTemplateWhereToSee: 'Gde može da se pogleda?',
  chatTemplateExchange: 'Da li razmatrate zamenu?',

  profileTitle: 'Profil',
  profileBalance: 'Stanje',
  profileTopUp: 'Dopuni',
  profileTopUpSoon: 'Dopuna uskoro počinje da radi',
  profileTransactions: 'Istorija transakcija',
  profileTransactionsEmpty: 'Još nema transakcija',
  profileMySearches: 'Moje pretrage',
  profileMySearchesEmpty: 'Još niste sačuvali nijednu pretragu',
  profileLanguage: 'Jezik',
  profileLogout: 'Odjavi se',
  txTopup: 'Dopuna',
  txBonus: 'Bonus',
  txGift: 'Poklon',
  txSpend: 'Trošak',
  txRefund: 'Povraćaj',

  favoritesTitle: 'Omiljeno',
  favoritesEmpty: 'Nemate omiljene oglase',
  favoritesEmptyBody: 'Dodajte oglase srcem — pojaviće se ovde',
  favoritesGoToCatalog: 'Idi na katalog',

  authRequiredFavorite: 'Prijavite se da biste dodali u omiljeno',
  authRequiredHide: 'Prijavite se da biste sakrili oglase',
  authRequiredWrite: 'Prijavite se da biste poslali poruku',
  catalogLoadError: 'Učitavanje kataloga nije uspelo.\nPokušajte ponovo.',
  catalogNoConnection:
      'Nema veze sa serverom.\nProverite internet i pokušajte ponovo.',
  catalogHideRecommendation: 'Sakrij preporuku',
  catalogHideCar: 'Ne zanima me ovaj oglas',
  catalogHideCity: 'Ne odgovara grad ili region',
  priceNegotiable: 'Po dogovoru',
  carListingTitle: 'Oglas',
  carNotFound: 'Oglas nije pronađen',
  carNoPhone: 'Ovaj oglas nema broj telefona',
  carCallFailed: 'Nije moguće otvoriti biranje broja',
  carSalePrice: 'Cena',
  carRentDaily: 'Najam po danu',
  carPerDay: 'dan',
  carOpening: 'Otvaramo…',

  profileGuest: 'Gost',
  profileYourName: 'Vaše ime',
  profileNameHint: 'Kako da vas prikažemo drugima',
  profileNameSaved: 'Ime je sačuvano',
  profilePhotoUpdated: 'Profilna slika je ažurirana',
  profileLogoutTitle: 'Odjaviti se?',
  profileLogoutBody: 'Za ponovnu prijavu biće potreban broj telefona.',

  chatsSearchHint: 'Pretraga razgovora',
  chatPinned: 'Razgovor je zakačen',
  chatUnpinned: 'Razgovor je otkačen',
  chatBlockConfirmTitle: 'Blokirati {name}?',
  chatBlockConfirmBody:
      'Korisnik više neće moći da vam šalje poruke. '
      'Blokadu možete ukinuti u svakom trenutku prevlačenjem po razgovoru.',
  chatBlock: 'Blokiraj',
);

// ============================================================
// ДОСТУП К СЛОВАРЮ
// ============================================================

// Словарь по коду языка. Незнакомый язык → сербский (язык рынка),
// та же логика запасного варианта, что в AppLanguageService.resolveLocale.
AppStrings stringsFor(Locale locale) {
  switch (locale.languageCode) {
    case 'ru':
      return _ru;
    case 'sr':
    default:
      return _sr;
  }
}

// Расширение для краткого доступа: context.t.catalogTitle
extension AppStringsX on BuildContext {
  AppStrings get t => stringsFor(Localizations.localeOf(this));
}

// Словарь вне дерева виджетов (например, в репозитории или сервисе, где нет
// BuildContext). Опирается на текущий выбор языка в AppLanguageService.
AppStrings get currentStrings {
  final selection = AppLanguageService.instance.selection;
  final locale = AppLanguageService.resolveLocale(
    selection,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
  return stringsFor(locale);
}
