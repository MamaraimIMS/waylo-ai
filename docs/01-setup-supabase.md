# Шаг 1 · Настройка Supabase (5 минут)

Supabase — это "Firebase на PostgreSQL". Даёт нам БД, REST API и Realtime без написания бэкенда. Бесплатный тариф покрывает первые 500 MB.

## 1.1 Создайте проект

1. Откройте **[supabase.com](https://supabase.com)** и зарегистрируйтесь (через GitHub рекомендую — удобнее)
2. Нажмите **"New project"**
3. Заполните:
   - **Name**: `waylo-ai`
   - **Database Password**: сгенерируйте надёжный пароль и **обязательно сохраните** — понадобится для n8n
   - **Region**: выберите ближайший (`Frankfurt (eu-central-1)` оптимален для СНГ)
   - **Pricing Plan**: Free
4. Нажмите **"Create new project"** и подождите ~2 минуты пока поднимется

## 1.2 Применить SQL-схему

Пока проект создаётся, подготовьте схему:

1. Откройте файл [`database/schema.sql`](../database/schema.sql) в этом репозитории
2. Скопируйте **всё содержимое** (Ctrl+A → Ctrl+C)
3. В Supabase Dashboard → левое меню → **SQL Editor** → **New query**
4. Вставьте схему (Ctrl+V) и нажмите **Run** (или `Ctrl+Enter`)

Должно появиться сообщение **"Success. No rows returned"**.

**Проверка**: в левом меню → **Table editor** — вы увидите 10 таблиц: `dmc_companies`, `users`, `drivers`, `vehicles`, `calendar_slots`, `transfer_requests`, `transfer_segments`, `driver_assignments`, `audit_log`. В `dmc_companies` уже есть 3 записи (Advantour, East Line Tour, Silk Road), в `drivers` — 4 тестовых водителя.

## 1.3 Получить connection string для n8n

Это нужно чтобы n8n Cloud мог писать в вашу базу.

1. В Supabase Dashboard → **Settings** (шестерёнка внизу слева) → **Database**
2. Прокрутите до раздела **"Connection info"** или **"Connection string"**
3. Выберите **"Session mode"** (порт 5432)
4. Скопируйте следующие поля — они понадобятся через 5 минут:

```
Host:     db.xxxxxxxxxxx.supabase.co
Database: postgres
Port:     5432
User:     postgres
Password: <тот самый пароль, что вы сохранили>
```

> **ВАЖНО**: если вы забыли пароль, его можно сбросить в том же разделе через кнопку "Reset database password".

## 1.4 (Опционально) Получить REST API ключ

Если позже будете делать прямые запросы из фронтенда в БД без n8n:

1. **Settings** → **API**
2. Скопируйте:
   - **Project URL**: `https://xxxxxxxxxxx.supabase.co`
   - **anon public** key (для публичного доступа с RLS политиками)
   - **service_role** key (для server-side с полным доступом — **храните в секрете**)

Пока оставьте это на будущее.

## 1.5 Что получили

- ✅ Полная схема БД с 10 таблицами
- ✅ Триггер автоблокировки календаря при подтверждении водителя
- ✅ Функции `find_available_drivers()` и `classify_vehicle_by_pax()`
- ✅ Seed data: 3 DMC, 4 тестовых водителя с машинами
- ✅ Connection string для подключения n8n

---

**Следующий шаг:** [02 · Настройка n8n Cloud →](02-setup-n8n.md)
