# Decisions

## 2026-11-12
- **Owner-protected:** AI output is never canon without explicit scoped creator approval. Private lore stays local unless the creator invokes the configured external provider.
- **Owner-protected:** No public deployment or paid validation calls this session.
- Builder choice: Next.js + Drizzle + SQLite, matching the requested defaults. SQLite makes setup local; SQL migrations and domain boundaries make a later PostgreSQL port tractable, not automatic.
- Builder choice: Markdown editor + rendered preview instead of a block editor. Portable serialization and reliable revision behavior take priority for the first slice.
- Builder choice: local-only single-user authentication boundary. Loopback binding, allowed Host/Origin, HttpOnly session cookie, and owner-scoped queries; not suitable for remote or multiuser hosting.
- Builder choice: saved draft content and accepted canon snapshots are separate. Editing canon never changes the accepted snapshot until review.
