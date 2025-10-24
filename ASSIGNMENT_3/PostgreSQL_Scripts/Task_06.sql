-- TASK 6: DISTRIBUTED CONCURRENCY CONTROL
-------------------------------------------
-- Desctiption: Demonstrate lock conflicts when updating the same record from different nodes
-- and analyze distributed locking mechanisms in PostgreSQL
----------------------------------------------------------------------------------------------

-- CLEANUP: Remove test data from previous runs
-----------------------------------------------

DROP TABLE IF EXISTS public.SharedAccountBalance CASCADE;

-- STEP 1: Setup - Create a shared table for concurrency testing
----------------------------------------------------------------

-- Create a shared account balance table that both branches can access
CREATE TABLE public.SharedAccountBalance (
    AccountID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Branch VARCHAR(50) NOT NULL,
    Balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedBy VARCHAR(100)
);

-- Insert test data
INSERT INTO public.SharedAccountBalance (MemberID, Branch, Balance, UpdatedBy) VALUES
(1, 'Kigali', 1000000.00, 'System'),
(2, 'Musanze', 500000.00, 'System'),
(3, 'Kigali', 750000.00, 'System');

-- STEP 2: Simulate concurrent updates from different sessions
--------------------------------------------------------------

-- SESSION 1 SCRIPT (Run in first terminal/connection)
-- This simulates a transaction from Kigali branch
-- Copy and run this in a separate psql session:

/*
BEGIN;
SELECT pg_backend_pid() AS session1_pid; -- Note this PID
UPDATE public.SharedAccountBalance 
SET Balance = Balance - 100000.00,
    LastUpdated = CURRENT_TIMESTAMP,
    UpdatedBy = 'Kigali Branch Officer'
WHERE AccountID = 1;

-- DO NOT COMMIT YET - Keep transaction open
-- Wait 30 seconds before running COMMIT to simulate long transaction
SELECT pg_sleep(30);
COMMIT;
*/

-- SESSION 2 SCRIPT (Run in second terminal/connection while Session 1 is waiting)
-- This simulates a transaction from Musanze branch trying to update same record
-- Copy and run this in a separate psql session:

/*
BEGIN;
SELECT pg_backend_pid() AS session2_pid; -- Note this PID
-- This will BLOCK waiting for Session 1's lock
UPDATE public.SharedAccountBalance 
SET Balance = Balance + 50000.00,
    LastUpdated = CURRENT_TIMESTAMP,
    UpdatedBy = 'Musanze Branch Officer'
WHERE AccountID = 1;

COMMIT;
*/

-- STEP 3: Query lock information during conflict
-------------------------------------------------

-- Run this query in a THIRD session while the above two are running
-- to observe the lock conflict:

SELECT 
    l.locktype,
    l.database,
    l.relation::regclass AS table_name,
    l.page,
    l.tuple,
    l.virtualxid,
    l.transactionid,
    l.mode,
    l.granted,
    a.pid,
    a.usename,
    a.application_name,
    a.client_addr,
    a.state,
    a.query,
    a.wait_event_type,
    a.wait_event
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation = 'public.sharedaccountbalance'::regclass
ORDER BY l.granted, a.pid;

-- STEP 4: Identify blocking and blocked sessions
-------------------------------------------------

-- Query to see which session is blocking which
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement,
    blocked_activity.application_name AS blocked_application
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- STEP 5: Demonstrate deadlock scenario
-----------------------------------------

-- SESSION A: Update Account 1, then try to update Account 2
/*
BEGIN;
UPDATE public.SharedAccountBalance SET Balance = Balance - 50000 WHERE AccountID = 1;
SELECT pg_sleep(5); -- Wait 5 seconds
UPDATE public.SharedAccountBalance SET Balance = Balance + 50000 WHERE AccountID = 2;
COMMIT;
*/

-- SESSION B: Update Account 2, then try to update Account 1 (run simultaneously)
/*
BEGIN;
UPDATE public.SharedAccountBalance SET Balance = Balance - 30000 WHERE AccountID = 2;
SELECT pg_sleep(5); -- Wait 5 seconds
UPDATE public.SharedAccountBalance SET Balance = Balance + 30000 WHERE AccountID = 1;
COMMIT;
*/

