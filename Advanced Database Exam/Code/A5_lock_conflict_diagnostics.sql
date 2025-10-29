-- A5: Distributed Lock Conflict & Diagnosis (no extra rows)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- A5_1: Session 1 on Node_A: UPDATE a single row and keep transaction open
-- Screenshot: A5 Session1 Update Lock NodeA – first session holding a lock

-- SESSION 1: Start transaction and hold a lock
-- Run this in pgAdmin Query Tool (Session 1)
BEGIN;
UPDATE node_a.orderdetail_a SET quantity = quantity + 1 WHERE detailid = 1;
-- DO NOT COMMIT YET - keep this transaction open

-- Verification for A5_1: Show locked row from Session 1 perspective
SELECT 
  'Session 1' AS session_info,
  detailid,
  orderid,
  quantity,
  'LOCKED' AS status
FROM node_a.orderdetail_a
WHERE detailid = 1;

-- A5_2: Session 2 from Node_B: UPDATE same logical row (will wait)
-- Screenshot: A5 Session2 Waiting Lock NodeB – second session waiting

-- SESSION 2: Open NEW Query Tool window and run this:
-- BEGIN;
-- UPDATE node_a.orderdetail_b_ft SET quantity = quantity + 1 WHERE orderid = 101;
-- This will WAIT because Session 1 holds a lock on related data

-- Verification query to show waiting state (run in Session 2 after starting UPDATE)
SELECT 
  pid,
  state,
  wait_event_type,
  wait_event,
  query_start,
  NOW() - query_start AS waiting_duration
FROM pg_stat_activity
WHERE state = 'active' AND wait_event IS NOT NULL;

-- A5_3: Query lock views (pg_locks, pg_blocking_pids) from Node_A
-- Screenshot: A5 pg locks View Output – lock diagnostics result

-- Diagnostics: Show all active queries
SELECT 
  pid,
  state,
  query,
  query_start,
  NOW() - query_start AS running_since
FROM pg_stat_activity 
WHERE state <> 'idle' AND datname = 'restaurantdb'
ORDER BY query_start;

-- Show blocking relationships
SELECT 
  pg_blocking_pids(pid) AS blocking_pids,
  pid AS waiting_pid,
  state,
  query
FROM pg_stat_activity 
WHERE state = 'active';

-- Show locks
SELECT 
  locktype,
  mode,
  granted,
  relation::regclass AS table_name,
  pid,
  virtualtransaction
FROM pg_locks 
WHERE NOT granted
ORDER BY pid;

-- Detailed lock diagnostics
SELECT 
  l.locktype,
  l.mode,
  l.granted,
  l.relation::regclass AS relation,
  a.pid,
  a.usename,
  a.query,
  a.state
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.granted = FALSE OR a.state = 'active'
ORDER BY l.granted, a.pid;

-- A5_4: Release the lock; show Session 2 completes
-- Screenshot: A5 Lock Release Timestamp – shows when second session proceeds

-- SESSION 1: Release the lock
-- COMMIT;  -- Run this in Session 1 to release the lock

-- SESSION 2: Should now proceed automatically

-- Verification: Show completed transactions
SELECT 
  'After lock release' AS phase,
  pid,
  state,
  query,
  state_change,
  NOW() - state_change AS time_since_state_change
FROM pg_stat_activity
WHERE datname = 'restaurantdb' 
  AND state IN ('idle', 'idle in transaction')
ORDER BY state_change DESC;

-- Final verification: Show updated row counts (no new rows inserted)
SELECT 
  'Node_A' AS fragment,
  COUNT(*) AS total_rows,
  SUM(CASE WHEN detailid = 1 THEN 1 ELSE 0 END) AS rows_locked_in_demo
FROM node_a.orderdetail_a;
