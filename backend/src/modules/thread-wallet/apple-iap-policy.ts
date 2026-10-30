import { z } from "zod";
import { createHttpError } from "../../shared/utils/http-error";
import {
  appleIapThreadProductIDs,
  type AppleIapThreadProductID
} from "./apple-iap-products";

export type AppleIapEnvironment = "Sandbox" | "Production";

export type AppleIapVerifiedTransaction = {
  readonly transactionId: string;
  readonly originalTransactionId: string;
  readonly productId: AppleIapThreadProductID;
  readonly appAccountToken: string;
  readonly purchasedAt: string;
  readonly environment: AppleIapEnvironment;
};

export type AppleNotificationEnvelope = {
  readonly notificationUUID: string;
  readonly notificationType: string;
  readonly subtype: string | null;
  readonly environment: AppleIapEnvironment;
  readonly signedTransaction: string | null;
  readonly reconcilesPurchase: boolean;
  readonly revokesPurchase: boolean;
};

export type AppleIapVerifiedNotification =
  | {
      readonly kind: "revoke";
      readonly notificationUUID: string;
      readonly notificationType: "REFUND" | "REVOKE";
      readonly subtype: string | null;
      readonly environment: AppleIapEnvironment;
      readonly transaction: AppleIapVerifiedTransaction;
      readonly revokedAt: string;
    }
  | {
      readonly kind: "record";
      readonly notificationUUID: string;
      readonly notificationType: string;
      readonly subtype: string | null;
      readonly environment: AppleIapEnvironment;
    }
  | {
      readonly kind: "reconcile";
      readonly notificationUUID: string;
      readonly notificationType: "ONE_TIME_CHARGE";
      readonly subtype: string | null;
      readonly environment: AppleIapEnvironment;
      readonly transaction: AppleIapVerifiedTransaction;
    };

export type AppleVerifierConfiguration = {
  readonly appAppleId: number;
  readonly bundleId: string;
};

const environmentSchema = z.enum(["Sandbox", "Production"]);
const productIdSchema = z.enum([
  appleIapThreadProductIDs.pack5,
  appleIapThreadProductIDs.pack10,
  appleIapThreadProductIDs.pack20
]);
const transactionClaimsSchema = z.object({
  transactionId: z.string().trim().min(1),
  originalTransactionId: z.string().trim().min(1),
  bundleId: z.string().trim().min(1),
  productId: productIdSchema,
  appAccountToken: z.string().uuid(),
  purchaseDate: z.number().int().positive().max(8_640_000_000_000_000),
  environment: environmentSchema,
  quantity: z.literal(1),
  revocationDate: z.never().optional(),
  revocationReason: z.never().optional(),
  type: z.literal("Consumable")
});
const notificationClaimsSchema = z.object({
  notificationType: z.string().trim().min(1),
  subtype: z.string().trim().min(1).optional(),
  notificationUUID: z.string().uuid(),
  version: z.literal("2.0"),
  data: z.object({
    environment: environmentSchema,
    appAppleId: z.number().int().positive().optional(),
    bundleId: z.string().trim().min(1),
    signedTransactionInfo: z.string().trim().min(1).optional()
  })
});

const revokedTransactionClaimsSchema = transactionClaimsSchema.extend({
  revocationDate: z.number().int().positive().max(8_640_000_000_000_000),
  revocationReason: z.number().int().nonnegative().optional()
});

export const parseAppleRevokedTransactionClaims = (
  payload: unknown,
  configuration: AppleVerifierConfiguration
): { readonly transaction: AppleIapVerifiedTransaction; readonly revokedAt: string } => {
  const parsed = revokedTransactionClaimsSchema.safeParse(payload);
  if (!parsed.success) return invalidTransaction();
  const { revocationDate, revocationReason: _revocationReason, ...claims } = parsed.data;
  return {
    transaction: parseAppleTransactionClaims(claims, configuration),
    revokedAt: new Date(revocationDate).toISOString()
  };
};

const invalidTransaction = (): never => {
  throw createHttpError(400, "Apple 구매 거래 정보를 확인할 수 없어요.");
};

export const parseAppleTransactionClaims = (
  payload: unknown,
  configuration: AppleVerifierConfiguration
): AppleIapVerifiedTransaction => {
  const parsed = transactionClaimsSchema.safeParse(payload);
  if (!parsed.success || parsed.data.bundleId !== configuration.bundleId) {
    return invalidTransaction();
  }
  return {
    transactionId: parsed.data.transactionId,
    originalTransactionId: parsed.data.originalTransactionId,
    productId: parsed.data.productId,
    appAccountToken: parsed.data.appAccountToken.toLowerCase(),
    purchasedAt: new Date(parsed.data.purchaseDate).toISOString(),
    environment: parsed.data.environment
  };
};

export const parseAppleNotificationClaims = (
  payload: unknown,
  configuration: AppleVerifierConfiguration
): AppleNotificationEnvelope => {
  const parsed = notificationClaimsSchema.safeParse(payload);
  if (!parsed.success || parsed.data.data.bundleId !== configuration.bundleId) {
    throw createHttpError(400, "Apple 서버 알림 정보를 확인할 수 없어요.");
  }
  if (
    parsed.data.data.environment === "Production"
    && parsed.data.data.appAppleId !== configuration.appAppleId
  ) {
    throw createHttpError(400, "Apple 서버 알림의 앱 정보를 확인할 수 없어요.");
  }
  const signedTransaction = parsed.data.data.signedTransactionInfo ?? null;
  const reconcilesPurchase = parsed.data.notificationType === "ONE_TIME_CHARGE";
  const revokesPurchase = parsed.data.notificationType === "REFUND" || parsed.data.notificationType === "REVOKE";
  if ((reconcilesPurchase || revokesPurchase) && signedTransaction === null) {
    throw createHttpError(400, "Apple 구매 거래가 없는 서버 알림이에요.");
  }
  return {
    notificationUUID: parsed.data.notificationUUID.toLowerCase(),
    notificationType: parsed.data.notificationType,
    subtype: parsed.data.subtype ?? null,
    environment: parsed.data.data.environment,
    signedTransaction,
    reconcilesPurchase,
    revokesPurchase
  };
};
