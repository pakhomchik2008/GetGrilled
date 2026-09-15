# GetGrilled

AI-тренажёр технических собеседований (iOS, MVP).

## Структура репо

- `ios/` — SwiftUI-приложение. Проект сгенерирован из `ios/project.yml`
  через [xcodegen](https://github.com/yonaskolb/XcodeGen); `.xcodeproj` не
  коммитится, генерируй локально: `cd ios && xcodegen generate`, затем
  открой `GetGrilled.xcodeproj`.
- `vercel/` — serverless API-слой (TypeScript). Весь LLM-трафик и запись в
  Supabase идут отсюда, никогда напрямую с клиента.
- `supabase/migrations/` — схема БД как код (SQL).
- `docs/` — черновики (системный промпт интервьюера и т.д.).

## Локальный запуск

### iOS
```
cd ios
xcodegen generate
open GetGrilled.xcodeproj
```

### Vercel API
```
cd vercel
npm install
cp .env.example .env.local   # заполнить реальными ключами, не коммитить
npm run dev
```

### Supabase
Миграции в `supabase/migrations/` — применить через Supabase CLI
(`supabase db push`) или вставить вручную в SQL editor проекта.

## Секреты

LLM API key и Supabase service role key живут только в переменных
окружения Vercel (prod) и `.env.local` (dev, в `.gitignore`). Никогда не
коммитятся, никогда не попадают в клиент.
