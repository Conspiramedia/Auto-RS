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
import 'plural.dart';

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
    required this.badgeRent,
    required this.formBrand,
    required this.formModel,
    required this.formCity,
    required this.formBodyType,
    required this.formTransmission,
    required this.formMileage,
    required this.formPrice,
    required this.formRentPrice,
    required this.formListingType,
    required this.formSelect,
    required this.formAny,
    required this.formAll,
    required this.formOptional,
    required this.formNotSet,
    required this.formSearchHint,
    required this.formSearchOrEnter,
    required this.formSetCustom,
    required this.formNoModels,
    required this.formRangeFrom,
    required this.formRangeTo,
    required this.filtersShowResults,
    required this.carDescriptionHint,
    required this.createTitleNew,
    required this.createTitleEdit,
    required this.createTitleCopy,
    required this.createPublish,
    required this.createSaveAndSend,
    required this.createSaving,
    required this.createSentToModeration,
    required this.createEditSent,
    required this.createTypeRequired,
    required this.createWaitPhotos,
    required this.createPhotosTitle,
    required this.createPhotoLimit,
    required this.createPhotoTrimmed,
    required this.createPhotoFailed,
    required this.createPublishFailed,
    required this.createConfirmPhoneTitle,
    required this.createConfirmPhoneBody,
    required this.createPhoneRequired,
    required this.createSessionExpired,
    required this.commonOk,
    required this.profileLogin,
    required this.profileLogoutFull,
    required this.profileLoggingOut,
    required this.profileAddName,
    required this.profileSave,
    required this.profileMyListings,
    required this.profileModeration,
    required this.profileLegal,
    required this.profilePhoneCopied,
    required this.profilePhotoFailed,
    required this.profileNameFailed,
    required this.carTransmissionShort,
    required this.carSoldNotice,
    required this.moderationReasonPhotoMismatch,
    required this.moderationReasonCustom,
    required this.moderationRejectReason,
    required this.moderationReasonPrefix,
    required this.validateCityRequired,
    required this.validateBrandRequired,
    required this.validateModelRequired,
    required this.validateYearRequired,
    required this.validateYearTooOld,
    required this.validateYearFuture,
    required this.validatePricePositive,
    required this.validatePhotoRequired,
    required this.validatePhoneRequired,
    required this.validatePhoneFormat,
    required this.createAfterPublishNote,
    required this.createPriceLabel,
    required this.createPricePositive,
    required this.createDuplicateExists,
    required this.createPhoneNoteSuffix,
    required this.catalogFavoriteFailed,
    required this.catalogHideCarFailed,
    required this.catalogHideCityFailed,
    required this.authOtpLimit,
    required this.savedSearchAll,
    required this.savedSearchFrom,
    required this.savedSearchTo,
    required this.savedSearchYearSuffix,
    required this.notificationsTitle,
    required this.notificationsEmpty,
    required this.notificationsReadAll,
    // Навигация
    required this.navCatalog,
    required this.navFavorites,
    required this.navCreate,
    required this.navSell,
    required this.navMenu,
    required this.commonUser,
    required this.commonNoName,
    required this.commonYesterday,
    required this.commonNothingFound,
    required this.commonErrorGeneric,
    required this.commonErrorNetwork,
    required this.chatsGuest,
    required this.chatsEmptyTitle,
    required this.chatsEmptyBody,
    required this.chatsSearchEmptyBody,
    required this.chatNoMessages,
    required this.chatPin,
    required this.chatUnpin,
    required this.chatUnblock,
    required this.chatPinFailed,
    required this.chatBlockFailed,
    required this.chatUnblockFailed,
    required this.chatSendFailed,
    required this.chatBlockedSuffix,
    required this.chatUnblockedSuffix,
    required this.loginTitle,
    required this.loginPhoneLabel,
    required this.loginHint,
    required this.loginSendCode,
    required this.loginSending,
    required this.loginCodeLabel,
    required this.loginCodeSentTo,
    required this.loginChangeNumber,
    required this.loginResend,
    required this.loginResendIn,
    required this.loginResent,
    required this.loginChecking,
    required this.loginAsGuest,
    required this.loginPhoneInvalid,
    required this.loginCodeInvalid,
    required this.loginCodeExpired,
    required this.loginVerifyFailed,
    required this.loginPhoneConfirmed,
    required this.moderationTitle,
    required this.moderationDenied,
    required this.moderationTabNew,
    required this.moderationTabRejected,
    required this.moderationEmptyNew,
    required this.moderationEmptyRejected,
    required this.moderationApprove,
    required this.moderationReject,
    required this.moderationApproved,
    required this.moderationRejected,
    required this.moderationNoPhoto,
    required this.moderationReasonTitle,
    required this.moderationReasonRequired,
    required this.moderationReasonOther,
    required this.moderationReasonPhotos,
    required this.moderationReasonDuplicate,
    required this.moderationReasonForbidden,
    required this.moderationReasonContacts,
    required this.moderationReasonPrice,
    required this.moderationReasonDescription,
    required this.moderationReasonFraud,
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
    required this.monthNamesShort,
    required this.weekdayNamesShort,
    required this.listingOne,
    required this.listingFew,
    required this.listingMany,
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

  /// Бейдж «Аренда» на фотографии в карточке каталога. Отдельно от
  /// filterRent: тот — вариант фильтра, этот — метка на объявлении, и
  /// при правке одного второй меняться не должен.
  final String badgeRent;
  final String formBrand;
  final String formModel;
  final String formCity;
  final String formBodyType;
  final String formTransmission;
  final String formMileage;
  final String formPrice;
  final String formRentPrice;
  final String formListingType;

  /// Плейсхолдер незаполненного поля-пикера.
  final String formSelect;

  /// Значение фильтра «любой» — фильтр не применяется.
  final String formAny;
  final String formAll;
  final String formOptional;
  final String formNotSet;
  final String formSearchHint;

  /// Пикер, где можно выбрать из списка или ввести своё.
  final String formSearchOrEnter;

  /// Подставляется введённое значение: «Указать „Zastava“».
  final String formSetCustom;
  final String formNoModels;

  /// Подставляется подпись поля: «Год от».
  final String formRangeFrom;
  final String formRangeTo;
  final String filtersShowResults;
  final String carDescriptionHint;
  final String createTitleNew;
  final String createTitleEdit;
  final String createTitleCopy;
  final String createPublish;
  final String createSaveAndSend;
  final String createSaving;
  final String createSentToModeration;
  final String createEditSent;
  final String createTypeRequired;
  final String createWaitPhotos;

  /// Подставляются загруженное и максимальное число.
  final String createPhotosTitle;
  final String createPhotoLimit;

  /// Часть выбранных фото не поместилась в лимит.
  final String createPhotoTrimmed;
  final String createPhotoFailed;
  final String createPublishFailed;
  final String createConfirmPhoneTitle;

  /// Подставляется номер.
  final String createConfirmPhoneBody;
  final String createPhoneRequired;
  final String createSessionExpired;
  final String commonOk;
  final String profileLogin;
  final String profileLogoutFull;
  final String profileLoggingOut;
  final String profileAddName;
  final String profileSave;
  final String profileMyListings;
  final String profileModeration;
  final String profileLegal;
  final String profilePhoneCopied;
  final String profilePhotoFailed;
  final String profileNameFailed;

  /// Компактная подпись в таблице характеристик.
  final String carTransmissionShort;
  final String carSoldNotice;
  final String moderationReasonPhotoMismatch;
  final String moderationReasonCustom;
  final String moderationRejectReason;

  /// Подставляется текст причины от модератора.
  final String moderationReasonPrefix;
  final String validateCityRequired;
  final String validateBrandRequired;
  final String validateModelRequired;
  final String validateYearRequired;
  final String validateYearTooOld;
  final String validateYearFuture;
  final String validatePricePositive;
  final String validatePhotoRequired;
  final String validatePhoneRequired;

  /// Подсказка формата сербского номера.
  final String validatePhoneFormat;
  final String createAfterPublishNote;
  final String createPriceLabel;
  final String createPricePositive;
  final String createDuplicateExists;

  /// Вторая часть подсказки о подтверждении номера.
  final String createPhoneNoteSuffix;
  final String catalogFavoriteFailed;
  final String catalogHideCarFailed;
  final String catalogHideCityFailed;

  /// Подставляется дневной лимит запросов кода.
  final String authOtpLimit;

  /// Подписка без фильтров — на всю выдачу.
  final String savedSearchAll;
  final String savedSearchFrom;
  final String savedSearchTo;

  /// Приписка после года: «2015–2020 г.».
  final String savedSearchYearSuffix;
  final String notificationsTitle;
  final String notificationsEmpty;
  final String notificationsReadAll;




  final String navCatalog;
  final String navFavorites;
  final String navCreate;

  /// CTA продавцу в шапке — та же формулировка, что на сайте (nav_sell).
  /// Отдельно от navCreate («Разместить» в нижнем меню): в шапке нужен
  /// призыв, а не название раздела.
  final String navSell;

  /// Заголовок боковой шторки меню (nav_menu сайта).
  final String navMenu;

  /// Подпись собеседника, у которого не заполнено имя.
  final String commonUser;
  final String commonNoName;
  final String commonYesterday;
  final String commonNothingFound;

  /// Текст на замену техническому сообщению, которое человеку ничего не говорит.
  final String commonErrorGeneric;
  final String commonErrorNetwork;
  final String chatsGuest;
  final String chatsEmptyTitle;
  final String chatsEmptyBody;
  final String chatsSearchEmptyBody;
  final String chatNoMessages;
  final String chatPin;
  final String chatUnpin;
  final String chatUnblock;
  final String chatPinFailed;
  final String chatBlockFailed;
  final String chatUnblockFailed;
  final String chatSendFailed;

  /// Подставляется имя: «Иван заблокирован».
  final String chatBlockedSuffix;
  final String chatUnblockedSuffix;
  final String loginTitle;
  final String loginPhoneLabel;
  final String loginHint;
  final String loginSendCode;
  final String loginSending;
  final String loginCodeLabel;

  /// Подставляется номер в международном формате.
  final String loginCodeSentTo;
  final String loginChangeNumber;
  final String loginResend;

  /// Подставляется остаток секунд.
  final String loginResendIn;
  final String loginResent;
  final String loginChecking;
  final String loginAsGuest;
  final String loginPhoneInvalid;
  final String loginCodeInvalid;
  final String loginCodeExpired;
  final String loginVerifyFailed;
  final String loginPhoneConfirmed;
  final String moderationTitle;
  final String moderationDenied;
  final String moderationTabNew;
  final String moderationTabRejected;
  final String moderationEmptyNew;
  final String moderationEmptyRejected;
  final String moderationApprove;
  final String moderationReject;
  final String moderationApproved;
  final String moderationRejected;
  final String moderationNoPhoto;
  final String moderationReasonTitle;
  final String moderationReasonRequired;
  final String moderationReasonOther;
  final String moderationReasonPhotos;
  final String moderationReasonDuplicate;
  final String moderationReasonForbidden;
  final String moderationReasonContacts;
  final String moderationReasonPrice;
  final String moderationReasonDescription;
  final String moderationReasonFraud;

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

  /// Короткие названия месяцев, янв..дек. Для отметок времени в списке
  /// диалогов, где полное название не помещается.
  final List<String> monthNamesShort;

  /// Короткие дни недели, пн..вс. Там же.
  final List<String> weekdayNamesShort;

  /// Формы слова «объявление» для счётчика результатов. Держим тремя
  /// строками, а не одним словом: русский и сербский меняют форму по
  /// числу, и «Найдено: 11 объявление» выдало бы машинный перевод.
  final String listingOne;
  final String listingFew;
  final String listingMany;

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

  // «Найдено: 35 объявлений» — с правильной формой существительного.
  // Правило склонения общее для ru и sr (CLDR one/few/many), логика
  // перенесена дословно из lib/plural.ts сайта.
  String foundCount(int count) {
    final forms = PluralForms(
      one: listingOne,
      few: listingFew,
      many: listingMany,
    );
    return '$catalogFound: ${withPlural(count, forms)}';
  }

  // «Иван заблокирован» / «Иван разблокирован».
  String userBlocked(String name) =>
      chatBlockedSuffix.replaceAll('{name}', name);

  String userUnblocked(String name) =>
      chatUnblockedSuffix.replaceAll('{name}', name);

  // «Мы отправили код на номер +381 6X XXX XXX».
  String codeSentTo(String phone) =>
      loginCodeSentTo.replaceAll('{phone}', phone);

  // «Отправить снова (42)» — обратный отсчёт до повторной отправки.
  String resendIn(int seconds) =>
      loginResendIn.replaceAll('{seconds}', '$seconds');

  // «Причина: не тот автомобиль на фото».
  String rejectionReason(String text) =>
      moderationReasonPrefix.replaceAll('{text}', text);

  // Причины отклонения объявления — порядок фиксирован, последним
  // идёт «Другое», где модератор пишет текст сам.
  List<String> get moderationReasons => [
        moderationReasonPhotos,
        moderationReasonPhotoMismatch,
        moderationReasonDuplicate,
        moderationReasonForbidden,
        moderationReasonContacts,
        moderationReasonPrice,
        moderationReasonDescription,
        moderationReasonFraud,
      ];

  // «Указать „Zastava“» — предложение задать значение, которого нет
  // в справочнике.
  String setCustom(String value) =>
      formSetCustom.replaceAll('{value}', value);

  // «Год от» / «Год до» — подписи полей диапазона.
  String rangeFrom(String label) => formRangeFrom.replaceAll('{label}', label);
  String rangeTo(String label) => formRangeTo.replaceAll('{label}', label);

  // «Фотографии (3/10)»
  String photosTitle(int current, int max) => createPhotosTitle
      .replaceAll('{current}', '$current')
      .replaceAll('{max}', '$max');

  // «Можно добавить не более 10 фото»
  String photoLimit(int max) =>
      createPhotoLimit.replaceAll('{max}', '$max');

  // «Добавлены первые 3 из 12 — лимит 10 фото»
  String photoTrimmed(int added, int total, int max) => createPhotoTrimmed
      .replaceAll('{added}', '$added')
      .replaceAll('{total}', '$total')
      .replaceAll('{max}', '$max');

  // «Подтвердите свой номер +381 6X XXX XXX — мы отправим код в SMS.»
  String confirmPhoneBody(String phone) =>
      createConfirmPhoneBody.replaceAll('{phone}', phone);

  // «Превышен лимит запросов кода (5 в сутки)…»
  String otpLimit(int count) =>
      authOtpLimit.replaceAll('{count}', '$count');

  // «от 2015» / «до 2020» — границы диапазона в описании подписки.
  String rangeFromValue(String value) =>
      savedSearchFrom.replaceAll('{value}', value);
  String rangeToValue(String value) =>
      savedSearchTo.replaceAll('{value}', value);

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
  badgeRent: 'Аренда',
  formBrand: 'Марка',
  formModel: 'Модель',
  formCity: 'Город',
  formBodyType: 'Тип кузова',
  formTransmission: 'Коробка передач',
  formMileage: 'Пробег, км',
  formPrice: 'Цена, €',
  formRentPrice: 'Цена аренды в сутки, EUR',
  formListingType: 'Тип объявления',
  formSelect: 'Выберите',
  formAny: 'Не важно',
  formAll: 'Все',
  formOptional: 'Необязательно',
  formNotSet: 'Не указано',
  formSearchHint: 'Поиск…',
  formSearchOrEnter: 'Поиск или ввод своего…',
  formSetCustom: 'Указать «{value}»',
  formNoModels: 'Нет моделей для этой марки',
  formRangeFrom: '{label} от',
  formRangeTo: '{label} до',
  filtersShowResults: 'Показать объявления',
  carDescriptionHint: 'Состояние, комплектация, история…',
  createTitleNew: 'Новое объявление',
  createTitleEdit: 'Редактирование',
  createTitleCopy: 'Копия объявления',
  createPublish: 'Опубликовать',
  createSaveAndSend: 'Сохранить и отправить',
  createSaving: 'Сохраняем…',
  createSentToModeration: 'Объявление отправлено на модерацию',
  createEditSent: 'Изменения отправлены на модерацию',
  createTypeRequired: 'Выберите тип объявления: продажа или аренда',
  createWaitPhotos: 'Дождитесь загрузки фото',
  createPhotosTitle: 'Фотографии ({current}/{max})',
  createPhotoLimit: 'Можно добавить не более {max} фото',
  createPhotoTrimmed: 'Добавлены первые {added} из {total} — лимит {max} фото',
  createPhotoFailed: 'Не удалось загрузить часть фото',
  createPublishFailed: 'Ошибка публикации',
  createConfirmPhoneTitle: 'Подтвердите номер телефона',
  createConfirmPhoneBody: 'Подтвердите свой номер {phone} — мы отправим код в SMS.',
  createPhoneRequired: 'Для размещения объявления нужно подтвердить номер телефона',
  createSessionExpired: 'Сессия истекла — добавьте фото заново, чтобы подтвердить номер',
  commonOk: 'Хорошо',
  profileLogin: 'Войти',
  profileLogoutFull: 'Выйти из аккаунта',
  profileLoggingOut: 'Выходим…',
  profileAddName: 'Добавьте имя',
  profileSave: 'Сохранить',
  profileMyListings: 'Мои объявления',
  profileModeration: 'Модерация объявлений',
  profileLegal: 'Политика и условия',
  profilePhoneCopied: 'Номер скопирован',
  profilePhotoFailed: 'Не удалось обновить фото',
  profileNameFailed: 'Не удалось сохранить имя',
  carTransmissionShort: 'КПП',
  carSoldNotice: 'Объявление продано — связь с продавцом закрыта',
  moderationReasonPhotoMismatch: 'Фото не соответствуют: чужие снимки, не тот автомобиль или плохое качество',
  moderationReasonCustom: 'Своя причина',
  moderationRejectReason: 'Причина отклонения',
  moderationReasonPrefix: 'Причина: {text}',
  validateCityRequired: 'Укажите город',
  validateBrandRequired: 'Укажите марку автомобиля',
  validateModelRequired: 'Укажите модель автомобиля',
  validateYearRequired: 'Укажите год выпуска',
  validateYearTooOld: 'Год выпуска не может быть раньше 1900',
  validateYearFuture: 'Год выпуска не может быть в будущем',
  validatePricePositive: 'Цена должна быть больше нуля',
  validatePhotoRequired: 'Добавьте хотя бы одно фото автомобиля',
  validatePhoneRequired: 'Укажите контактный телефон',
  validatePhoneFormat: 'Введите корректный номер: моб. +381 6X XXX XXX или гор. +381 11 XXX XXX',
  createAfterPublishNote: 'После публикации объявление уходит на модерацию и появится в каталоге после одобрения.',
  createPriceLabel: 'Цена, EUR',
  createPricePositive: 'Цена должна быть больше нуля или оставьте поле пустым',
  createDuplicateExists: 'Уже есть такое объявление',
  createPhoneNoteSuffix: 'мы отправим код в SMS.',
  catalogFavoriteFailed: 'Не удалось обновить избранное',
  catalogHideCarFailed: 'Не удалось скрыть объявление',
  catalogHideCityFailed: 'Не удалось скрыть город',
  authOtpLimit: 'Превышен лимит запросов кода ({count} в сутки). Попробуйте завтра или войдите позже.',
  savedSearchAll: 'Все объявления',
  savedSearchFrom: 'от {value}',
  savedSearchTo: 'до {value}',
  savedSearchYearSuffix: 'г.',
  notificationsTitle: 'Уведомления',
  notificationsEmpty: 'Уведомлений пока нет',
  notificationsReadAll: 'Прочитать все',

  navCatalog: 'Каталог',
  navFavorites: 'Избранное',
  navCreate: 'Разместить',
  navSell: 'Продать авто',
  navMenu: 'Меню',
  commonUser: 'Пользователь',
  commonNoName: 'Без имени',
  commonYesterday: 'Вчера',
  commonNothingFound: 'Ничего не найдено',
  commonErrorGeneric: 'Что-то пошло не так. Попробуйте ещё раз.',
  commonErrorNetwork: 'Нет связи с сервером. Проверьте интернет и попробуйте снова.',
  chatsGuest: 'Войдите, чтобы видеть диалоги',
  chatsEmptyTitle: 'Диалогов пока нет',
  chatsEmptyBody: 'Напишите продавцу со страницы объявления.',
  chatsSearchEmptyBody: 'Попробуйте изменить запрос: имя собеседника, марка или модель.',
  chatNoMessages: 'Сообщений пока нет',
  chatPin: 'Закрепить',
  chatUnpin: 'Открепить',
  chatUnblock: 'Разблокировать',
  chatPinFailed: 'Не удалось изменить закрепление',
  chatBlockFailed: 'Не удалось заблокировать',
  chatUnblockFailed: 'Не удалось разблокировать',
  chatSendFailed: 'Не удалось отправить',
  chatBlockedSuffix: '{name} заблокирован',
  chatUnblockedSuffix: '{name} разблокирован',
  loginTitle: 'Вход по телефону',
  loginPhoneLabel: 'Телефон',
  loginHint: 'Введите номер — пришлём код в SMS. Пароль не нужен.',
  loginSendCode: 'Отправить код',
  loginSending: 'Отправляем…',
  loginCodeLabel: 'Введите код из SMS',
  loginCodeSentTo: 'Мы отправили код на номер {phone}',
  loginChangeNumber: 'Изменить номер',
  loginResend: 'Отправить снова',
  loginResendIn: 'Отправить снова ({seconds})',
  loginResent: 'Код отправлен повторно',
  loginChecking: 'Проверяем код…',
  loginAsGuest: 'Продолжить как гость',
  loginPhoneInvalid: 'Введите корректный номер телефона',
  loginCodeInvalid: 'Неверный код из SMS',
  loginCodeExpired: 'Срок действия кода истёк. Запросите новый',
  loginVerifyFailed: 'Не удалось подтвердить код. Попробуйте ещё раз',
  loginPhoneConfirmed: 'Номер подтверждён',
  moderationTitle: 'Модерация',
  moderationDenied: 'Доступ только для администраторов',
  moderationTabNew: 'Новые',
  moderationTabRejected: 'Отклонённые',
  moderationEmptyNew: 'Новых объявлений нет',
  moderationEmptyRejected: 'Отклонённых объявлений нет',
  moderationApprove: 'Одобрить',
  moderationReject: 'Отклонить',
  moderationApproved: 'Объявление опубликовано',
  moderationRejected: 'Объявление отклонено',
  moderationNoPhoto: 'Без фото',
  moderationReasonTitle: 'Опишите, что не так с объявлением',
  moderationReasonRequired: 'Укажите причину отклонения',
  moderationReasonOther: 'Другое (указать причину вручную)…',
  moderationReasonPhotos: 'Данные не совпадают с фото (марка, модель, год или состояние)',
  moderationReasonDuplicate: 'Дубликат: такое же объявление уже размещено',
  moderationReasonForbidden: 'Запрещённый объект: не легковой автомобиль, авто в розыске/аресте/залоге',
  moderationReasonContacts: 'Контакты в описании или на фото (укажите телефон в отдельном поле)',
  moderationReasonPrice: 'Недостоверная цена (заниженная/ложная для привлечения внимания)',
  moderationReasonDescription: 'Некорректное описание: оскорбления, спам или реклама сторонних сайтов',
  moderationReasonFraud: 'Признаки мошенничества (предоплата, «пригон под заказ», подозрительная схема)',
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
  monthNamesShort: [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ],
  weekdayNamesShort: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  listingOne: 'объявление',
  listingFew: 'объявления',
  listingMany: 'объявлений',
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
  badgeRent: 'Iznajmljivanje',
  formBrand: 'Marka',
  formModel: 'Model',
  formCity: 'Grad',
  formBodyType: 'Tip karoserije',
  formTransmission: 'Menjač',
  formMileage: 'Kilometraža, km',
  formPrice: 'Cena, €',
  formRentPrice: 'Cena najma po danu, EUR',
  formListingType: 'Tip oglasa',
  formSelect: 'Izaberite',
  formAny: 'Nije važno',
  formAll: 'Sve',
  formOptional: 'Opciono',
  formNotSet: 'Nije navedeno',
  formSearchHint: 'Pretraga…',
  formSearchOrEnter: 'Pretraga ili unos…',
  formSetCustom: 'Postavi „{value}“',
  formNoModels: 'Nema modela za ovu marku',
  formRangeFrom: '{label} od',
  formRangeTo: '{label} do',
  filtersShowResults: 'Prikaži oglase',
  carDescriptionHint: 'Stanje, oprema, istorija…',
  createTitleNew: 'Novi oglas',
  createTitleEdit: 'Izmena',
  createTitleCopy: 'Kopija oglasa',
  createPublish: 'Objavi',
  createSaveAndSend: 'Sačuvaj i pošalji',
  createSaving: 'Čuvamo…',
  createSentToModeration: 'Oglas je poslat na moderaciju',
  createEditSent: 'Izmene su poslate na moderaciju',
  createTypeRequired: 'Izaberite tip oglasa: prodaja ili najam',
  createWaitPhotos: 'Sačekajte da se fotografije otpreme',
  createPhotosTitle: 'Fotografije ({current}/{max})',
  createPhotoLimit: 'Možete dodati najviše {max} fotografija',
  createPhotoTrimmed: 'Dodato prvih {added} od {total} — ograničenje {max} fotografija',
  createPhotoFailed: 'Otpremanje dela fotografija nije uspelo',
  createPublishFailed: 'Greška pri objavi',
  createConfirmPhoneTitle: 'Potvrdite broj telefona',
  createConfirmPhoneBody: 'Potvrdite svoj broj {phone} — poslaćemo kod SMS-om.',
  createPhoneRequired: 'Za objavu oglasa potrebno je potvrditi broj telefona',
  createSessionExpired: 'Sesija je istekla — dodajte fotografije ponovo da potvrdite broj',
  commonOk: 'U redu',
  profileLogin: 'Prijava',
  profileLogoutFull: 'Odjavi se sa naloga',
  profileLoggingOut: 'Odjavljujemo…',
  profileAddName: 'Dodajte ime',
  profileSave: 'Sačuvaj',
  profileMyListings: 'Moji oglasi',
  profileModeration: 'Moderacija oglasa',
  profileLegal: 'Politika i uslovi',
  profilePhoneCopied: 'Broj je kopiran',
  profilePhotoFailed: 'Ažuriranje fotografije nije uspelo',
  profileNameFailed: 'Čuvanje imena nije uspelo',
  carTransmissionShort: 'Menjač',
  carSoldNotice: 'Oglas je prodat — kontakt sa prodavcem je zatvoren',
  moderationReasonPhotoMismatch: 'Fotografije se ne poklapaju: tuđe slike, pogrešan automobil ili loš kvalitet',
  moderationReasonCustom: 'Sopstveni razlog',
  moderationRejectReason: 'Razlog odbijanja',
  moderationReasonPrefix: 'Razlog: {text}',
  validateCityRequired: 'Unesite grad',
  validateBrandRequired: 'Unesite marku automobila',
  validateModelRequired: 'Unesite model automobila',
  validateYearRequired: 'Unesite godište',
  validateYearTooOld: 'Godište ne može biti pre 1900',
  validateYearFuture: 'Godište ne može biti u budućnosti',
  validatePricePositive: 'Cena mora biti veća od nule',
  validatePhotoRequired: 'Dodajte bar jednu fotografiju automobila',
  validatePhoneRequired: 'Unesite kontakt telefon',
  validatePhoneFormat: 'Unesite ispravan broj: mob. +381 6X XXX XXX ili fiksni +381 11 XXX XXX',
  createAfterPublishNote: 'Nakon objave oglas ide na moderaciju i pojaviće se u katalogu posle odobrenja.',
  createPriceLabel: 'Cena, EUR',
  createPricePositive: 'Cena mora biti veća od nule ili ostavite polje prazno',
  createDuplicateExists: 'Takav oglas već postoji',
  createPhoneNoteSuffix: 'poslaćemo kod SMS-om.',
  catalogFavoriteFailed: 'Ažuriranje omiljenih nije uspelo',
  catalogHideCarFailed: 'Sakrivanje oglasa nije uspelo',
  catalogHideCityFailed: 'Sakrivanje grada nije uspelo',
  authOtpLimit: 'Prekoračen je limit zahteva za kod ({count} dnevno). Pokušajte sutra ili se prijavite kasnije.',
  savedSearchAll: 'Svi oglasi',
  savedSearchFrom: 'od {value}',
  savedSearchTo: 'do {value}',
  savedSearchYearSuffix: 'god.',
  notificationsTitle: 'Obaveštenja',
  notificationsEmpty: 'Još nema obaveštenja',
  notificationsReadAll: 'Označi sve kao pročitano',

  navCatalog: 'Katalog',
  navFavorites: 'Omiljeno',
  navCreate: 'Postavi',
  navSell: 'Prodaj auto',
  navMenu: 'Meni',
  commonUser: 'Korisnik',
  commonNoName: 'Bez imena',
  commonYesterday: 'Juče',
  commonNothingFound: 'Nema rezultata',
  commonErrorGeneric: 'Nešto nije u redu. Pokušajte ponovo.',
  commonErrorNetwork: 'Nema veze sa serverom. Proverite internet i pokušajte ponovo.',
  chatsGuest: 'Prijavite se da biste videli poruke',
  chatsEmptyTitle: 'Još nema poruka',
  chatsEmptyBody: 'Pišite prodavcu sa stranice oglasa.',
  chatsSearchEmptyBody: 'Promenite upit: ime sagovornika, marka ili model.',
  chatNoMessages: 'Još nema poruka',
  chatPin: 'Zakači',
  chatUnpin: 'Otkači',
  chatUnblock: 'Odblokiraj',
  chatPinFailed: 'Zakačivanje nije uspelo',
  chatBlockFailed: 'Blokiranje nije uspelo',
  chatUnblockFailed: 'Odblokiranje nije uspelo',
  chatSendFailed: 'Slanje nije uspelo',
  chatBlockedSuffix: '{name} je blokiran',
  chatUnblockedSuffix: '{name} je odblokiran',
  loginTitle: 'Prijava telefonom',
  loginPhoneLabel: 'Telefon',
  loginHint: 'Unesite broj — poslaćemo kod SMS-om. Lozinka nije potrebna.',
  loginSendCode: 'Pošalji kod',
  loginSending: 'Šaljemo…',
  loginCodeLabel: 'Unesite kod iz SMS-a',
  loginCodeSentTo: 'Poslali smo kod na broj {phone}',
  loginChangeNumber: 'Promeni broj',
  loginResend: 'Pošalji ponovo',
  loginResendIn: 'Pošalji ponovo ({seconds})',
  loginResent: 'Kod je ponovo poslat',
  loginChecking: 'Proveravamo kod…',
  loginAsGuest: 'Nastavi kao gost',
  loginPhoneInvalid: 'Unesite ispravan broj telefona',
  loginCodeInvalid: 'Pogrešan kod iz SMS-a',
  loginCodeExpired: 'Kod je istekao. Zatražite novi',
  loginVerifyFailed: 'Potvrda koda nije uspela. Pokušajte ponovo',
  loginPhoneConfirmed: 'Broj je potvrđen',
  moderationTitle: 'Moderacija',
  moderationDenied: 'Pristup samo za administratore',
  moderationTabNew: 'Novi',
  moderationTabRejected: 'Odbijeni',
  moderationEmptyNew: 'Nema novih oglasa',
  moderationEmptyRejected: 'Nema odbijenih oglasa',
  moderationApprove: 'Odobri',
  moderationReject: 'Odbij',
  moderationApproved: 'Oglas je objavljen',
  moderationRejected: 'Oglas je odbijen',
  moderationNoPhoto: 'Bez fotografije',
  moderationReasonTitle: 'Opišite šta nije u redu sa oglasom',
  moderationReasonRequired: 'Navedite razlog odbijanja',
  moderationReasonOther: 'Drugo (navedite razlog)…',
  moderationReasonPhotos: 'Podaci se ne poklapaju sa fotografijama (marka, model, godište ili stanje)',
  moderationReasonDuplicate: 'Duplikat: isti oglas već postoji',
  moderationReasonForbidden: 'Zabranjen predmet: nije putnički automobil, vozilo je traženo/zaplenjeno/pod hipotekom',
  moderationReasonContacts: 'Kontakti u opisu ili na fotografiji (unesite telefon u posebno polje)',
  moderationReasonPrice: 'Netačna cena (spuštena/lažna radi privlačenja pažnje)',
  moderationReasonDescription: 'Neprikladan opis: uvrede, spam ili reklama drugih sajtova',
  moderationReasonFraud: 'Znaci prevare (avans, „dovoz po porudžbini“, sumnjiva šema)',
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
  monthNamesShort: [
    'jan', 'feb', 'mar', 'apr', 'maj', 'jun',
    'jul', 'avg', 'sep', 'okt', 'nov', 'dec',
  ],
  weekdayNamesShort: ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'],
  listingOne: 'oglas',
  listingFew: 'oglasa',
  listingMany: 'oglasa',
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