-- PostgreSQL will detect the deadlock and abort one transaction

-- STEP 6: Implement optimistic locking with version control
------------------------------------------------------------

-- Add version column for optimistic locking
ALTER TABLE public.SharedAccountBalance ADD COLUMN IF NOT EXISTS Version INT DEFAULT 1;

-- Drop function if exists to avoid errors on re-run
DROP FUNCTION IF EXISTS update_balance_optimistic(INT, DECIMAL, INT, VARCHAR);

-- Function to update with optimistic locking
CREATE OR REPLACE FUNCTION update_balance_optimistic(
    p_account_id INT,
    p_amount DECIMAL(12, 2),
    p_expected_version INT,
    p_updated_by VARCHAR(100)
) RETURNS BOOLEAN AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    UPDATE public.SharedAccountBalance
    SET Balance = Balance + p_amount,
        Version = Version + 1,
        LastUpdated = CURRENT_TIMESTAMP,
        UpdatedBy = p_updated_by
    WHERE AccountID = p_account_id 
      AND Version = p_expected_version;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected = 0 THEN
        RAISE NOTICE 'Optimistic lock failed - record was modified by another transaction';
        RETURN FALSE;
    ELSE
        RAISE NOTICE 'Update successful - new version: %', p_expected_version + 1;
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Test optimistic locking
SELECT * FROM public.SharedAccountBalance WHERE AccountID = 1;

-- This should succeed
SELECT update_balance_optimistic(1, -50000.00, 1, 'Kigali Officer');

-- This should fail (version mismatch)
SELECT update_balance_optimistic(1, -30000.00, 1, 'Musanze Officer');

-- STEP 7: Advisory locks for distributed coordination
------------------------------------------------------

-- Use PostgreSQL advisory locks for custom locking logic
-- Session 1: Acquire advisory lock
/*
BEGIN;
SELECT pg_advisory_lock(12345); -- Lock with custom ID
-- Perform operations
SELECT pg_sleep(10);
SELECT pg_advisory_unlock(12345);
COMMIT;
*/

-- Session 2: Try to acquire same lock (will wait)
/*
BEGIN;
SELECT pg_advisory_lock(12345); -- Will block until Session 1 releases
-- Perform operations
SELECT pg_advisory_unlock(12345);
COMMIT;
*/

-- Check advisory locks
SELECT 
    locktype,
    objid,
    mode,
    granted,
    pid
FROM pg_locks
WHERE locktype = 'advisory';


-- STEP 8: Set lock timeout to prevent indefinite waiting
---------------------------------------------------------

-- Wrapped in DO block to handle potential errors
DO $$
BEGIN
    -- Set lock timeout for current session (5 seconds)
    EXECUTE 'SET lock_timeout = ''5s''';
    RAISE NOTICE 'Lock timeout set to 5 seconds';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error setting lock timeout: %', SQLERRM;
END $$;

-- Try an update that might block (wrapped in DO block for safety)
DO $$
BEGIN
    BEGIN
        UPDATE public.SharedAccountBalance SET Balance = Balance + 1000 WHERE AccountID = 1;
        RAISE NOTICE 'Update completed successfully';
        COMMIT;
    EXCEPTION WHEN lock_not_available THEN
        RAISE NOTICE 'Lock timeout - could not acquire lock within 5 seconds';
        ROLLBACK;
    WHEN OTHERS THEN
        RAISE NOTICE 'Error during update: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

-- Reset to default
RESET lock_timeout;

-- STEP 9: Monitor lock wait events
-- ================================

-- View current lock waits
SELECT 
    pid,
    usename,
    application_name,
    state,
    wait_event_type,
    wait_event,
    query,
    query_start,
    state_change
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY query_start;

-- STEP 10: Cleanup and verification
-------------------------------------

-- View final state of accounts
SELECT 
    AccountID,
    Branch,
    Balance,
    Version,
    LastUpdated,
    UpdatedBy
FROM public.SharedAccountBalance
ORDER BY AccountID;
