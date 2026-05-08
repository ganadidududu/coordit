# API Flow

## MVP Lifecycle

1. `POST /auth/signup`
2. `POST /auth/login`
3. `POST /clothing-items`
4. `POST /clothing-items/:id/sizes`
5. `POST /reference-clothing`
6. `POST /external-products`
7. `POST /external-products/:id/sizes`
8. `POST /fit/recommend`
9. `POST /fit-analysis-results/:id/feedback`

## Fit Recommend Request

```json
{
  "referenceClothingIds": ["reference-id-1", "reference-id-2"],
  "externalProductId": "external-product-id"
}
```

## Fit Recommend Response

```json
{
  "recommendedSize": "L",
  "fitScore": 92,
  "fitLabel": "good_fit",
  "recommendationConfidence": "high",
  "diff": {
    "shoulder_width": 1,
    "chest_width": 1
  }
}
```

## OCR / URL Preparation

`external_product_sizes` now stores:

- `raw_size_data`
- `parsing_status`
- `measurement_source`
- `extracted_text`
- `extraction_confidence`

`POST /external-products/from-url` currently returns mock parsed data and is ready to be replaced by URL scraping or OCR parsing later.
