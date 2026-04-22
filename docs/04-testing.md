# Шаг 4 · Тестирование End-to-End (4 минуты)

Убедимся что весь pipeline работает корректно.

## 4.1 Подготовьте тестовый документ

**Вариант A**: Возьмите любой реальный DOCX/PDF от DMC (программа тура с трансферами)

**Вариант B**: Используйте готовый сэмпл (сгенерируйте через скрипт):

```bash
cd scripts/
node generate-sample.js
# Создаст файл test-request.docx с программой на 7 дней по Узбекистану
```

**Вариант C**: Скачайте тестовую программу Hugo Villar USA 10 days из [docs/samples/](./samples/)

## 4.2 Тест через curl (опционально)

Для быстрой проверки webhook без UI:

```bash
bash scripts/test-webhook.sh path/to/your-request.docx
```

Ожидаемый вывод:
```
✓ Webhook отвечает: HTTP 200
✓ request_id: REQ-2026-12345
✓ Извлечено дней: 10
✓ Извлечено сегментов: 14
✓ Уверенность Claude: 94%
✓ Записано в БД: transfer_requests (1), transfer_segments (14)
✓ Найдено водителей: 6 (в 4 городах)
Полный JSON: ...
```

## 4.3 Тест через Dashboard

Полный happy-path сценарий:

### ▶ Tест 1: Обработка заявки
1. Откройте Dashboard: `https://YOUR-USERNAME.github.io/waylo-ai/dashboard/`
2. Загрузите тестовый DOCX через dropzone
3. **Ожидаемо**: pipeline проходит все 5 шагов за 8-12 секунд
4. **Проверка**: в секции Шаг 3 отображается модульный маршрут с корректными датами, временами, городами

### ▶ Tест 2: Отправка водителям (SLA + эскалация)
1. На экране результата нажмите **"Отправить 4 водителям"**
2. **Ожидаемо**: открывается Шаг 4 со списком водителей в жёлтой обводке, таймеры обратного отсчёта 14:59
3. Подождите 2-8 секунд — должна начаться симуляция:
   - 3 водителя подтверждают
   - 1 отказывается
   - Автоматически выбирается замена (карточка "Рахимов Мурад")
4. **Проверка**: зелёный банер "Все водители подтверждены", кнопка "Завершить"

### ▶ Tест 3: Driver PWA
1. Откройте Driver App: `https://YOUR-USERNAME.github.io/waylo-ai/driver/`
2. Наверху входящая заявка с таймером
3. Нажмите **"Принять"** → sheet подтверждения → **"Подтвердить"**
4. **Ожидаемо**:
   - Карточка заявки исчезает с анимацией
   - В списке предстоящих поездок появляется новая карточка "Hugo Villar, 11 мая"
   - Toast "Заявка принята · 11 мая забронирован в календаре"
5. Перейдите во вкладку **"Календарь"**
6. **Проверка**: 11 мая — тёмно-зелёный (booked), в "Забронированные дни" добавилась Hugo Villar

### ▶ Tест 4: База данных
Проверьте что данные реально пишутся в Supabase:

```sql
-- В Supabase SQL Editor:

-- Последняя заявка
SELECT tour_name, pax_count, vehicle_category, total_segments, ai_confidence, status
FROM transfer_requests ORDER BY created_at DESC LIMIT 1;

-- Сегменты этой заявки
SELECT day_number, transfer_date, time_from, time_to, dispatch_city, location_from, location_to
FROM transfer_segments
WHERE request_id = (SELECT id FROM transfer_requests ORDER BY created_at DESC LIMIT 1)
ORDER BY day_number, sequence;

-- Доступные водители на конкретный день
SELECT * FROM find_available_drivers('tashkent', '2026-05-11', 'sedan', 2, 5);
```

## 4.4 Чек-лист готовности к продакшену

- [ ] `transfer_requests` заполняется корректными данными
- [ ] `transfer_segments` содержит все сегменты с правильным dispatch_city
- [ ] Функция `find_available_drivers()` возвращает водителей отсортированных по рейтингу
- [ ] AI-точность (`ai_confidence`) > 0.85 на хороших документах
- [ ] Dashboard корректно отображает результат parsing
- [ ] Driver PWA: принятие → календарь обновляется
- [ ] n8n executions: 0 ошибок на 10 тестовых запросах
- [ ] CORS работает с вашего домена
- [ ] SSL везде включён

## 4.5 Метрики производительности

Замеры на чистом pipeline:

| Шаг | Время | Что зависит |
|-----|-------|-------------|
| Upload + Validate | 0.2-0.5s | Размер файла |
| Extract text (DOCX/PDF) | 0.5-2s | Сложность документа |
| Claude parsing | 4-8s | Длина текста, сложность |
| Normalize + Classify | <0.1s | — |
| Supabase insert | 0.3-0.8s | Latency до Supabase EU |
| Find drivers | 0.2-0.5s | Количество водителей в БД |
| **Total E2E** | **6-12s** | |

Если ваш pipeline занимает больше 20 секунд — откройте Executions в n8n и найдите узкое место.

## 4.6 Нагрузочное тестирование (опционально)

Перед публичным запуском стоит проверить на объёмах:

```bash
# 10 параллельных запросов
for i in {1..10}; do
  bash scripts/test-webhook.sh test-request.docx &
done
wait
```

**Ожидаемо**: все 10 обрабатываются за 15-25 секунд, все успешны.

## Диагностика

**Проблема: Claude часто возвращает неполный JSON**
- Решение: увеличьте `max_tokens` в ноде "Claude · Extract" с 4096 до 8192

**Проблема: "Connection timeout" на Supabase при большой нагрузке**
- Решение: в Supabase → Settings → Database → Connection Pooling, переключитесь на **Transaction mode** (порт 6543). Обновите порт в n8n credential.

**Проблема: Dashboard не получает ответ от webhook (висит)**
- Решение: в n8n workflow откройте ноду "Webhook · Intake" → Settings → **Response Mode** должен быть `Using 'Respond to Webhook' Node`

---

## Готово! 🎉

Ваша платформа работает end-to-end. Следующие шаги:

- Добавить реальных водителей в БД
- Настроить Telegram Bot для уведомлений
- Включить RLS политики в Supabase для безопасности
- Подключить домен к GitHub Pages
- Начать pilot с 2-3 DMC

[← Вернуться к главному README](../README.md)
