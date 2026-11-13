# Architecture

Next.js App Router serves a local single-user application. React workspace components call JSON routes. Server domain functions validate world ownership, record membership, revisions and proposal transitions. Drizzle provides typed SQLite access; numbered SQL migrations maintain tables, indexes, and FTS5 search. Every world record uses UUIDs and ISO timestamps.

Modules: db/schema + migrations; workspace domain; security/local session; agents/provider adapter; client workspace/editor/connections/assistant. Documents and entities share records with explicit kind, category, aliases, tags, draft content and separate canonical snapshots. Record links attach pages to entities. Typed relationships connect entities. Events reference source records and use freeform date labels plus optional numeric ordering. Revisions preserve content and accepted snapshot history. Proposals store exact base version, before/after and evidence.

Storage: data/worldos.sqlite (gitignored). Export is versioned world-scoped JSON with records, revisions, links, relationships, events and proposals. No destructive delete in initial UI. PostgreSQL migration requires changing the driver/schema, SQL migrations and FTS implementation; the domain and UI contracts remain stable.
