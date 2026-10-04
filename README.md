# GetGrilled

AI-powered technical interview trainer (iOS, MVP).

## What it is

Practice technical interviews with an AI interviewer that asks follow-up questions, grades your answers against a rubric, and tracks progress across sessions.

## Repo layout

- `ios/` — SwiftUI app. Generated from `ios/project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen); `.xcodeproj` is not committed — generate it locally with `cd ios && xcodegen generate`, then open `GetGrilled.xcodeproj`.
- `vercel/` — serverless API layer (TypeScript). All LLM traffic and Supabase writes go through here, never directly from the client.
- `supabase/migrations/` — database schema as code (SQL).
- `docs/` — design spec, interviewer system-prompt draft, and the design-system PDF.

## Running locally

### iOS
```bash
cd ios
xcodegen generate
open GetGrilled.xcodeproj
```

### Vercel API
```bash
cd vercel
npm install
cp .env.example .env.local   # fill in real keys, never commit this file
npm run dev
```

### Supabase
Apply migrations in `supabase/migrations/` via the Supabase CLI (`supabase db push`) or paste them into the project's SQL editor.

## Secrets

The LLM API key and the Supabase service-role key live only in Vercel environment variables (prod) and `.env.local` (dev, gitignored). Never committed, never reach the client.
