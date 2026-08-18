# Agent development policy

Apply `$docs-first-game-dev` to every task that changes code, scenes, resources, configuration, game data, or production content.

Before implementation:

1. Read `docs/index.md` and the relevant canonical documents.
2. Create or update `docs/changes/CHG-YYYYMMDD-short-slug.md`.
3. Record goal, scope, non-goals, acceptance checks, documentation impact, and likely files.
4. Update any canonical document whose product, design, world, technical, production, or QA truth will change.
5. Do not edit implementation files until these documentation steps are complete.

During implementation, pause and update the documents when new constraints or changed decisions appear.

Before declaring completion, reconcile documents with actual behavior, record verification evidence in the change record, and set its status to `done`. Preserve unrelated user changes and never mark undocumented code changes complete.
