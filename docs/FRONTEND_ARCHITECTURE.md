# Frontend Architecture

coordit frontend is a Next.js App Router MVP connected to the Express API.

## State Flow

1. `AuthProvider` stores the Supabase access token in `localStorage`.
2. `apiClient` injects `Authorization` into every protected request.
3. Pages fetch the minimum data needed for their workflow.
4. Forms show loading and error states locally.

## Implemented Screens

- `/login`: signup, login, logout.
- `/wardrobe`: create clothing item and its measured size.
- `/reference`: mark wardrobe items as fit references with `preferenceScore`.
- `/external-products`: create external products and manual size rows.
- `/fit-result`: select multiple references, select an external product, run Fit Engine v1.1.

## UI Principle

The UI is intentionally focused on measured fit comparison. It does not recommend outfits, TPO, weather styling, or coordination.
