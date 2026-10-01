---
name: questburg
description: Work with a family in Questburg (questburg.com) through its API — see what the kids have today, check quests off, approve or decline what they checked off, list and add quests. Use when the user asks about the kids' quests, chores or habits in Questburg — "what do the kids have today", "approve everything they checked off", "add a quest for Theo", «что сегодня у детей», «засчитай всё, что отметили», «заведи задание», «сколько у Феди баллов» — or mentions Questburg or a qb_ key.
---

# Questburg

Questburg is a family app: grown-ups set up quests (chores, habits), kids check
them off, a grown-up approves, approval gives points. This skill drives it
through the API with one script: `scripts/qb.sh` (bash + curl, nothing else).

The key acts **as the grown-up who created it**: what you approve is recorded
as approved by them. Points are the kids' real currency — approve only what the
user asked you to approve.

## First run

1. Check the key: `scripts/qb.sh me`. If it prints the family, skip to "Usual order".
2. If it says `No key`, ask the user to create one at
   https://questburg.com/en/developers (step 1 on that page; also in the app:
   Family → Agents and API) and to save it themselves, so the key never goes
   through the chat:

   ```bash
   mkdir -p ~/.config/questburg && printf '%s' 'qb_PASTE_HERE' > ~/.config/questburg/key && chmod 600 ~/.config/questburg/key
   ```

   The script also accepts the key in `QUESTBURG_API_KEY`.
3. If it answers `unauthorized`, the key is wrong or revoked — the user creates
   a new one. Do not guess keys.

## Usual order

1. `scripts/qb.sh me` — member codes (`M-…`), who is a child, points, and
   whether the key is `read` or `write`. A `read` key cannot change anything:
   say so instead of trying.
2. `scripts/qb.sh today` — every quest of the day with its `id` and `state`.
3. Act on an `id` from step 2, then re-read `today` to confirm.

## Commands

| Command | What it does |
|---|---|
| `scripts/qb.sh me` | family, timezone, today's date, members with codes and points |
| `scripts/qb.sh today [--member M-XXXXXX] [--date YYYY-MM-DD]` | quests of a day; default is today, whole family |
| `scripts/qb.sh approvals` | what kids checked off and what waits for a grown-up |
| `scripts/qb.sh done <id>` | check a quest off |
| `scripts/qb.sh approve <id>` | approve: points are credited |
| `scripts/qb.sh reject <id>` | decline a check-off; the kid can redo it and check off again |
| `scripts/qb.sh approve-all` | approve everything in `approvals` |
| `scripts/qb.sh offers` | active quests with schedule, points, assignees |
| `scripts/qb.sh add-offer --title T --to kids` | add a quest (see below) |

Output is JSON on stdout. Exit code 0 — done; 1 — the API refused, the JSON
says why (`error.code`, `error.message`); 2 — the command was called wrong.

### States in `today`

| `state` | Meaning | What you can do |
|---|---|---|
| `todo` | not checked off | `done`, or `approve` straight away |
| `waiting_approval` | the kid checked it off, a grown-up hasn't answered | `approve` or `reject` |
| `done` | approved, points credited | nothing |
| `rejected` | declined | `done` again after it's redone |
| `missed` | the day closed without it | `approve` within 7 days counts it backdated |

`done` on a quest with `requiresApproval: true` gives `waiting_approval`, not
`done` — points come only after `approve`.

### Adding a quest

```bash
scripts/qb.sh add-offer --title "Take out the trash" --to kids --points 10 --weekdays 3
```

- `--to` — `kids` (every child) or member codes from `me`: `--to M-9F5A00,M-A4FE41`.
- `--weekdays` — `0`–`6`, `0` is Sunday, comma-separated; without it the quest is daily.
- `--points` — whole number, 0 to 10000; default 0.
- `--description` — how exactly to do it; optional.
- `--no-approval` — the kid's check-off counts at once, without a grown-up.

## Things that cost a retry

- **Dates are the family's**, not yours: take `today` from `me`, the family
  lives in its own timezone.
- **Ids are per day.** The same quest tomorrow has another `id` — always take
  it from `today` or `approvals` of the right date.
- **`done`, `approve`, `reject` are safe to repeat** — points are not credited
  twice (`already: true`). **`add-offer` is not**: a retry creates a second
  quest. If a call failed midway, run `offers` before repeating.
- **A future day** can't be checked off or approved (`invalid`).
- **`not_found`** on an id means it isn't in this family — re-read `today`.
- **Limit: 60 requests a minute** per key; over it — `rate_limited`, wait a minute.
- Rewards, perks, manual points and strikes are not in the API yet — tell the
  user to do those in the app.

## Before saying "done"

Re-read what you changed and report from the answer, not from memory:

- after `done` / `approve` / `reject` / `approve-all` — `scripts/qb.sh today`
  and check the `state` of each id you touched; for points — `scripts/qb.sh me`;
- after `add-offer` — `scripts/qb.sh offers` and find the new quest by title.

Report in three lines at most: what was done, what the re-read shows, what is
left for the user (for example, quests still `waiting_approval`).
