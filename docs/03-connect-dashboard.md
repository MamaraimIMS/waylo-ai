# Шаг 3 · Подключение Dashboard (3 минуты)

Соединяем ваш фронтенд с работающим n8n workflow.

## 3.1 Загрузите код на GitHub

Если ещё не сделали:

```bash
# Клонируйте этот проект
git clone https://github.com/YOUR-USERNAME/waylo-ai.git
cd waylo-ai

# Или создайте новый репозиторий из этого пакета:
git init
git add .
git commit -m "Initial commit: WayloAI platform"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/waylo-ai.git
git push -u origin main
```

## 3.2 Включите GitHub Pages

1. На странице репозитория в GitHub → **Settings** → **Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main`, folder: `/ (root)`
4. **Save**

Через 30-60 секунд получите URL:
- Главная: `https://YOUR-USERNAME.github.io/waylo-ai/`
- Dashboard: `https://YOUR-USERNAME.github.io/waylo-ai/dashboard/`
- Driver App: `https://YOUR-USERNAME.github.io/waylo-ai/driver/`

> **Альтернатива**: GitHub Actions workflow (`.github/workflows/deploy.yml`) уже настроен в репозитории — при каждом push на `main` происходит автодеплой.

## 3.3 Подключите webhook в Dashboard

1. Откройте ваш Dashboard: `https://YOUR-USERNAME.github.io/waylo-ai/dashboard/`
2. Нажмите **иконку шестерёнки** в правом верхнем углу (или кнопку "Настройки")
3. В разделе **"n8n Workflow"**:
   - **URL webhook**: вставьте Production URL из Шага 2.7
   - **Токен авторизации**: оставьте пустым (если не настраивали Header Auth)
4. Нажмите **"Проверить соединение"** — должен появиться зелёный индикатор ✓
5. В разделе **"Поведение системы"**:
   - **Demo-режим**: **ВЫКЛЮЧИТЕ** (тогда реальные файлы будут уходить в n8n вместо симуляции)
6. Нажмите **"Сохранить настройки"**

Настройки сохраняются в localStorage вашего браузера — при следующем открытии не нужно повторно вводить.

## 3.4 Первый тест

1. Закройте панель настроек
2. В секции **"Шаг 1 · Загрузка заявки"** перетащите DOCX или PDF с программой тура
3. Вы должны увидеть как по очереди загораются 5 шагов pipeline:
   - ✓ Получение документа
   - ✓ Анализ содержимого
   - ✓ Построение графика
   - ✓ Подбор типа транспорта
   - ✓ Поиск водителей
4. На Шаге 3 появится модульный маршрут + список рекомендованных водителей

Обработка занимает **8-12 секунд** на документ с 10 днями.

## 3.5 Проверка записи в БД

1. Откройте Supabase → **Table editor** → **transfer_requests**
2. Должна появиться новая запись с названием тура
3. Откройте **transfer_segments** — там строки с трансферами (по одной на каждый сегмент)

Всё работает!

## Диагностика

**"Ошибка: HTTP 500" при загрузке файла?**
- Откройте n8n → Executions (левое меню) → найдите последний exec с ошибкой
- Кликните чтобы увидеть детали — n8n показывает где именно сломалось

**"CORS error" в консоли браузера?**
- В workflow уже настроен CORS (`Access-Control-Allow-Origin: *`) — но проверьте что **nod "Respond to Dashboard"** есть в workflow и она последняя
- Если проблема остаётся — в ноде "Webhook · Intake" → Settings → **Response**: `Using 'Respond to Webhook' Node`

**Claude возвращает мусор вместо JSON?**
- Первые 2-3 запроса с необычным форматом документа могут сбоить
- Откройте execution → нода "Claude · Extract" → Output — увидите что вернул Claude
- Если формат регулярно плохой — увеличьте max_tokens в ноде с 4096 до 8192

---

**Следующий шаг:** [04 · Тестирование E2E →](04-testing.md)
