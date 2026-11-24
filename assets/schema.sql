-- ============================================================
-- My Tasks — SQL schema for online / GitHub version
-- Compatible with SQLite AND Postgres (Supabase / Neon).
-- Maps 1:1 to normTask() in your HTML file.
-- For Postgres, replace AUTOINCREMENT with GENERATED ALWAYS AS IDENTITY
-- ============================================================

-- ---------- 1) USERS ----------
-- HTML today: localStorage['aurum_users_v1'] = { username: {pass, created, passUpdated} }
-- SQL future: one row per person. NEVER store plaintext.
CREATE TABLE IF NOT EXISTS users (
  username      TEXT PRIMARY KEY,          -- e.g. 'admin','user1' (max 40, no spaces - enforced in app)
  pass_hash     TEXT NOT NULL,             -- 'p2$salt$120000$hash' (new) or 's2$salt$hash' (legacy)
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),  -- ISO8601, = users[u].created
  pass_updated_at TEXT,                    -- = users[u].passUpdated
  is_admin      INTEGER NOT NULL DEFAULT 0 -- 1 only for 'admin'
);

-- ---------- 2) PROJECTS ----------
-- HTML today: localStorage['aurum_projects_v1'] + task.project string
CREATE TABLE IF NOT EXISTS projects (
  id         TEXT PRIMARY KEY,   -- same id you use in task.project, or 't...' uid()
  name       TEXT NOT NULL,
  owner      TEXT NOT NULL DEFAULT 'admin' REFERENCES users(username),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ---------- 3) TASKS (the main record) ----------
-- HTML today: localStorage['aurum_tasks_v1'] = array of normTask()
-- normTask fields mapped below with original JS limits in comments.
CREATE TABLE IF NOT EXISTS tasks (
  id            TEXT PRIMARY KEY,  -- uid() -> 't' + base36 : SAFE_ID_RE validated
  name          VARCHAR(120) NOT NULL,   -- String(t.name).slice(0,120), REQUIRED
  note          VARCHAR(300) NOT NULL DEFAULT '', -- slice(0,300)
  category      VARCHAR(40)  NOT NULL DEFAULT '', -- slice(0,40)
  due_date      DATE NOT NULL,       -- t.due, must match /^\d{4}-\d{2}-\d{2}$/
  due_time      VARCHAR(5) NOT NULL DEFAULT '',   -- /^\d{2}:\d{2}$/ or ''
  urgency       TEXT NOT NULL DEFAULT 'medium'
                CHECK (urgency IN ('low','medium','high','critical')),
  recorded_at   TEXT NOT NULL DEFAULT (datetime('now')), -- t.recorded ISO
  done          INTEGER NOT NULL DEFAULT 0,  -- !!t.done -> 0/1
  done_at       TEXT NOT NULL DEFAULT '',    -- t.doneAt ISO or ''
  delayed       INTEGER NOT NULL DEFAULT 0,
  delay_count   INTEGER NOT NULL DEFAULT 0,  -- +t.delayCount
  orig_due      DATE,                        -- t.origDue or NULL
  repeat_mode   TEXT NOT NULL DEFAULT 'none'
                CHECK (repeat_mode IN ('none','daily','weekly','monthly')),
  assignee      TEXT NOT NULL DEFAULT '' REFERENCES users(username), -- slice(0,40)
  assigned_by   TEXT NOT NULL DEFAULT '' ,  -- slice(0,40)
  assigned_at   TEXT NOT NULL DEFAULT '',
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  qme           VARCHAR(60) NOT NULL DEFAULT '', -- slice(0,60)
  project_id    TEXT REFERENCES projects(id) ON DELETE SET NULL, -- t.project
  attachments_json TEXT NOT NULL DEFAULT '[]', -- normAtts(t.attachments) as JSON array string
  updated_at    TEXT NOT NULL DEFAULT (datetime('now')),
  deleted       INTEGER NOT NULL DEFAULT 0,  -- tombstone (= DBDEL row in tasks-database.csv)
  deleted_at    TEXT
);

-- Performance for 7 users x 50 = 350 tasks (and 10x more):
CREATE INDEX IF NOT EXISTS idx_tasks_assignee  ON tasks(assignee);
CREATE INDEX IF NOT EXISTS idx_tasks_due       ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_done      ON tasks(done);
CREATE INDEX IF NOT EXISTS idx_tasks_qme       ON tasks(qme);
CREATE INDEX IF NOT EXISTS idx_tasks_project   ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_recorded  ON tasks(recorded_at);

-- ---------- 4) AUDIT LOG ----------
-- HTML today: meta.audit in localStorage['aurum_meta_v2'] (max 200, renderAudit shows 50)
CREATE TABLE IF NOT EXISTS audit_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  when_at    TEXT NOT NULL DEFAULT (datetime('now')),
  by_user    TEXT NOT NULL REFERENCES users(username),
  kind       TEXT NOT NULL,   -- 'assign','done','delay','create',...
  task_id    TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  task_name  VARCHAR(60),
  to_user    TEXT
);
CREATE INDEX IF NOT EXISTS idx_audit_when ON audit_log(when_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_by   ON audit_log(by_user);

-- ---------- 5) SYNC STATE (replaces tasks-database.csv stamps) ----------
-- HTML today: CSV rows DB VSTAMP / DB WRITER + delSet (max 500)
CREATE TABLE IF NOT EXISTS sync_state (
  key   TEXT PRIMARY KEY,  -- 'vstamp','writer'
  value TEXT NOT NULL
);

-- ============================================================
-- USEFUL QUERIES (same numbers your Analysis tab shows)
-- ============================================================

-- Q1: tasks per user (your 7 x 50 check):
-- SELECT assignee, COUNT(*) FROM tasks WHERE deleted=0 GROUP BY assignee;

-- Q2: what V() shows for one signed-in user (user1 sees own + assigned-by-own; admin sees all):
-- SELECT * FROM tasks WHERE deleted=0 AND (assignee='user1' OR assigned_by='user1') ORDER BY due_date;

-- Q3: due today:
-- SELECT * FROM tasks WHERE deleted=0 AND done=0 AND due_date = date('now');

-- Q4: status breakdown for Insights & trends:
-- SELECT done, COUNT(*) FROM tasks WHERE deleted=0 GROUP BY done;

-- Q5: urgency mix:
-- SELECT urgency, COUNT(*) FROM tasks WHERE deleted=0 GROUP BY urgency;

-- ============================================================
-- SEED: manager account is created by REGISTER in the app,
-- never by SQL. Example (password hashed in app, not here):
-- INSERT INTO users(username, pass_hash, is_admin)
-- VALUES('admin','p2$...$...',1);
-- ============================================================
