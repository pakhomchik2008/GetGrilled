# GetGrilled v2 — технический план

Заменяет фазы 1-3 из исходного промпта. Собрано по итогам grill-me
(см. историю чата) — каждое решение там объяснено, здесь — что оно
значит технически.

---

## 1. Структура сессии

**Было**: 1 session = 1 задача = 1 фидбэк.
**Стало**: 1 session = 3 раунда (Intro → Technical → Behavioral), каждый
со своим фидбэком.

### Экраны (порядок флоу)

1. **Setup** — форма перед стартом: мод (Test/Competition), роль
   (текст), уровень (Junior/Mid/Senior), заметка "на что налечь"
   (опционально). Заполняется КАЖДУЮ сессию заново, никуда не
   сохраняется в профиль.
2. **Question** — полноэкранный "момент входа в звонок": крупный
   портрет интервьюера, облако с текущим вопросом, кнопка "I'm ready
   to answer".
3. **Round** ("call-stage") — постоянный экран раунда: портрет
   интервьюера в карточке-сцене + мини-окно камеры юзера (PiP, как в
   Zoom) + облако с репликой + твой ответ + чипы-развилки + редактор
   кода (только Technical-раунд) + voice-ввод (mic/текст).
4. **Self-eval** — только Test mode, между концом раунда и AI-фидбэком:
   быстрая самооценка (Rough/OK/Strong).
5. **Summary** — по итогам всех 3 раундов: карточка на раунд (твоя
   оценка vs AI-оценка в Test mode, просто AI-оценка в Competition),
   общий вывод.

Референс всех экранов — опубликованный Artifact-превью (веб-макет, не
код), ссылка в истории чата.

### Данные (Supabase)

Новые таблицы:

```sql
create table session_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references interview_sessions(id) on delete cascade,
  round_type text not null check (round_type in ('intro','technical','behavioral')),
  round_order int not null,
  transcript jsonb not null default '[]'::jsonb,
  self_eval text check (self_eval in ('rough','ok','strong')),
  feedback jsonb, -- {score_label, notes}
  status text not null default 'pending' check (status in ('pending','in_progress','completed'))
);
```

`interview_sessions` — добавить колонки:
- `mode text check (mode in ('test','competition'))`
- `plan_stage_id uuid references plan_stages(id)` (nullable — null = ad-hoc practice)
- убрать/перестать писать `question_text`, `transcript` напрямую в
  сессию — теперь это живёт в `session_rounds`. **Миграция ломающая**,
  старые сессии из Фазы 1-2 станут нечитаемы как раунды — решить, что
  с ними делать (оставить как legacy read-only записи в истории, или
  мигрировать в 1-round session_rounds).

### Бэкенд (Vercel)

Новые эндпоинты, заменяют `/api/interview/{start,message,finish}`:
- `POST /api/round/start` — {sessionId, roundType} → стримит первый
  вопрос раунда, статус pending→in_progress
- `POST /api/round/message` — {sessionId, roundId, content} → стрим
  ответа интервьюера
- `POST /api/round/finish` — {sessionId, roundId, selfEval?} → forced
  tool-call, фидбэк раунда, статус completed
- `POST /api/session/finish` — {sessionId} → агрегирует 3 фидбэка
  раундов в overall summary, финализирует сессию

Три системных промпта (intro/technical/behavioral), параметризованные
`{role, level, focusNotes}` из Setup-формы. Technical-промпт — это
текущий (промпт Two Sum и т.д.), плюс инъекция роли/уровня в тон.

---

## 2. Test / Competition режимы

- **Test** (free, 3/нед): после каждого раунда — self-eval экран,
  потом AI-фидбэк
- **Competition** (free, 2/нед; paid — безлимит на оба): без
  self-eval, сразу фидбэк

Лимиты — бэкенд-проверка перед `/round/start` первого раунда сессии:
считаем `interview_sessions` за скользящие 7 дней по `mode` для юзера,
сравниваем с лимитом. Тот же принцип, что в приостановленной Фазе 3.

