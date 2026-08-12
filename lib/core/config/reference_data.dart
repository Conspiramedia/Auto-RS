// ============================================================
// AUTO.RS — Справочники для фильтров: марки авто и города Сербии.
// Захардкожены для MVP. Менять — правкой этого файла.
// ============================================================

class ReferenceData {
  ReferenceData._();

  // Марки автомобилей (для dropdown фильтра), по алфавиту
  static const List<String> brands = [
    'Acura', 'Afeela', 'Alfa Romeo', 'Alpine', 'Aston Martin', 'Audi',
    'Avatr', 'BMW', 'BYD', 'Baojun', 'Bentley', 'Bugatti', 'Buick',
    'Cadillac', 'Changan', 'Chery', 'Chevrolet', 'Chrysler', 'Citroen',
    'Cupra', 'Dacia', 'Daewoo', 'Daihatsu', 'Denza', 'Dodge', 'Dongfeng',
    'Exeed', 'Ferrari', 'Fiat', 'Fisker', 'Ford', 'Forthing', 'Foton',
    'GAC', 'GMC', 'Geely', 'Genesis', 'Great Wall', 'Haval', 'Hiphi',
    'Honda', 'Hongqi', 'Hummer', 'Hyundai', 'Ineos', 'Infiniti', 'Isuzu',
    'Iveco', 'JAC', 'Jaecoo', 'Jaguar', 'Jeep', 'Jetour', 'Jetta', 'Kia',
    'Koenigsegg', 'Lamborghini', 'Lancia', 'Land Rover', 'Leapmotor',
    'Lexus', 'Li Auto', 'Lincoln', 'Lotus', 'Lucid', 'Lync & Co', 'MG',
    'Mahindra', 'Maserati', 'Maxus', 'Maybach', 'Mazda', 'McLaren',
    'Mercedes-Benz', 'Mini', 'Mitsubishi', 'M-Hero', 'Neta', 'Nio',
    'Nissan', 'Omoda', 'Opel', 'Pagani', 'Peugeot', 'Polestar', 'Pontiac',
    'Porsche', 'Proton', 'Ram', 'Ravon', 'Renault', 'Rimac', 'Rivian',
    'Rolls-Royce', 'Rover', 'Saab', 'Scion', 'Seat', 'Seres', 'Škoda',
    'Smart', 'SsangYong', 'Subaru', 'Suzuki', 'Tank', 'Tata', 'Tesla',
    'Togg', 'Toyota', 'Vauxhall', 'Venucia', 'Volkswagen', 'Volvo', 'Voya',
    'Wuling', 'Xpeng', 'Yangwang', 'Zeekr',
  ];

  // Крупные города Сербии (для dropdown фильтра)
  static const List<String> cities = [
    'Beograd', 'Novi Sad', 'Niš', 'Kragujevac', 'Subotica', 'Zrenjanin',
    'Pančevo', 'Čačak', 'Kraljevo', 'Novi Pazar', 'Leskovac', 'Smederevo',
    'Valjevo', 'Kruševac', 'Vranje', 'Šabac', 'Užice', 'Sombor',
  ];

  // Типы кузова (value = enum body_type в БД, label — для показа)
  static const Map<String, String> bodyTypes = {
    'sedan': 'Седан',
    'hatchback': 'Хэтчбек',
    'suv': 'Внедорожник',
    'crossover': 'Кроссовер',
    'coupe': 'Купе',
    'wagon': 'Универсал',
    'minivan': 'Минивэн',
    'pickup': 'Пикап',
    'convertible': 'Кабриолет',
    'van': 'Фургон',
  };

  // Коробка передач
  static const Map<String, String> transmissions = {
    'manual': 'Механика',
    'automatic': 'Автомат',
    'robot': 'Робот',
    'variator': 'Вариатор',
  };

  // Тип топлива
  static const Map<String, String> fuels = {
    'petrol': 'Бензин',
    'diesel': 'Дизель',
    'hybrid': 'Гибрид',
    'electric': 'Электро',
    'gas': 'Газ',
  };
}
