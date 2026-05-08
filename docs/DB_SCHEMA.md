# Database Schema

The SQL source of truth lives in `supabase/`.

## Tables

- `users`: public profile table connected to `auth.users`.
- `body_measurements`: optional body data for future personalization.
- `clothing_items`: all user-owned garments.
- `clothing_sizes`: measured dimensions for owned garments.
- `reference_clothing`: well-fitting garments selected as references.
- `external_products`: shopping mall products.
- `external_product_sizes`: measured size chart rows for external products.
- `fit_analysis_results`: persisted recommendation output.
- `user_feedback`: post-purchase or try-on feedback.
- `recommendation_logs`: shown, clicked, and purchased recommendation events.

## Measurement Fields

Both owned and external garments support:

- `total_length`
- `shoulder_width`
- `chest_width`
- `sleeve_length`
- `waist_width`
- `hip_width`
- `rise`
- `inseam`

JSONB fields such as `raw_data`, `raw_measurements`, `raw_product_data`, `raw_size_data`, and `result_details` are included for OCR, ML, and parser expansion.

