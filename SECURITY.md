# Security policy

## Supported versions

Only the latest release receives fixes. Synthesis is in early 0.0.x releases.

## Reporting a vulnerability

Please **do not open a public issue**. Report privately through GitHub's [private vulnerability reporting](https://github.com/desenyon/synthesis/security/advisories/new). Include the version, steps to reproduce, and what an attacker could achieve.

You should get an acknowledgement within a week. Once a fix is released the advisory will be published with credit, unless you prefer otherwise.

## What matters most

Synthesis holds private creative work locally. Reports are especially valuable for:

- anything that sends world content anywhere other than the creator's chosen assistant CLI, or sends it without a creator action;
- a way for imported files, lore text or assistant output to act as instructions, run code, or approve canon;
- a `.synthesis` world file that can read or alter another world or files outside the database;
- the embedded Canvas reaching the network or escaping its content security policy;
- assistant requests gaining tools, file access or the user's CLI configuration.

Synthesis never stores provider credentials; sign-in stays with Claude Code or Codex.
