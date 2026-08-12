# Экран авторизации и онбординга (Auth & Onboarding) — архитектура для FlutterFlow

Вход/регистрация через Supabase Auth, гостевой режим, онбординг выбора роли
(customer/vendor). Опирается на миграцию 0026: `profiles.user_type` +
`role_selected`. Профиль создаётся триггером `handle_new_user` (0002)
автоматически при регистрации.

---

## 1. Экран авторизации (Auth Screen)

### Структура (TabBar / переключатель Вход ↔ Регистрация)

```
AuthScreen (Column)
├── Logo / заголовок "Auto.RS"
├── TabBar [ Вход | Регистрация ]
│
├── LoginTab
│   ├── TextField Email
│   ├── TextField Password (obscure)
│   └── Button "Войти"                 → Action Flow §1.1
│
├── RegisterTab
│   ├── TextField Name
│   ├── TextField Email
│   ├── TextField Password (obscure)
│   ├── TextField Confirm Password (obscure)
│   └── Button "Зарегистрироваться"    → Action Flow §1.2
│
└── Button "Продолжить как гость"      → Action Flow §1.3
```

### 1.1. Action Flow «Войти»

```
1. Валидация: email/password не пусты
2. isLoading = true
3. Action: Supabase Auth → Log In (email, password)
4a. Success:
      isLoading = false
      Navigate To MainCatalogScreen (Replace Route)
      // онбординг роли проверится в On Page Load каталога (§3)
4b. Failure:
      isLoading = false
      SnackBar( Action Error Message )   // "Invalid login credentials" и т.п.
```

### 1.2. Action Flow «Зарегистрироваться»

```
1. Валидация формы:
   - Name/Email/Password не пусты
   - Password == Confirm Password ?  нет → SnackBar "Пароли не совпадают" → STOP
   - (Опц.) длина пароля >= 6

2. isLoading = true

3. Action: Supabase Auth → Sign Up
     email = emailField, password = passwordField
     (Опц.) user metadata: full_name = nameField
     // триггер handle_new_user (0002) создаст profiles с этим email/full_name;
     // user_type='customer', role_selected=false по умолчанию (0026)

4a. Success:
      isLoading = false
      (если email-подтверждение выключено — юзер сразу залогинен)
      Navigate To MainCatalogScreen (Replace Route)
      // на каталоге сработает онбординг выбора роли (role_selected=false)

4b. Failure:
      isLoading = false
      SnackBar( Action Error Message )
      // типичные тексты Supabase Auth:
      //  "User already registered" (email занят)
      //  "Password should be at least 6 characters" (слабый пароль)
```

### 1.3. Action Flow «Продолжить как гость»

```
1. Navigate To MainCatalogScreen (Replace Route)
   // без авторизации. Каталог доступен гостю (RPC search_cars_advanced → anon).
   // Действия, требующие auth (бронь, чат, избранное), при попытке
   // перенаправят на AuthScreen.
```

Для гостя онбординг роли НЕ показываем (нет профиля). Проверка в §3 учитывает
`currentUser == null`.

---

## 2. Онбординг выбора роли (Role Selection Bottom Sheet)

Компонент `RoleSelectionSheet` — показывается при первом входе (role_selected=false).
Не закрывается свайпом/тапом вне (isDismissible = false) — выбор обязателен.

### Widget Tree

```
RoleSelectionSheet (Column, padding)
├── Text "Как вы будете пользоваться Auto.RS?" (заголовок)
├── RoleCard "Ищу машину"  (большая карточка-кнопка)
│     иконка поиска + подпись "Покупка и аренда авто"
│     → Action Flow §2.1 (customer)
└── RoleCard "Сдаю машину" (большая карточка-кнопка)
      иконка ключа + подпись "Продажа и сдача в аренду"
      → Action Flow §2.2 (vendor)
```

### 2.1. «Ищу машину» (customer)

```
1. Supabase Update profiles
     where id = currentUser.uid
     set user_type = 'customer', role_selected = true
2. Close Bottom Sheet
3. SnackBar "Добро пожаловать! Найдите свой автомобиль."
   (остаёмся на каталоге)
```

### 2.2. «Сдаю машину» (vendor)

```
1. Supabase Update profiles
     where id = currentUser.uid
     set user_type = 'vendor', role_selected = true
2. Close Bottom Sheet
3. SnackBar "Отлично! Теперь вы можете размещать объявления."
4. Navigate To MainCatalogScreen (Replace Route — жёсткий редирект)
   // или на экран создания объявления, если хотим сразу вести вендора туда
```

> Обе ветки ставят `role_selected = true` — это гарантирует, что онбординг
> больше не всплывёт при следующих входах.

---

## 3. Логика показа онбординга (On Page Load главного экрана)

```
On Page Load  MainCatalogScreen:

1. currentUser == null (гость) ?
   └─ ДА → ничего не делаем (у гостя нет профиля/роли) → показываем каталог

2. Backend Query (Single Row) profiles по id = currentUser.uid → myProfile

3. Условие: myProfile.role_selected == false ?
   └─ ДА → Open Bottom Sheet RoleSelectionSheet
             (isDismissible = false — обязательный выбор)
   └─ НЕТ → онбординг уже пройден, ничего не делаем
```

### Почему role_selected, а не user_type == null

Поле `user_type` имеет `default 'customer'` (0026) → оно НИКОГДА не бывает null
(триггер handle_new_user проставит дефолт при регистрации). Поэтому «первый вход»
нельзя определить по `user_type is null`. Для этого и введён отдельный флаг
`role_selected` (default false): он честно отражает, делал ли пользователь
осознанный выбор роли. Как только выбрал — становится true, и Bottom Sheet
больше не появляется.

---

## 4. Сводка

| Действие | Механизм | Результат |
|---|---|---|
| Вход | Supabase Log In | → каталог, проверка онбординга |
| Регистрация | Supabase Sign Up | профиль (триггер), role_selected=false |
| Гость | Navigate без auth | каталог только для чтения |
| Выбор роли | Update user_type + role_selected=true | онбординг пройден |
| Показ онбординга | On Page Load: role_selected==false | Bottom Sheet (обязательный) |

**Ключ логики:** `role_selected` отличает «ещё не выбирал» от «выбрал customer».
`user_type` с дефолтом сам по себе для этого не годится.
```
