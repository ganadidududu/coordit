# API Specification

Base URL: `http://localhost:4000`

Authenticated APIs require:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

Common errors:

- `400`: invalid request body or incompatible category
- `401`: missing or invalid token
- `404`: resource not found
- `500`: persistence or unexpected server error

## Auth

### POST /auth/signup

Creates a Supabase Auth user and public profile.

Request:

```json
{ "email": "user@example.com", "password": "password123", "displayName": "User" }
```

Response:

```json
{ "userId": "uuid", "email": "user@example.com" }
```

Logic: create auth user, insert `public.users`, return profile. Errors: duplicate email, weak password.

### POST /auth/login

Logs in and returns tokens.

Request:

```json
{ "email": "user@example.com", "password": "password123" }
```

Response:

```json
{ "accessToken": "jwt", "refreshToken": "token", "user": { "id": "uuid", "email": "user@example.com" } }
```

Logic: validate credentials through Supabase Auth. Errors: invalid credentials.

## User

### GET /users/me

Returns the current user's profile.

Response:

```json
{ "id": "uuid", "email": "user@example.com", "displayName": "User" }
```

Logic: select `users` by authenticated user ID. Errors: profile not found.

### PATCH /users/me

Updates the current user's profile.

Request:

```json
{ "displayName": "New Name", "gender": "female", "birthYear": 1995 }
```

Response:

```json
{ "id": "uuid", "displayName": "New Name", "updatedAt": "2026-05-07T00:00:00Z" }
```

Logic: update only allowed profile fields. Errors: invalid field.

## Body Measurement

### POST /body-measurements

Creates optional body measurement data.

Request:

```json
{ "heightCm": 172, "weightKg": 64, "shoulderWidth": 42, "rawData": {} }
```

Response:

```json
{ "id": "uuid", "heightCm": 172, "weightKg": 64 }
```

Logic: insert row with `user_id`. Errors: invalid numeric value.

### GET /body-measurements

Lists body measurements for current user.

Response:

```json
[{ "id": "uuid", "heightCm": 172, "createdAt": "2026-05-07T00:00:00Z" }]
```

Logic: select by `user_id`, newest first.

## Clothing Items

### POST /clothing-items

Creates a user-owned garment.

Request:

```json
{ "name": "Oxford Shirt", "brand": "Uniqlo", "category": "shirt", "fitType": "regular", "sizeLabel": "L" }
```

Response:

```json
{ "id": "uuid", "name": "Oxford Shirt", "category": "shirt" }
```

Logic: insert `clothing_items`. Errors: unsupported category.

### GET /clothing-items

Lists owned garments.

Response:

```json
[{ "id": "uuid", "name": "Oxford Shirt", "category": "shirt", "sizeLabel": "L" }]
```

Logic: select rows owned by user.

### GET /clothing-items/:id

Returns one owned garment.

Response:

```json
{ "id": "uuid", "name": "Oxford Shirt", "category": "shirt" }
```

Logic: select by `id` and `user_id`. Errors: not found.

### PATCH /clothing-items/:id

Updates an owned garment.

Request:

```json
{ "name": "Favorite Oxford Shirt", "fitType": "regular" }
```

Response:

```json
{ "id": "uuid", "name": "Favorite Oxford Shirt" }
```

Logic: update owned row. Errors: not found.

### DELETE /clothing-items/:id

Deletes an owned garment.

Response:

```json
{ "deleted": true }
```

Logic: delete by `id` and `user_id`.

## Clothing Sizes

### POST /clothing-items/:id/sizes

Creates actual measurements for an owned garment.

Request:

```json
{ "sizeLabel": "L", "shoulderWidth": 48, "chestWidth": 57, "totalLength": 73, "sleeveLength": 62 }
```

Response:

```json
{ "id": "uuid", "clothingItemId": "uuid", "sizeLabel": "L" }
```

Logic: verify garment ownership, insert `clothing_sizes`.

### GET /clothing-items/:id/sizes

Lists measurements for an owned garment.

Response:

```json
[{ "id": "uuid", "sizeLabel": "L", "chestWidth": 57 }]
```

Logic: verify ownership, select by clothing item.

### PATCH /clothing-sizes/:id

Updates owned garment measurements.

Request:

```json
{ "chestWidth": 58 }
```

Response:

```json
{ "id": "uuid", "chestWidth": 58 }
```

Logic: update owned size row.

### DELETE /clothing-sizes/:id

Deletes a measurement row.

Response:

```json
{ "deleted": true }
```

## Reference Clothing

### POST /reference-clothing

Marks a clothing item as reference clothing.

Request:

```json
{ "clothingItemId": "uuid", "nickname": "잘 맞는 셔츠", "category": "shirt", "fitType": "regular" }
```

Response:

```json
{ "id": "uuid", "isActive": true }
```

Logic: verify item ownership and at least one measurement row.

### GET /reference-clothing

Lists active and inactive references.

Response:

```json
[{ "id": "uuid", "nickname": "잘 맞는 셔츠", "isActive": true }]
```

### GET /reference-clothing/:id

Returns reference detail with linked clothing item and measurements.

Response:

```json
{ "id": "uuid", "category": "shirt", "measurements": { "chestWidth": 57 } }
```

### PATCH /reference-clothing/:id

