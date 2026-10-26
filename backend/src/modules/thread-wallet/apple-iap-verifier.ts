import { readFile } from "node:fs/promises";
import {
  Environment,
  SignedDataVerifier,
  VerificationException
} from "@apple/app-store-server-library";
import { env } from "../../config/env";
import { createHttpError } from "../../shared/utils/http-error";
import {
  parseAppleNotificationClaims,
  parseAppleRevokedTransactionClaims,
  parseAppleTransactionClaims,
  type AppleIapEnvironment,
  type AppleIapVerifiedNotification,
  type AppleIapVerifiedTransaction,
  type AppleVerifierConfiguration
} from "./apple-iap-policy";

export type AppleSignedDataDecoder = {
  readonly verifyAndDecodeNotification: (signedPayload: string) => Promise<unknown>;
  readonly verifyAndDecodeTransaction: (signedTransaction: string) => Promise<unknown>;
};

type AppleEnvironmentDecoders = {
  readonly production: AppleSignedDataDecoder;
  readonly sandbox: AppleSignedDataDecoder;
};

type AppleIapVerifierDependencies = {
  readonly allowSandbox?: boolean;
  readonly configuration: AppleVerifierConfiguration;
  readonly decoders: AppleEnvironmentDecoders;
};

export type AppleIapVerifier = {
  readonly verifyNotification: (signedPayload: string) => Promise<AppleIapVerifiedNotification>;
  readonly verifyTransaction: (signedTransaction: string) => Promise<AppleIapVerifiedTransaction>;
};

type DecodedAppleData = {
  readonly decoder: AppleSignedDataDecoder;
  readonly environment: AppleIapEnvironment;
  readonly payload: unknown;
};

const verificationFailure = (): never => {
  throw createHttpError(400, "Apple 서명 데이터를 검증할 수 없어요.");
};

const decodeWithAppleSignature = async (
  decoders: AppleEnvironmentDecoders,
  operation: (decoder: AppleSignedDataDecoder) => Promise<unknown>,
  allowSandbox: boolean
): Promise<DecodedAppleData> => {
  try {
    return {
      decoder: decoders.production,
      environment: "Production",
      payload: await operation(decoders.production)
    };
  } catch (error) {
    if (!(error instanceof VerificationException)) throw error;
  }

  if (!allowSandbox) return verificationFailure();

  try {
    return {
      decoder: decoders.sandbox,
      environment: "Sandbox",
      payload: await operation(decoders.sandbox)
    };
  } catch (error) {
    if (error instanceof VerificationException) return verificationFailure();
    throw error;
  }
};

const decodeNestedTransaction = async (
  decoder: AppleSignedDataDecoder,
  signedTransaction: string
): Promise<unknown> => {
  try {
    return await decoder.verifyAndDecodeTransaction(signedTransaction);
  } catch (error) {
    if (error instanceof VerificationException) return verificationFailure();
    throw error;
  }
};

export const createAppleIapVerifier = (
  dependencies: AppleIapVerifierDependencies
): AppleIapVerifier => {
  const verifyTransaction = async (
    signedTransaction: string
  ): Promise<AppleIapVerifiedTransaction> => {
    const decoded = await decodeWithAppleSignature(
      dependencies.decoders,
      (decoder) => decoder.verifyAndDecodeTransaction(signedTransaction),
      dependencies.allowSandbox === true
    );
    const transaction = parseAppleTransactionClaims(
      decoded.payload,
      dependencies.configuration
    );
    if (transaction.environment !== decoded.environment) return verificationFailure();
    return transaction;
  };

  return {
    verifyTransaction,
    verifyNotification: async (
      signedPayload: string
    ): Promise<AppleIapVerifiedNotification> => {
      const decoded = await decodeWithAppleSignature(
        dependencies.decoders,
        (decoder) => decoder.verifyAndDecodeNotification(signedPayload),
        dependencies.allowSandbox === true
      );
      const envelope = parseAppleNotificationClaims(
        decoded.payload,
        dependencies.configuration
      );
      if (envelope.environment !== decoded.environment) return verificationFailure();

      if (envelope.signedTransaction !== null) {
        const nestedPayload = await decodeNestedTransaction(decoded.decoder, envelope.signedTransaction);
        if (envelope.revokesPurchase) {
          const revoked = parseAppleRevokedTransactionClaims(nestedPayload, dependencies.configuration);
          if (revoked.transaction.environment !== envelope.environment) return verificationFailure();
          if (envelope.notificationType !== "REFUND" && envelope.notificationType !== "REVOKE") return verificationFailure();
          return {
            kind: "revoke", notificationUUID: envelope.notificationUUID,
            notificationType: envelope.notificationType, subtype: envelope.subtype,
            environment: envelope.environment, ...revoked
          };
        }
        const transaction = parseAppleTransactionClaims(
          nestedPayload,
          dependencies.configuration
        );
        if (transaction.environment !== envelope.environment) return verificationFailure();
        if (envelope.reconcilesPurchase) {
          return {
            kind: "reconcile",
            notificationUUID: envelope.notificationUUID,
            notificationType: "ONE_TIME_CHARGE",
            subtype: envelope.subtype,
            environment: envelope.environment,
            transaction
          };
        }
      }

      return {
        kind: "record",
        notificationUUID: envelope.notificationUUID,
        notificationType: envelope.notificationType,
        subtype: envelope.subtype,
        environment: envelope.environment
      };
    }
  };
};

const createProductionAppleVerifier = async (): Promise<AppleIapVerifier> => {
  if (!env.appleIapAppAppleId || env.appleIapRootCertificatePaths.length === 0) {
    throw createHttpError(503, "Apple 인앱결제 검증 설정이 아직 완료되지 않았어요.");
  }
  const rootCertificates = await Promise.all(
    env.appleIapRootCertificatePaths.map((path) => readFile(path))
  );
  return createAppleIapVerifier({
    allowSandbox: (process.env.NODE_ENV === "development" || process.env.NODE_ENV === "test")
      && process.env.APPLE_IAP_ALLOW_SANDBOX === "true",
    configuration: {
      appAppleId: env.appleIapAppAppleId,
      bundleId: env.appleIapBundleId
    },
    decoders: {
      production: new SignedDataVerifier(
        rootCertificates,
        true,
        Environment.PRODUCTION,
        env.appleIapBundleId,
        env.appleIapAppAppleId
      ),
      sandbox: new SignedDataVerifier(
        rootCertificates,
        true,
        Environment.SANDBOX,
        env.appleIapBundleId
      )
    }
  });
};

let appleIapVerifier: Promise<AppleIapVerifier> | null = null;

const activeAppleIapVerifier = (): Promise<AppleIapVerifier> => {
  appleIapVerifier ??= createProductionAppleVerifier();
  return appleIapVerifier;
};

export const verifyAppleTransaction = async (
  signedTransaction: string
): Promise<AppleIapVerifiedTransaction> => {
  return (await activeAppleIapVerifier()).verifyTransaction(signedTransaction);
};

export const verifyAppleNotification = async (
  signedPayload: string
): Promise<AppleIapVerifiedNotification> => {
  return (await activeAppleIapVerifier()).verifyNotification(signedPayload);
};
