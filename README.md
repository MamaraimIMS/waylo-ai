# WayloAI · Transfer Intelligence Platform

> AI-платформа для автоматизации трансферов между DMC-туроператорами и водителями в Узбекистане.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Deploy](https://img.shields.io/badge/deploy-GitHub_Pages-blue)](#деплой)
[![n8n](https://img.shields.io/badge/workflow-n8n_Cloud-ff5a5f)](https://n8n.io)
[![Supabase](https://img.shields.io/badge/database-Supabase-3ecf8e)](https://supabase.com)
[![AI](https://img.shields.io/badge/AI-Claude_Sonnet_4.5-8A5CF6)](https://anthropic.com)

## Что это

DMC загружает DOCX/PDF с программой тура → AI-агент извлекает все трансферы → система строит модульный график → находит свободных водителей по рейтингу и городу → рассылает push-уведомления → собирает подтверждения → автоэскалация при отказе.

Полный цикл от получения заявки до подтверждения занимает в среднем **18 минут**.

## Архитектура

```
┌─────────────────────┐          ┌──────────────────┐
│   Dashboard (DMC)   │──POST───▶│   n8n Cloud      │
│   GitHub Pages      │◀─JSON────│   Workflow       │
└─────────────────────┘          └────────┬─────────┘
                                          │
                  ┌───────────────────────┼───────────────────────┐
                  │                       │                       │
                  ▼                       ▼                       ▼
         ┌────────────────┐      ┌────────────────┐      ┌────────────────┐
         │  Claude API    │      │   Supabase     │      │  Telegram Bot  │
         │  (Sonnet 4.5)  │      │   PostgreSQL   │      │  Notifications │
         └────────────────┘      └────────┬───────┘      └────────────────┘
                                          │
                                          ▼
                                 ┌────────────────┐
                                 │  Driver PWA    │
                                 │  GitHub Pages  │
                                 └────────────────┘
```

## Структура репозитория

```
waylo-ai/
├── dashboard/              # Веб-дашборд для DMC (диспетчер)
│   └── index.html
├── driver/                 # Мобильное PWA для водителей
│   └── index.html
├── database/               # PostgreSQL схема для Supabase
│   └── schema.sql
├── n8n/                    # n8n workflow для импорта
│   └── waylo-intake-workflow.json
├── scripts/                # Тестовые скрипты
│   ├── test-webhook.sh     # End-to-end тест pipeline
│   └── generate-sample.js  # Генератор тестовых заявок
├── docs/                   # Подробные инструкции
│   ├── 01-setup-supabase.md
│   ├── 02-setup-n8n.md
│   ├── 03-connect-dashboard.md
│   └── 04-testing.md
├── .github/workflows/
│   └── deploy.yml          # Автодеплой на GitHub Pages
└── README.md
```

## Быстрый старт (20 минут)

Полный путь от пустого репозитория до работающей системы:

| Этап | Время | Что получаем |
|------|-------|--------------|
| [Шаг 1 · Supabase](docs/01-setup-supabase.md) | 5 мин | База данных с 10 таблицами и триггерами |
| [Шаг 2 · n8n Cloud](docs/02-setup-n8n.md) | 8 мин | AI-pipeline с Claude Sonnet 4.5 |
| [Шаг 3 · Dashboard](docs/03-connect-dashboard.md) | 3 мин | Подключение фронтенда к n8n |
| [Шаг 4 · Тестирование](docs/04-testing.md) | 4 мин | E2E тест с реальным документом |

## Деплой

### Dashboard + Driver PWA → GitHub Pages

После git push автоматически деплоится через GitHub Actions:

- Dashboard: `https://<your-username>.github.io/waylo-ai/dashboard/`
- Driver PWA: `https://<your-username>.github.io/waylo-ai/driver/`

### n8n workflow → n8n Cloud

1. Зарегистрируйтесь на [n8n.cloud](https://n8n.cloud) (14 дней бесплатно, потом $20/мес)
2. Импортируйте `n8n/waylo-intake-workflow.json`
3. Подключите credentials: Anthropic API + Supabase

### Database → Supabase

1. Создайте проект на [supabase.com](https://supabase.com) (бесплатный Free tier)
2. В SQL Editor выполните `database/schema.sql`
3. Скопируйте connection string в n8n credentials

## Технологический стек

- **Frontend**: Vanilla HTML/CSS/JS, Roboto + Roboto Mono, светлая/тёмная тема
- **Backend**: n8n Cloud (workflow automation)
- **Database**: PostgreSQL 15 on Supabase (+ PostGIS для гео-данных)
- **AI**: Claude Sonnet 4.5 (Anthropic API)
- **Notifications**: Telegram Bot API
- **Hosting**: GitHub Pages (static)
- **CI/CD**: GitHub Actions

## Стоимость эксплуатации

На 1000 заявок в месяц:

| Сервис | План | Стоимость |
|--------|------|-----------|
| Claude Sonnet 4.5 (~15K input + 2K output tokens/заявка) | Pay-as-you-go | ~$60 |
| Supabase | Free tier до 500MB, Pro $25/мес после | $0–25 |
| n8n Cloud | Starter | $20 |
| GitHub Pages | Free | $0 |
| Telegram Bot | Free | $0 |
| **ИТОГО** | | **~$80–105/мес** |

При тарифе $3 с заявки для DMC: unit economics = 96% маржа.

## Дорожная карта

- [x] AI-парсинг DOCX/PDF заявок
- [x] Модульный график трансферов
- [x] Матчинг водителей по рейтингу и календарю
- [x] Dashboard для DMC (диспетчер)
- [x] Mobile PWA для водителей
- [x] SLA-таймер с автоэскалацией (15 мин)
- [ ] Интеграция платёжной системы (Payme/Click)
- [ ] Live tracking водителя в день трансфера (WebSocket + geo)
- [ ] Мультиязычность (UZ/RU/EN)
- [ ] Expansion на Казахстан, Кыргызстан

## Лицензия

MIT © 2026

## Контакты

Вопросы и баги: [открыть issue](../../issues/new)
