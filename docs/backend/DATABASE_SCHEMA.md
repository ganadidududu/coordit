# Database Schema

문서 상태: 최신  
기준일: 2026-05-22  
기준 SQL: `supabase/schema.sql`, `supabase/indexes.sql`, `supabase/rls.sql`

coordit DB는 Supabase PostgreSQL을 사용합니다. SQL 원본은 `supabase/` 디렉터리에 있습니다.

## 적용 순서

신규 Supabase 프로젝트에는 다음 순서로 적용합니다.

1. `supabase/schema.sql`
2. `supabase/indexes.sql`
3. `supabase/rls.sql`
4. `supabase/seed.sql` 선택

## 테이블 요약

| 테이블 | 설명 |
| --- | --- |
| `users` | Supabase Auth user와 연결되는 public profile |
| `body_measurements` | 사용자 신체 치수 |
| `clothing_items` | 사용자가 보유한 의류 |
| `clothing_sizes` | 보유 의류의 실측값 |
| `reference_clothing` | 추천 기준으로 선택한 보유 의류 |
| `external_products` | 비교 대상 외부 상품 |
| `external_product_sizes` | 외부 상품 사이즈표 |
| `fit_analysis_results` | 추천 실행 결과 |
| `user_feedback` | 추천 후 실제 착용/구매 피드백 |
| `recommendation_logs` | 추천 노출/클릭/구매 로그 |

## 핵심 관계

```text
auth.users
  └─ public.users
      ├─ body_measurements
      ├─ clothing_items
      │   ├─ clothing_sizes
      │   └─ reference_clothing
      ├─ external_products
      │   └─ external_product_sizes
      ├─ fit_analysis_results
      ├─ user_feedback
      └─ recommendation_logs
```

## 주요 테이블 상세

### `users`

- `id`: `auth.users(id)` 참조
- `email`: unique
- `display_name`
- `gender`
- `birth_year`
- `created_at`, `updated_at`

회원가입/로그인 시 `auth.service.ts`에서 프로필을 upsert합니다.

### `clothing_items`

보유 의류의 기본 정보입니다.

- `user_id`
- `name`
- `brand`
- `category`
- `fit_type`
- `size_label`
- `notes`
- `image_url`
- `raw_product_data`

### `clothing_sizes`

보유 의류의 실측값입니다. 추천 엔진의 기준 측정값입니다.

- `user_id`
- `clothing_item_id`
- `size_label`
- `total_length`
- `shoulder_width`
- `chest_width`
- `sleeve_length`
- `waist_width`
- `hip_width`
- `rise`
- `outseam`
- `raw_measurements`

### `reference_clothing`

사용자가 추천 기준으로 선택한 보유 의류입니다.

- `user_id`
- `clothing_item_id`
- `nickname`
- `category`
- `fit_type`
- `preference_score`
- `is_active`
- `notes`

제약:

- `unique (user_id, clothing_item_id)`
- `preference_score between 1 and 100`

추천 API는 `is_active = true`인 기준 의류만 사용합니다.

### `external_products`

쇼핑몰 상품 등 비교 대상입니다.

- `user_id`
- `product_name`
- `brand`
- `mall_name`
- `product_url`
- `category`
- `fit_type`
- `image_url`
- `raw_product_data`

### `external_product_sizes`

외부 상품의 사이즈표 row입니다.

- `user_id`
- `external_product_id`
- `size_label`
- `total_length`
- `shoulder_width`
- `chest_width`
- `sleeve_length`
- `waist_width`
- `hip_width`
- `rise`
- `outseam`
- `raw_size_data`
- `parsing_status`
- `measurement_source`
- `extracted_text`
- `extraction_confidence`

OCR/파서 확장을 위해 `raw_size_data`, `parsing_status`, `measurement_source`, `extracted_text`, `extraction_confidence` 컬럼이 준비되어 있습니다.

### `fit_analysis_results`

추천 실행 결과입니다.

- `user_id`
- `reference_clothing_id`
- `external_product_id`
- `recommended_external_product_size_id`
- `recommended_size_label`
- `fit_score`
- `fit_label`
- `fit_comment`
- `weighted_fit_distance`
- `algorithm_version`
- `recommendation_confidence`
- `result_details`

`result_details`에는 부위별 차이, 설명, 상태, 전체 사이즈 점수, 추천에 사용한 기준 의류 목록, 동적 가중치 메타데이터가 들어갑니다.

동적 가중치 메타데이터:

- `baseWeights`
- `dynamicWeights`
- `referenceVariance`
- `weightingStrategy`

현재 여러 기준 의류를 사용해도 `reference_clothing_id` 컬럼에는 첫 번째 기준 의류만 저장됩니다. 전체 목록은 `result_details.referenceClothingIds`에서 확인합니다.

### `user_feedback`

추천 결과에 대한 사용자의 실제 피드백입니다.

- `user_id`
- `fit_analysis_result_id`
- `purchased_size_label`
- `actual_fit_rating`
- `actual_fit_label`
- `comment`
- `raw_data`

### `recommendation_logs`

추천 이벤트 로그입니다.

- `user_id`
- `fit_analysis_result_id`
- `external_product_id`
- `recommended_size_label`
- `event_type`
- `clicked_at`
- `purchased_at`
- `algorithm_version`
- `raw_data`

`POST /fit/recommend` 성공 시 `event_type = "shown"` 로그가 생성됩니다.

## 지원 카테고리와 fit type

카테고리:

- `tshirt`
- `shirt`
- `sweatshirt`
- `hoodie`
- `knit`
- `jacket`
- `coat`
- `pants`
- `jeans`
- `shorts`
- `skirt`

Fit type:

- `slim`
- `regular`
- `relaxed`
- `oversized`

## 측정값 필드

현재 추천 엔진에서 사용하는 측정값은 다음입니다.

- `total_length`
- `shoulder_width`
- `chest_width`
- `sleeve_length`
- `waist_width`
- `hip_width`
- `rise`
- `outseam`

API 요청에서도 측정값은 snake_case를 기준으로 사용합니다.

## 인덱스

현재 인덱스는 `supabase/indexes.sql`에 있습니다.

- `idx_body_measurements_user_id`
- `idx_clothing_items_user_category`
- `idx_clothing_sizes_item_id`
- `idx_reference_clothing_user_active`
- `idx_reference_clothing_user_category`
- `idx_external_products_user_category`
- `idx_external_product_sizes_product_id`
- `idx_fit_results_user_created_at`
- `idx_feedback_user_id`
- `idx_recommendation_logs_user_created_at`

데이터가 늘어나면 `clothing_sizes(user_id, clothing_item_id)`, `external_product_sizes(user_id, external_product_id)` 복합 인덱스를 추가 검토할 수 있습니다.

## RLS

`supabase/rls.sql`은 모든 user-owned 테이블에 RLS를 활성화합니다. 기본 정책은 `auth.uid() = user_id`입니다. `users` 테이블만 `auth.uid() = id` 기준입니다.

단, 백엔드가 service role key를 사용하므로 API 코드에서 `user_id` 필터를 반드시 유지해야 합니다.

## Migration Notes

Fit Engine v1.2에서 하의 길이 측정 항목을 `inseam`에서 `outseam`으로 변경했습니다.

관련 migration:

- `supabase/migrations/20260522_rename_inseam_to_outseam.sql`

기존 `inseam` 데이터를 `outseam`으로 마이그레이션할지 여부는 실제 운영 데이터 존재 여부에 따라 결정해야 합니다.
