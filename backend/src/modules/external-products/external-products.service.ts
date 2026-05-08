import { asOptionalRecord, asOptionalString, asRequiredString } from "../../shared/utils/request";
import {
  insertExternalProduct,
  patchExternalProduct,
  selectExternalProductById,
  selectExternalProducts,
  type ExternalProductDto
} from "./external-products.repository";

const toDto = (body: Record<string, unknown>): ExternalProductDto => ({
  product_name: asRequiredString(body.productName ?? body.product_name, "productName"),
  brand: asOptionalString(body.brand),
  mall_name: asOptionalString(body.mallName ?? body.mall_name),
  product_url: asOptionalString(body.productUrl ?? body.product_url),
  category: asRequiredString(body.category, "category") as ExternalProductDto["category"],
  fit_type: (asOptionalString(body.fitType ?? body.fit_type) ?? "regular") as ExternalProductDto["fit_type"],
  image_url: asOptionalString(body.imageUrl ?? body.image_url),
  raw_product_data: asOptionalRecord(body.rawProductData ?? body.raw_product_data)
});

export const createExternalProductForUser = (userId: string, body: Record<string, unknown>) =>
  insertExternalProduct(userId, toDto(body));

export const listExternalProductsForUser = (userId: string) => selectExternalProducts(userId);

export const getExternalProductForUser = (userId: string, id: string) => selectExternalProductById(userId, id);

export const updateExternalProductForUser = (userId: string, id: string, body: Record<string, unknown>) =>
  patchExternalProduct(userId, id, toDto(body));

export const mockExternalProductFromUrl = (url: string) => ({
  productName: "오버핏 후드티",
  brand: "무신사 스탠다드",
  mallName: new URL(url).hostname,
  productUrl: url,
  category: "hoodie",
  fitType: "relaxed",
  parsingStatus: "mocked",
  sizes: [
    { sizeLabel: "M", shoulderWidth: 54, chestWidth: 58, totalLength: 68, sleeveLength: 61 },
    { sizeLabel: "L", shoulderWidth: 56, chestWidth: 60, totalLength: 70, sleeveLength: 62 },
    { sizeLabel: "XL", shoulderWidth: 58, chestWidth: 63, totalLength: 72, sleeveLength: 63 }
  ]
});
