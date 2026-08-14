// ============================================================
// AUTO.RS — Репозиторий объявлений (cars).
// Все запросы к таблице cars инкапсулированы здесь.
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/car_image_model.dart';
import '../models/car_model.dart';

class CarsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // ----------------------------------------------------------
  // Каталог продажи. RLS сам вернёт только active-объявления гостю.
  // ----------------------------------------------------------
  Future<List<CarModel>> fetchForSale({int limit = 30}) async {
    final rows = await _client
        .from('cars')
        .select()
        .eq('is_for_sale', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Каталог аренды.
  // ----------------------------------------------------------
  Future<List<CarModel>> fetchForRent({int limit = 30}) async {
    final rows = await _client
        .from('cars')
        .select()
        .eq('is_for_rent', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Двуалфавитный поиск (кириллица/латиница).
  // ilike по паре brand/model/city. Индексы f_normalize+trgm в БД
  // ускоряют нечёткое совпадение; здесь используем ilike как базовый
  // клиентский фильтр. Точный unaccent-поиск лучше вынести в RPC —
  // добавим на следующем шаге.
  // ----------------------------------------------------------
  Future<List<CarModel>> search(String query, {int limit = 30}) async {
    final q = '%$query%';
    final rows = await _client
        .from('cars')
        .select()
        .or('brand.ilike.$q,model.ilike.$q,city.ilike.$q')
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Двуалфавитный нечёткий поиск через серверную RPC search_cars_v2
  // (миграция 0008). Устойчив к диакритике и опечаткам (unaccent + pg_trgm).
  // Предпочтительный способ поиска вместо клиентского ilike выше.
  // ----------------------------------------------------------
  Future<List<CarModel>> searchV2(String query) async {
    final rows = await _client.rpc('search_cars_v2', params: {
      'search_query': query,
    });
    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Расширенный поиск каталога (RPC search_cars_advanced, миграция 0017):
  // тип объявления + двуалфавитный поиск + гео-радиус (PostGIS).
  // Любой параметр можно опустить (null) — соответствующий фильтр не применится.
  // radiusKm > 0 вместе с координатами включает гео-фильтр и сортировку
  // по близости; иначе — сортировка по свежести.
  // ----------------------------------------------------------
  Future<List<CarModel>> searchAdvanced({
    String? listingType, // 'sale' | 'rent' | null
    String? query,
    double? userLat,
    double? userLng,
    double? radiusKm,
    // Фильтры (все опциональны)
    String? brand,
    String? model,
    String? city,
    int? yearFrom,
    int? yearTo,
    int? mileageMax,
    double? priceFrom,
    double? priceTo,
    String? bodyType,
    String? transmission,
    String? fuel,
    // Бесконечная лента (миграция 0030): seed круга, смещение, размер
    // страницы и флаг полного шафла (круги 2+). По умолчанию — первый
    // круг, страница 20, свежие/близкие сверху.
    int seed = 0,
    int offset = 0,
    int limit = 20,
    bool shuffleAll = false,
  }) async {
    final rows = await _client.rpc('search_cars_advanced', params: {
      'p_listing_type': listingType,
      'p_search_query': query,
      'p_user_lat': userLat,
      'p_user_lng': userLng,
      'p_radius_km': radiusKm,
      'p_brand': brand,
      'p_model': model,
      'p_city': city,
      'p_year_from': yearFrom,
      'p_year_to': yearTo,
      'p_mileage_max': mileageMax,
      'p_price_from': priceFrom,
      'p_price_to': priceTo,
      'p_body_type': bodyType,
      'p_transmission': transmission,
      'p_fuel': fuel,
      'p_seed': seed,
      'p_offset': offset,
      'p_limit': limit,
      'p_shuffle_all': shuffleAll,
    });
    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Мои объявления (все статусы). RLS отдаёт владельцу свои строки.
  // ----------------------------------------------------------
  Future<List<CarModel>> fetchMyCars(String userId) async {
    final rows = await _client
        .from('cars')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return _mapRows(rows);
  }

  // ----------------------------------------------------------
  // Создание объявления через серверную RPC create_car_v2 (миграция 0014).
  // user_id ставит сервер (auth.uid()), фото пишутся в car_images,
  // координаты конвертируются в PostGIS. Возвращает id созданного авто.
  // listingType: 'sale' | 'rent' | 'both'.
  // ----------------------------------------------------------
  Future<String> createCarV2({
    required String listingType,
    required String brand,
    required String model,
    required int year,
    int? mileage,
    double? price, // null → «Договорная»
    String currency = 'EUR',
    required String city,
    double? lat,
    double? lng,
    List<String> photoUrls = const [],
    // Характеристики (как в фильтрах). null = не указано.
    String? bodyType,
    String? transmission,
    String? fuel,
    String? description,
    // Контактный телефон (сербский мобильный). Нормализуется на бэкенде.
    required String phone,
  }) async {
    final id = await _client.rpc('create_car_v2', params: {
      'listing_type': listingType,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'price': price,
      'currency': currency,
      'city': city,
      'lat': lat,
      'lng': lng,
      'photo_urls': photoUrls,
      'p_body_type': bodyType,
      'p_transmission': transmission,
      'p_fuel': fuel,
      'p_description': description,
      'p_phone': phone,
    });
    return id as String;
  }

  // Редактирование своего объявления (RPC update_car_v2, миграция 0039).
  // После сохранения статус → moderation (снова на проверку). photoUrls
  // передаём заново — набор фото полностью заменяется. Возвращает id.
  Future<String> updateCarV2({
    required String carId,
    required String listingType,
    required String brand,
    required String model,
    required int year,
    int? mileage,
    double? price,
    String currency = 'EUR',
    required String city,
    double? lat,
    double? lng,
    List<String> photoUrls = const [],
    String? bodyType,
    String? transmission,
    String? fuel,
    String? description,
    required String phone,
  }) async {
    final id = await _client.rpc('update_car_v2', params: {
      'p_car_id': carId,
      'listing_type': listingType,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'price': price,
      'currency': currency,
      'city': city,
      'lat': lat,
      'lng': lng,
      'p_photo_urls': photoUrls,
      'p_body_type': bodyType,
      'p_transmission': transmission,
      'p_fuel': fuel,
      'p_description': description,
      'p_phone': phone,
    });
    return id as String;
  }

  // ----------------------------------------------------------
  // Смена статуса СВОЕГО объявления (RLS cars_update_own: auth.uid()=user_id).
  //   'sold'     — продано (убирается из каталога);
  //   'archived' — снято с публикации (можно вернуть редактированием);
  // Прямой UPDATE — RPC не нужен, права проверяет RLS.
  // ----------------------------------------------------------
  Future<void> setCarStatus(String carId, String status) async {
    await _client.from('cars').update({'status': status}).eq('id', carId);
  }

  // ----------------------------------------------------------
  // Карточка одного объявления по id.
  // ----------------------------------------------------------
  Future<CarModel?> fetchById(String id) async {
    final row = await _client
        .from('cars')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return CarModel.fromMap(row);
  }

  // ----------------------------------------------------------
  // Загрузка одного фото в бакет car-images.
  // Путь ОБЯЗАН начинаться с auth.uid() (иначе RLS бакета отклонит):
  //   "<uid>/<tempCarUuid>/<index>.jpg".
  // Возвращает публичный URL загруженного файла (бакет public).
  // ----------------------------------------------------------
  Future<String> uploadCarImage({
    required String tempCarUuid,
    required int index,
    required List<int> bytes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Требуется авторизация для загрузки фото');
    }
    // Первый сегмент пути = uid (требование RLS car-images)
    final path = '$userId/$tempCarUuid/$index.jpg';

    await _client.storage.from('car-images').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // Публичная ссылка на файл (бакет car-images публичный на чтение)
    return _client.storage.from('car-images').getPublicUrl(path);
  }

  // ----------------------------------------------------------
  // Удаление ВРЕМЕННЫХ фото объявления из Storage (до публикации).
  // Вызывается, когда пользователь загрузил фото, но ушёл с формы, не
  // опубликовав: в БД (car_images) записи ещё нет, поэтому чистим только
  // файлы папки "<uid>/<tempCarUuid>/". Ошибки глушим — это фоновая уборка.
  // ----------------------------------------------------------
  Future<void> deleteTempCarImages(String tempCarUuid) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // гость файлов и не грузил
    final dir = '$userId/$tempCarUuid';
    try {
      final files = await _client.storage.from('car-images').list(path: dir);
      if (files.isEmpty) return;
      final paths = files.map((f) => '$dir/${f.name}').toList();
      await _client.storage.from('car-images').remove(paths);
    } catch (_) {
      // Уборка не критична: временные файлы не мешают и не попадают в каталог.
    }
  }

  // ----------------------------------------------------------
  // Фото объявления по порядку галереи (order_index ASC).
  // ----------------------------------------------------------
  Future<List<CarImageModel>> fetchImages(String carId) async {
    final rows = await _client
        .from('car_images')
        .select()
        .eq('car_id', carId)
        .order('order_index', ascending: true);

    return (rows as List)
        .map((e) => CarImageModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Марки из справочника car_brands (RPC get_car_brands).
  // Полный каталог марок, а не только те, что есть в объявлениях.
  // ----------------------------------------------------------
  Future<List<String>> fetchBrands() async {
    final rows = await _client.rpc('get_car_brands');

    final list = <String>[];
    for (final r in (rows as List)) {
      final n = (r as Map<String, dynamic>)['name'] as String?;
      if (n != null && n.trim().isNotEmpty) list.add(n.trim());
    }
    return list; // RPC уже сортирует по name
  }

  // ----------------------------------------------------------
  // Модели конкретной марки из справочника car_models (RPC get_car_models).
  // Берём по НАЗВАНИЮ марки (нормализация на стороне БД), поэтому список
  // не зависит от наличия объявлений — виден весь модельный ряд.
  // ----------------------------------------------------------
  Future<List<String>> fetchModelsByBrand(String brand) async {
    final rows = await _client.rpc(
      'get_car_models',
      params: {'p_brand_name': brand},
    );

    final list = <String>[];
    for (final r in (rows as List)) {
      final m = (r as Map<String, dynamic>)['name'] as String?;
      if (m != null && m.trim().isNotEmpty) list.add(m.trim());
    }
    return list; // RPC уже сортирует по name
  }

  // ----------------------------------------------------------
  // Скрыть объявление из каталога («не интересует это объявление»).
  // Постоянно, через RPC hide_car (миграция 0031). Требует авторизации.
  // ----------------------------------------------------------
  Future<void> hideCar(String carId) async {
    await _client.rpc('hide_car', params: {'p_car_id': carId});
  }

  // ----------------------------------------------------------
  // Скрыть все объявления города («не подходит город или регион»).
  // Через RPC hide_city (город нормализуется на сервере). Требует авторизации.
  // ----------------------------------------------------------
  Future<void> hideCity(String city) async {
    await _client.rpc('hide_city', params: {'p_city': city});
  }

  List<CarModel> _mapRows(dynamic rows) {
    return (rows as List)
        .map((e) => CarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
