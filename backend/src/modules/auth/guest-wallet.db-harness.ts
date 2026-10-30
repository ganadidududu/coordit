import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { startDisposableReconciliationDatabase } from "../thread-wallet/monetization-schema-reconciliation.db-harness";

export const applyGuestMigration = async (
  database: Awaited<ReturnType<typeof startDisposableReconciliationDatabase>>,
  filename: string
): Promise<void> => {
  await database.client.query(await readFile(resolve(process.cwd(), "..", "supabase", "migrations", filename), "utf8"));
};

export const startGuestWalletDatabase = async () => {
  const database = await startDisposableReconciliationDatabase("fresh");
  try {
    await database.applyReconciliation();
    await database.client.query(`
      create schema auth;
      create table auth.users(id uuid primary key, is_anonymous boolean not null default true);
    `);
    await applyGuestMigration(database, "20260826_seed_new_user_thread_balance.sql");
    await applyGuestMigration(database, "20260902_add_guest_devicecheck_auth.sql");
    return database;
  } catch (error) {
    await database.stop();
    throw error;
  }
};
