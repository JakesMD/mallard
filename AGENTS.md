## Agent skills

### Issue tracker

Issues are tracked locally as markdown under `.scratch/` (gitignored, never GitHub Issues). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Grilling sessions

Ask all questions via the `AskUserQuestion` popup tool, never plain chat. See `docs/agents/grilling.md`.