---

## 3. Голос (STT/TTS)

**On-device**, не через бэкенд — транскрибированный текст идёт в
`/api/round/message` тем же путём, что напечатанный.

- STT: `Speech` framework, `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest`
- TTS: `AVSpeechSynthesizer` + `AVSpeechUtterance`
- UI: push-to-talk микрофон (зажал — пишет, отпустил — транскрибирует
  и отправляет), TTS автопроигрывает ответ интервьюера, иконка
  🔊 — replay/mute

**Обязательно** (без этого — краш или App Store reject):
- `Info.plist`: `NSMicrophoneUsageDescription`,
  `NSSpeechRecognitionUsageDescription` — конкретные, не generic
  строки ("Used to transcribe your spoken answers during mock
  interviews")
- Explicit permission request flow (`SFSpeechRecognizer.requestAuthorization`,
  `AVAudioSession.requestRecordPermission`) до первого использования
  микрофона, с понятным UI-состоянием "отказано" (голос недоступен,
  но текст работает)
- `AVAudioSession` category `.playAndRecord` с правильными options
  (иначе конфликт с TTS-воспроизведением или беззвучным переключателем
  устройства)

---

## 4. Аватар

Статичная иллюстрация (SVG, см. превью), НЕ фото реального человека
(риск — использование чужого лица без согласия для вымышленного
персонажа), НЕ анимация. Показывается на Question и Round экранах.

**Обязательно**:
- SVG как Asset (или инлайн в SwiftUI через `Shape`/`Image` — решить
  при имплементации) — арт-ассет уже есть черновиком в веб-превью,
  нужно перенести
- Paid-версия (анимированный видео-аватар) — не в этой волне, See §8

---

## 5. Камера (зеркало)

Только локальный preview юзеру, **никогда никуда не отправляется и не
анализируется**. PiP-окно поверх портрета интервьюера, toggle on/off.

**Обязательно**:
- `Info.plist`: `NSCameraUsageDescription` — конкретная строка,
  явно объясняющая что это self-view, не отправляется ("Shows your
  own camera feed to you during practice — never recorded or sent
  anywhere")
- `AVCaptureSession` + `AVCaptureVideoPreviewLayer`, локальный layer
  без `AVCaptureVideoDataOutput`/записи — архитектурно исключить путь
  для кадров уйти на бэкенд (это не просто "не вызывать", а не
  реализовывать сам output path вообще)
- Paid-версия (реальный AI-анализ видео) — не в этой волне, см. §8

---

## 6. Кнопки-развилки (чипы)

"Не уверен" (наводка от AI, не спойлер) · "Повторить вопрос" ·
"Пропустить раунд"

**Требует**: расширить `/api/round/message` — принимать `action`
поле (`hint` | `repeat` | `skip`) вместо/вместе с `content`; в
системном промпте — инструкции как реагировать на каждый action;
skip → раунд помечается `status: skipped`, влияет на итоговый summary
(явно указывается что раунд пропущен).

---

## 7. Prep Plans

- **Plans** (список) — карточки с % ring, "+ New plan"
- **Create plan** — форма: роль, уровень, компания (опционально,
  ТОЛЬКО контекст тона — см. guardrail ниже), заметки
- **Plan detail** — % ring крупно, чек-лист этапов (done/pending),
  "Continue plan" → запускает Test-mode сессию, привязанную к
  следующему pending-этапу

### Данные

```sql
create table prep_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  role_title text not null,
  seniority text not null check (seniority in ('junior','mid','senior')),
  company_context text, -- контекст тона, НЕ источник вопросов
  focus_notes text,
  created_at timestamptz not null default now()
);

create table plan_stages (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references prep_plans(id) on delete cascade,
  stage_order int not null,
  title text not null,
  focus_description text not null,
  status text not null default 'pending' check (status in ('pending','completed')),
  session_id uuid references interview_sessions(id)
);
```

`POST /api/plans/generate` — {roleTitle, seniority, companyContext?,
focusNotes?} → AI генерит 5-8 этапов (structured output, tool
call), пишет в `plan_stages`.

**Обязательный guardrail** (юридический риск, уже согласовано):
системный промпт для `/plans/generate` и для раундов, запущенных из
плана, должен ЯВНО запрещать модели заявлять "это реальные вопросы
компании X". Компания — только контекст домена/тона. Формулировка в
промпте должна быть прямой, не подразумеваемой.

---

## 8. Монетизация (было Фаза 3, актуализировано)

- **Free**: Test 3/нед + Competition 2/нед, статичный аватар,
  on-device голос, камера-зеркало
- **Paid**: безлимит на оба мода, дальше (отдельная волна, не сейчас):
  анимированный видео-аватар, реальный AI-анализ видео, premium
  voice (API TTS/STT вместо on-device)

RevenueCat: аккаунт есть, продукты/entitlement — НЕ настроены (нужны
твои шаги в App Store Connect + RevenueCat дэшборде, дам отдельно).
Webhook-эндпоинт `/api/revenuecat/webhook` обновляет
`users.subscription_status` — писать можно уже сейчас, тестировать
только после настройки продуктов.

---

## 9. Design System v2 — обязательные технические требования

Это то самое "что обязательно быть" — без этого дизайн-система не
воспроизведётся в SwiftUI как задумано:

1. **Шрифты не системные.** Onest и IBM Plex Mono — НЕ встроены в iOS.
   Нужно:
   - Скачать `.ttf`/`.otf` файлы (Google Fonts)
   - Добавить в Xcode target как Bundle Resources
   - Зарегистрировать через `Info.plist` → `UIAppFonts` (массив имён
     файлов)
   - Без этого шага шрифт молча откатится на системный San Francisco,
     дизайн "поплывёт"

2. **OKLCH не поддерживается SwiftUI напрямую.** `Color` не парсит
   `oklch()`-строки. Нужна таблица конвертации OKLCH → sRGB
   hex/RGB для каждого токена ДО кодирования (посчитать один раз,
   захардкодить как `Color(hex:)` или `Color(red:green:blue:)`).
   Токены к конвертации: bg, surface, ink, ink-soft, accent,
   accent-strong, success, warn, danger (+ dark-вариант каждого).

3. **Тёмная тема — обязательна**, не опциональна. Design System v2
   задумана light-first, но SwiftUI `@Environment(\.colorScheme)`
   должен переключать оба набора токенов (см. dark-палитру уже
   посчитанную в веб-превью как референс).

4. **Permissions strings** (Info.plist, все три обязательны для
   голоса/камеры, без них приложение крашится при первом запросе
   разрешения или отклоняется в App Store Review):
   - `NSMicrophoneUsageDescription`
   - `NSSpeechRecognitionUsageDescription`
   - `NSCameraUsageDescription`

5. **Sign in with Apple entitlement** — уже добавлен в Фазе 2
   (`GetGrilled.entitlements`), просто отмечаю что он остаётся
   нужен.

---

## 10. Порядок реализации

**A → B → C → E → D → F**

- **A** — данные/бэкенд: новые таблицы, промпты, эндпоинты раундов
- **B** — iOS: раундовый флоу (Setup→Question→Round→Self-eval→Summary),
  без голоса/камеры/аватара пока — текст+редактор, как сейчас, но на
  новой структуре
- **C** — voice (STT/TTS on-device)
- **E** — Prep Plans (UI + `/plans/generate`)
- **D** — аватар (SVG-портрет) + камера-зеркало (косметика, в конце
  осознанно — ничего на них не завязано функционально)
- **F** — монетизация (лимиты по модам + RevenueCat webhook)

Каждый кусок — билд + живой прогон в симуляторе перед следующим,
как раньше.
