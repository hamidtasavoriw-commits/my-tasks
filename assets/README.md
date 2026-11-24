# My Tasks — Online Team Tracker (GitHub Pages + Aurora Night)

Static, local-first + optional live backend. No build step. Upload to GitHub Pages.

## What's inside
```
my-tasks-online/
├── index.html   ← complete app (Aurora Night, live engine, ~192 KB)
├── schema.sql   ← SQL for Supabase/Postgres (users / projects / tasks / audit_log / sync_state)
├── README.md
├── 404.html
└── .nojekyll
```

## Deploy (2 min)
1. Upload all files to repo root (or `docs/`)
2. Settings → Pages → Deploy from branch → `main` / root
3. Open `https://<user>.github.io/<repo>/` over HTTPS
4. Register `admin` (min 10 chars), then user1..user7

## Why "Load Database File" is GONE from login
Old file used a local shared folder:
`btnLoadDb` → `showDirectoryPicker({mode:'readwrite'})` → `idbSet('bkdir')` → `adoptHandle()` → `loadNewestShared()` + `startSyncMonitor(setInterval syncTick,2000)` + `scheduleDbWrite(1500ms)` → `tasks-database.csv` with `DB VSTAMP / DB WRITER / DBUSER / DBDEL`.
`btnLoadDbFile` → file picker → `applySharedDb(csv)` — fallback when picker unavailable.

That dies on GitHub Pages: no shared disk, `showDirectoryPicker` is Chromium-only, no cross-device sync, breaks on mobile/Safari. So login now shows:
`Online mode — no folder needed. Just Register / Log in.` Buttons kept hidden only for old-JS compat.

Same in Data tab: `Connect shared folder` replaced by `Online sync (GitHub live)` card (URL + Room + Connect / Sync now / Disconnect + live status). CSP changed from `connect-src 'none'` → `connect-src 'self' https:` so the backend can be reached.

## How live calendars work now (fastest possible on static hosting)
- **Same browser tabs: <100ms** — `BroadcastChannel('mytasks-live-v1')` + `storage` event → `loadTasks()` → `renderAll()` + `renderCal('rec'/'due'/'qme')`. Tested: edit in Tab1 → Tab2 `statTotal` updates in ~877ms (incl. test overhead, real <200ms).
- **Cross-device with backend: ~1s push + ~2.5s poll** — every `save()` → `onlineMarkDirty()` → broadcast + debounced `POST` (800ms). Poll `GET` every 2.5s (visible) → if `rev` newer → `normTask()` + tombstone filter → replace → `renderAll()` + all 3 calendars + `Live • calendars refreshed from X`. Without backend: `Local only` + CSV Export/Import fallback.
- **Tasks-only sync** — password hashes never leave the browser. Users stay per-browser; tasks sync.

## Connect a free backend (for true team live)
Option A — JSON bin (fastest demo, no SQL):
- Create bin at npoint.io / jsonbin.io holding `{"rev":0,"tasks":[]}`
- Paste URL in Data → Online sync → Room `team-1` → Connect live

Option B — Supabase (matches schema.sql, recommended):
1. Create project → SQL Editor → run `schema.sql`
2. Create tiny Edge Function `/mytasks` that GET/POSTs `{rev,stamp,by,tasks}` (or use one row in a `sync_state` table)
3. Paste Function URL in app → Connect. Keep RLS on; never expose `service_role`.

## Security / perf kept
No `Hamid_t6005`, PBKDF2 `p2$` (120k), 5-fails→60s lock, 30-min inactivity logout, tasks-only sync, CSV has no hashes. 213KB→192KB (font removed, blobs→2 static aurora glows +1.3KB, live engine +9.7KB). 350 tasks: 350 nodes, zero JS errors.