Updates nickname, fit type, notes, or active state.

Request:

```json
{ "nickname": "최애 셔츠" }
```

Response:

```json
{ "id": "uuid", "nickname": "최애 셔츠" }
```

### PATCH /reference-clothing/:id/deactivate

Deactivates a reference.

Response:

```json
{ "id": "uuid", "isActive": false }
```

## External Products

### POST /external-products

Creates a shopping mall product.

Request:

```json
{ "productName": "Linen Shirt", "brand": "Brand", "mallName": "29CM", "productUrl": "https://example.com", "category": "shirt", "fitType": "regular" }
```

Response:

```json
{ "id": "uuid", "productName": "Linen Shirt" }
```

### GET /external-products

Lists registered external products.

Response:

```json
[{ "id": "uuid", "productName": "Linen Shirt", "category": "shirt" }]
```

### GET /external-products/:id

Returns product detail.

Response:

```json
{ "id": "uuid", "productName": "Linen Shirt", "rawProductData": {} }
```

### PATCH /external-products/:id

Updates product metadata.

Request:

```json
{ "mallName": "Musinsa" }
```

Response:

```json
{ "id": "uuid", "mallName": "Musinsa" }
```

## External Product Sizes

### POST /external-products/:id/sizes

Creates a size chart row for an external product.

Request:

```json
{ "sizeLabel": "L", "shoulderWidth": 49, "chestWidth": 58, "totalLength": 73.5, "sleeveLength": 63 }
```

Response:

```json
{ "id": "uuid", "sizeLabel": "L" }
```

### GET /external-products/:id/sizes

Lists all size chart rows.

Response:

```json
[{ "id": "uuid", "sizeLabel": "M" }, { "id": "uuid", "sizeLabel": "L" }]
```

### PATCH /external-product-sizes/:id

Updates one size chart row.

Request:

```json
{ "chestWidth": 59 }
```

Response:

```json
{ "id": "uuid", "chestWidth": 59 }
```

### DELETE /external-product-sizes/:id

Deletes one size chart row.

Response:

```json
{ "deleted": true }
```

## Fit Recommendation

### POST /fit/recommend

Runs the Fit Score Engine and persists result and recommendation log.

Request:

```json
{ "referenceClothingId": "uuid", "externalProductId": "uuid" }
```

Response:

```json
{
  "fitAnalysisResultId": "uuid",
  "recommendedSize": "L",
  "fitScore": 92.5,
  "fitLabel": "good_fit",
  "fitComment": "L 사이즈를 추천합니다. 기준 의류와 어깨, 가슴단면, 총장 차이가 작아 유사한 핏이 예상됩니다.",
  "diff": { "shoulder_width": 1, "chest_width": 1, "total_length": 0.5, "sleeve_length": 1 },
  "allSizeScores": [
    { "externalProductSizeId": "uuid", "sizeLabel": "M", "fitScore": 78, "fitLabel": "acceptable", "weightedFitDistance": 2.2 },
    { "externalProductSizeId": "uuid", "sizeLabel": "L", "fitScore": 92.5, "fitLabel": "good_fit", "weightedFitDistance": 0.75 }
  ],
  "algorithmVersion": "mvp_rule_v1"
}
```

Logic:

1. Verify authenticated user.
2. Validate `referenceClothingId` and `externalProductId`.
3. Load active reference clothing.
4. Load connected clothing item and clothing measurements.
5. Load external product and all size rows.
6. Check top-to-top or bottom-to-bottom category compatibility.
7. Run Fit Score Engine.
8. Insert `fit_analysis_results`.
9. Insert `recommendation_logs`.
10. Return best size and all scores.

Errors: no comparable measurements, incompatible category, missing size chart.

## Fit Analysis Results

### GET /fit-analysis-results

Lists saved fit analyses.

Response:

```json
[{ "id": "uuid", "recommendedSizeLabel": "L", "fitScore": 92.5 }]
```

### GET /fit-analysis-results/:id

Returns one saved result.

Response:

```json
{ "id": "uuid", "resultDetails": {}, "algorithmVersion": "mvp_rule_v1" }
```

## Feedback

### POST /fit-analysis-results/:id/feedback

Stores actual purchase or try-on feedback.

Request:

```json
{ "purchasedSizeLabel": "L", "actualFitRating": 5, "actualFitLabel": "good_fit", "comment": "잘 맞음" }
```

Response:

```json
{ "id": "uuid", "actualFitRating": 5 }
```

### GET /user-feedback

Lists current user's feedback.

Response:

```json
[{ "id": "uuid", "fitAnalysisResultId": "uuid", "actualFitRating": 5 }]
```

## Recommendation Logs

### GET /recommendation-logs

Lists recommendation exposure logs.

Response:

```json
[{ "id": "uuid", "eventType": "shown", "recommendedSizeLabel": "L" }]
```

### PATCH /recommendation-logs/:id/click

Marks a recommendation as clicked.

Response:

```json
{ "id": "uuid", "clickedAt": "2026-05-07T00:00:00Z" }
```

### PATCH /recommendation-logs/:id/purchase

Marks a recommendation as purchased.

Response:

```json
{ "id": "uuid", "purchasedAt": "2026-05-07T00:00:00Z" }
```

