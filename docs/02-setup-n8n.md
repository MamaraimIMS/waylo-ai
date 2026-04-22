# Шаг 2 · Настройка n8n Cloud (8 минут)

n8n — оркестратор workflow. Здесь живёт логика: принять файл → вытащить текст → отправить в Claude → сохранить в Supabase → найти водителей.

## 2.1 Создайте аккаунт n8n Cloud

1. Откройте **[n8n.cloud](https://n8n.cloud)** → **Get started for free**
2. Регистрация через email или GitHub
3. Выберите план: **Starter** ($20/мес, 14 дней trial бесплатно)
4. Выберите регион: **Europe** (ниже latency к Supabase EU-central)
5. Имя workspace: `waylo`

После создания откроется dashboard n8n.

## 2.2 Получите Anthropic API key

Это ключ для обращения к Claude Sonnet 4.5.

1. Откройте **[console.anthropic.com](https://console.anthropic.com)**
2. Зарегистрируйтесь или войдите
3. Добавьте платёжный метод (для бесплатного тира нужна карта, но первые $5 бесплатно)
4. **Settings** → **API Keys** → **Create Key**
5. Имя: `waylo-n8n-production`
6. Скопируйте ключ (начинается с `sk-ant-api03-...`) — он показывается только один раз!

## 2.3 Импортируйте workflow

1. В n8n: **Workflows** (левое меню) → **Add workflow** → стрелка вниз → **Import from file**
2. Выберите файл [`n8n/waylo-intake-workflow.json`](../n8n/waylo-intake-workflow.json) из репозитория
3. Workflow откроется — вы увидите 15 нод, соединённых пайплайном

Пока он не работает — нужно настроить credentials.

## 2.4 Credential 1/2: Anthropic API

1. В открытом workflow кликните на ноду **"Claude · Extract"** (фиолетовая)
2. В поле **Credential to connect with** нажмите **"Create new credential"**
3. В открывшемся модальном окне:
   - Имя: `Anthropic API`
   - **Name**: `x-api-key`
   - **Value**: вставьте ваш `sk-ant-api03-...` ключ
4. Нажмите **Save**
5. Закройте ноду

## 2.5 Credential 2/2: Supabase PostgreSQL

1. Кликните на любую ноду с префиксом **"Supabase · ..."** (например "Supabase · Insert Request")
2. **Credential to connect with** → **Create new credential**
3. Заполните из данных Шага 1.3:
   - **Host**: `db.xxxxxxxxxxx.supabase.co` (из Supabase Settings → Database)
   - **Database**: `postgres`
   - **User**: `postgres`
   - **Password**: тот пароль, который вы сохранили при создании Supabase проекта
   - **Port**: `5432`
   - **SSL**: `require` ⚠️ **обязательно!** Supabase требует SSL
   - **Ignore SSL Issues**: оставьте выключенным
4. Нажмите **Save**
5. **Test connection** (внизу модалки) — должен зажечься зелёный индикатор "Connection successful"

Теперь этот credential будет использоваться во всех Supabase-нодах автоматически.

## 2.6 Активируйте workflow

1. Переключатель **Inactive** → **Active** (справа вверху рядом с именем workflow)
2. **Save** (если нужно — иногда n8n просит явно сохранить)

## 2.7 Получите Webhook URL

1. Кликните на первую ноду — **"Webhook · Intake"**
2. Вверху вы увидите два URL:
   - **Test URL**: `https://xxxxx.app.n8n.cloud/webhook-test/waylo-intake` — работает только при открытом редакторе (для отладки)
   - **Production URL**: `https://xxxxx.app.n8n.cloud/webhook/waylo-intake` — **этот нам нужен**
3. Скопируйте **Production URL**

## 2.8 Что получили

- ✅ Активный workflow с 15 нодами
- ✅ Claude API подключён и готов принимать DOCX/PDF
- ✅ Supabase подключена — данные будут записываться в БД
- ✅ Webhook URL для подключения к дашборду

## Диагностика

**"Connection failed" в Supabase credential?**
- Проверьте что SSL = `require`
- Проверьте пароль (если не уверены — сбросьте в Supabase Settings → Database)
- Проверьте что скопировали Host из "Session mode" (порт 5432), не "Transaction mode"

**"Authentication error" от Anthropic?**
- Ключ должен быть в header `x-api-key`, НЕ `Authorization: Bearer`
- Проверьте что у вас есть кредит на Anthropic balance

**Webhook возвращает 404?**
- Workflow должен быть **Active** (зелёный переключатель)
- URL должен быть Production, не Test

---

**Следующий шаг:** [03 · Подключение Dashboard →](03-connect-dashboard.md)
