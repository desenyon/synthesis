import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import * as schema from './schema';
export function openDatabase(path = process.env.DATABASE_PATH || './data/worldos.sqlite') {
  if (path !== ':memory:') mkdirSync(dirname(resolve(path)), { recursive: true });
  const sqlite = new Database(path);
  sqlite.pragma('journal_mode = WAL'); sqlite.pragma('foreign_keys = ON'); sqlite.pragma('busy_timeout = 5000');
  sqlite.exec('CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL)');
  const folder = resolve(process.cwd(), 'migrations');
  for (const name of readdirSync(folder).filter(n => n.endsWith('.sql')).sort()) {
    if (!sqlite.prepare('SELECT name FROM schema_migrations WHERE name=?').get(name)) {
      sqlite.transaction(() => { sqlite.exec(readFileSync(resolve(folder, name), 'utf8')); sqlite.prepare('INSERT INTO schema_migrations VALUES(?,?)').run(name, new Date().toISOString()); })();
    }
  }
  return { sqlite, db: drizzle(sqlite, { schema }) };
}
export type DB = ReturnType<typeof openDatabase>['db'];
const globalDb = globalThis as unknown as { worldosConnection?: ReturnType<typeof openDatabase> };
export function database() { return (globalDb.worldosConnection ??= openDatabase()).db; }
