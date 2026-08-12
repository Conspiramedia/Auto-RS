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
  }) async {
    final rows = await _client.rpc('search_cars_advanced', params: {
      'p_listing_type': listingType,
      'p_search_query': query,
      'p_user_lat': userLat,
      'p_user_lng': userLng,
      'p_radius_km': radiusKm,
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
    required double price,
    String currency = 'EUR',
    required String city,
    double? lat,
    double? lng,
    List<String> photoUrls = const [],
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
    });
    return id as String;
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

  List<CarModel> _mapRows(dynamic rows) {
    return (rows as List)
        .map((e) => CarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
