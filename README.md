# coordit

coordit is an AI-ready fashion fit recommendation MVP focused on reducing online shopping size and fit failures. It is not a TPO styling app. The core product compares a user's trusted reference clothing measurements with an online product's size chart, then recommends the closest size.

## Core Concept

1. A user registers clothing they already own.
2. The user enters real garment measurements for that item.
3. The user marks a well-fitting item as reference clothing.
4. The user registers an external shopping product and size chart.
5. The Fit Score Engine compares measurements by category and fit type.
6. coordit stores the fit analysis, recommendation log, and later user feedback.

## Tech Stack

- Frontend: Next.js, React, TypeScript, Tailwind CSS, fetch
- Backend: Node.js, Express, TypeScript, REST API
- Database: Supabase PostgreSQL
- Auth: JWT-ready Express middleware plus Supabase Auth-compatible user schema

## Folder Structure

```text
coordit-dev/
  coordit/       # iOS app, Xcode project, share extension, and UI tests
  android/       # Android app and Gradle project
  frontend/      # Next.js web app and public assets
  backend/       # Express API and tests
  supabase/      # Database schema, migrations, and RLS
  config/        # Shared development settings, including SimSlim
  tools/         # Standalone development playgrounds
  docs/          # Product, API, architecture, and deployment documentation
```

Start with the [documentation index](docs/README.md), [Android guide](android/README.md),
[backend guide](backend/README.md), or [web guide](frontend/README.md).
For iOS, open `coordit/coordit.xcodeproj`; [DESIGN.md](DESIGN.md) describes its design system.
The historical Fit Score playground lives in [tools/](tools/README.md).
The web logo is kept at [frontend/public/logo.png](frontend/public/logo.png).

Local agent records (`.omo/`), separate worktrees (`.worktrees/`), dependencies,
and build outputs are not application source. Local videos and reports in
`deliverables/` are user artifacts and should be kept out of source commits.

## Run Locally

Run each command block from the repository root, in separate terminals.

```bash
cd backend
npm install
npm run dev
```

```bash
cd frontend
npm install
npm run dev
```

Backend runs on `http://localhost:4000`. Frontend runs on `http://localhost:3000`.

## Environment Variables

Copy `.env.example` into each app as needed:

```bash
cp .env.example backend/.env
cp .env.example frontend/.env.local
```

Fill Supabase URL and keys from your Supabase project settings.

## Apply Supabase Schema

Run the files in this order in the Supabase SQL editor:

1. `supabase/schema.sql`
2. `supabase/indexes.sql`
3. `supabase/rls.sql`
4. `supabase/seed.sql` for optional demo data

## MVP Priorities

1. Auth and user profile flow
2. Wardrobe item creation
3. Clothing measurement entry
4. Reference clothing management
5. External product and size chart entry
6. Fit recommendation API
7. Result history and feedback
8. UX polishing and validation

## Fit Score Engine

The MVP engine is rule-based. It compares only available numeric measurements, normalizes weighted distance by the total usable weight, converts distance into a 0-100 fit score, applies fit-type penalties, then returns the highest scoring external product size.

## Future Expansion

- OCR extraction from product size chart images
- Brand-specific measurement normalization
- User feedback learning loop
- RLS hardening and audit logs
- Browser extension or product URL parser
- ML-assisted fit prediction after enough feedback data

