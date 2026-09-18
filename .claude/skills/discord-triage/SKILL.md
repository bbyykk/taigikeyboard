---
name: discord-triage
description: Triage Taigi Keyboard Discord #general chat into the #issues forum. Two phases - `scan` writes a review list (triage.md) of messages that look like bug reports or feature requests, skipping ones the bot already handled; `apply` executes the approved rows (create #issues post with message link, reply under the #general message, mark fixed posts with the version + close, fix tags). Requires the `discord` MCP server (discord-mcp). Args - `scan [n]` or `apply <triage.md>`.
disable-model-invocation: false
---

# Discord Triage

Turn #general chat into tracked #issues forum posts. Backed by the `discord` MCP server
(`~/Workspace/discord-mcp`; tools `read_channel`, `list_posts`, `read_post`, `create_post`,
`reply_post`, `list_tags`, `set_tags`/`add_tags`/`remove_tags`, `close_post`).

**Never write to Discord in `scan`. Only `apply` writes, and only rows the USER approved.**

## Config

`channels.json` (this dir): `general` / `issues` channel IDs, `bot_username` (the MCP bot's
Discord username — used to recognise its own replies). Any value empty → ask the USER once,
then write it back to the file.

MCP not registered (`claude mcp list` has no `discord`) → tell the USER to run
`claude mcp add -s user discord -e DISCORD_BOT_TOKEN=<token> -- uv --directory ~/Workspace/discord-mcp run discord-mcp`
themselves (token is theirs), then restart the session.

## `scan [n]` — build the review list (read-only)

1. `read_channel(general, limit=100)`; if `n` > 100 keep paging with `before=<oldest id>` until
   `n` messages or the channel ends.
2. **Skip already-handled messages**: collect `reply_to` of every message whose `author ==
   bot_username`; any message whose `id` is in that set is done. Second dedup source: message
   links (`https://discord.com/channels/<guild>/<channel>/<id>`) found in the first message of
   every `list_posts(issues, include_archived=true)` post (`read_post` each). Third source:
   message IDs in `skipped.json` (this dir) — rows the USER marked `skip` in an earlier `apply`.
3. **Candidate = 疑似需求, loose** (USER 2026-09-18: 寬鬆, the USER reviews the list). Keep a
   message when it reports something broken or asks for a capability: bug / feature / "希望",
   "可以…嗎", "能不能", "壞掉", "沒反應", "打不出來", "建議", stack of screenshots + complaint.
   Drop pure discussion, greetings, thanks, answers to someone else's question, and bot output.
   Merge a reporter's consecutive messages (same author, < 10 min apart) into one row; link the
   first message.
4. **Fixed check**: for each candidate, grep `changelog/*.md` and `docs/architecture/dogfood-checklist.md`
   for the symptom's keywords. A clear hit → `fixed` + the changelog file's version; no hit or
   unsure → leave the version column empty. Never guess a version.
5. **Tags**: `list_tags(issues)` once; pick the best-fitting existing tag names per row
   (platform + kind, e.g. `ios`, `android`, `bug`, `feature`). Never propose `done` or `drop`.
6. Write `triage.md` to the scratchpad dir and print its path. One row per candidate:

   ```
   | # | action | link | author | date | summary (EN, ≤ 1 line) | tags | fixed in | note |
   ```
   `action` ∈ `create` (new #issues post) · `fixed` (create post, reply fixed, close) ·
   `skip`. Existing #issues posts that match a candidate get `action = exists` with the post
   ID in `note`, so `apply` replies under the #general message without creating a duplicate.

   Also list, below the table, existing #issues posts that carry `done` or `drop` tags or are
   archived-but-tagged-`done`, with a proposed action (reply fixed version + close, or just retag)
   — same review rule applies.

7. Stop. Report the counts (scanned / skipped as handled / candidates) and the file path.
   USER edits the file (change `action`, fill `fixed in`, delete rows), then runs `apply`.

## `apply <triage.md>` — execute approved rows (writes)

Process rows top-down; on any Discord error stop, report the row, do not retry blindly.

| action | steps |
|---|---|
| `create` | `create_post(issues, title=summary, content=<template A>, tags)` → `reply_post(general, <template B>, reply_to=<msg id>)` |
| `fixed` | same as `create`, then `reply_post(post, <template C>)` → `remove_tags(post, ["done","drop"])` if present → `close_post(post)` |
| `exists` | `reply_post(general, <template B with existing post link>, reply_to=<msg id>)`; if `fixed in` filled, also template C + retag + close on that post |
| `skip` | append the message ID to `skipped.json` (this dir, `{"skipped": [<id>, …]}`); no Discord write |

Post link = `https://discord.com/channels/<guild>/<post id>` (guild from the message link).

**Discord copy is short, plain English** (USER 2026-09-18). Templates — fill, do not embellish:

- **A** (post body): `<summary sentence>\n\nReported in #general: <message link>`
- **B** (reply under #general message): `Tracked in #issues: <post link>`
- **C** (fixed reply in post): `Fixed in v<version>.` — desktop versions say `desktop v3.6.8`,
  mobile `mobile v0.8`, matching `changelog/` file names.

After the run: rewrite `triage.md` with a `result` column (post ID or error) and print the
counts. Messages replied to in this run and `skip` rows are skipped by the next `scan` automatically (step 2).

## Rules

- `done` / `drop` are never applied; remove them when touching a post's tags.
- `fixed in` must come from `changelog/` or the USER — never inferred from code state.
- A "fixed" that the USER did not confirm stays `create`. Release scope is the USER's call.
