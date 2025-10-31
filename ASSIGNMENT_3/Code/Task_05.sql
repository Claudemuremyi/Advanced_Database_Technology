-- TASK 5: DISTRIBUTED ROLLBACK AND RECOVERY
-- ==========================================
-- Description: Simulate a network failure during a distributed transaction
-- Check unresolved transactions and resolve them using ROLLBACK PREPARED
-- (PostgreSQL equivalent of Oracle's ROLLBACK FORCE)


DO $$
DECLARE
    txn RECORD;
BEGIN
    -- Clean up any orphaned prepared transactions from previous runs
    FOR txn IN SELECT gid FROM pg_prepared_xacts WHERE gid LIKE '%demo%' OR gid LIKE '%orphan%' OR gid LIKE '%loan%'
    LOOP
        BEGIN
            EXECUTE 'ROLLBACK PREPARED ' || quote_literal(txn.gid);
            RAISE NOTICE 'Rolled back orphaned transaction: %', txn.gid;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Could not rollback transaction %: %', txn.gid, SQLERRM;
        END;
    END LOOP;
    
    -- Delete test members from previous runs
    DELETE FROM branch_kigali.Member WHERE Contact IN ('+250788999888', '+250788777666', '+250788555444');
    DELETE FROM branch_musanze.Member WHERE Contact IN ('+250788999889', '+250788777667');
    
    -- Delete test loans from previous runs
    DELETE FROM branch_kigali.LoanAccount WHERE Amount = 8000000.00;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup encountered error: %', SQLERRM;
END $$;

-- SCENARIO 1: SIMULATING NETWORK FAILURE DURING DISTRIBUTED TRANSACTION
-- ======================================================================
-- HARD GUARD: Abort early if prepared transactions are disabled to avoid engine errors
DO $$
DECLARE v_max_prep int;
BEGIN
    SELECT current_setting('max_prepared_transactions')::int INTO v_max_prep;
    IF v_max_prep = 0 THEN
        RAISE EXCEPTION 'Prepared transactions are disabled. Please enable by setting max_prepared_transactions > 0 and restarting PostgreSQL.'
            USING HINT = 'Edit postgresql.conf: max_prepared_transactions = 10; then restart.';
    END IF;
END $$;

-- STEP 1: Start distributed transaction on Kigali branch
-- ======================================================

BEGIN;
-- Insert member in Kigali branch
INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Mugisha Emmanuel', 'M', '+250788999888', 'Remera, Kigali', CURRENT_DATE, 'Kigali');

-- Prepare the transaction (simulating first phase of 2PC)
PREPARE TRANSACTION 'kigali_member_txn_001';

Select * from branch_kigali.Member where FullName='Mugisha Emmanuel';
-- STEP 2: Start distributed transaction on Musanze branch
-- ========================================================

BEGIN;
-- Insert related data in Musanze branch
INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Uwase Marie', 'F', '+250788999889', 'Musanze Center', CURRENT_DATE, 'Musanze');

-- Prepare the transaction (simulating first phase of 2PC)
PREPARE TRANSACTION 'musanze_member_txn_001';


-- STEP 4: CHECK UNRESOLVED TRANSACTIONS
-- ======================================
-- Query pg_prepared_xacts to identify unresolved transactions
-- This is PostgreSQL's equivalent of Oracle's DBA_2PC_PENDING

SELECT 
    '=== UNRESOLVED PREPARED TRANSACTIONS ===' AS report_section;

SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    owner AS transaction_owner,
    database AS db_name,
    CURRENT_TIMESTAMP - prepared AS time_pending,
    'UNRESOLVED - Awaiting Commit or Rollback' AS status
FROM pg_prepared_xacts
WHERE gid IN ('kigali_member_txn_001', 'musanze_member_txn_001')
ORDER BY gid;

-- Check data visibility (prepared data is visible in prepared transactions)
SELECT 'Kigali Branch - Prepared Data' AS status, COUNT(*) AS member_count
FROM branch_kigali.Member
WHERE Contact = '+250788999888';

SELECT 'Musanze Branch - Prepared Data' AS status, COUNT(*) AS member_count
FROM branch_musanze.Member
WHERE Contact = '+250788999889';

-- STEP 5: RESOLVE USING ROLLBACK PREPARED
-- ========================================
-- PostgreSQL uses ROLLBACK PREPARED (equivalent to Oracle's ROLLBACK FORCE)
-- This resolves the in-doubt transaction by rolling it back
-- =========================================================================

-- Rollback Kigali transaction
ROLLBACK PREPARED 'kigali_member_txn_001';

-- Rollback Musanze transaction
ROLLBACK PREPARED 'musanze_member_txn_001';

-- STEP 6: VERIFY RECOVERY 
-- =======================

-- Verify transactions are no longer in prepared state
SELECT 
    '=== AFTER ROLLBACK - SHOULD BE EMPTY ===' AS report_section;

SELECT 
    gid AS transaction_id,
    'Should be empty after rollback' AS note
FROM pg_prepared_xacts
WHERE gid IN ('kigali_member_txn_001', 'musanze_member_txn_001');

-- Verify data was rolled back (should return 0 rows)
SELECT 'Kigali Branch - After Rollback' AS status, COUNT(*) AS member_count
FROM branch_kigali.Member
WHERE Contact = '+250788999888';

SELECT 'Musanze Branch - After Rollback' AS status, COUNT(*) AS member_count
FROM branch_musanze.Member
WHERE Contact = '+250788999889';

-- STEP 7: Prepare loan application on Kigali
-- ============================================================================

BEGIN;
INSERT INTO branch_kigali.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status)
VALUES (1, 1, 8000000.00, 11.50, CURRENT_DATE, 'Pending');

PREPARE TRANSACTION 'kigali_loan_app_002';
-- STEP 8: Prepare credit check on Musanze
-- =======================================

BEGIN;
-- Create temporary credit check table
CREATE TEMP TABLE IF NOT EXISTS credit_check_temp (
    CheckID SERIAL PRIMARY KEY,
    MemberID INT,
    Branch VARCHAR(50),
    CreditScore INT,
    Approved BOOLEAN,
    CheckDate DATE
);

INSERT INTO credit_check_temp (MemberID, Branch, CreditScore, Approved, CheckDate)
VALUES (1, 'Musanze', 450, FALSE, CURRENT_DATE);  -- Failed credit check

PREPARE TRANSACTION 'musanze_credit_check_002';

-- STEP 9: Check unresolved loan transactions
-- ===========================================

SELECT 
    '=== LOAN APPLICATION - UNRESOLVED TRANSACTIONS ===' AS report_section;

SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    CURRENT_TIMESTAMP - prepared AS age,
    'PENDING - Credit check failed, needs rollback' AS status
FROM pg_prepared_xacts
WHERE gid LIKE '%_002'
ORDER BY gid;

-- STEP 10: Rollback due to failed credit check
-- =============================================

ROLLBACK PREPARED 'kigali_loan_app_002';
ROLLBACK PREPARED 'musanze_credit_check_002';

-- Verify rollback
SELECT 'Loan Application - After Rollback' AS status, COUNT(*) AS loan_count
FROM branch_kigali.LoanAccount
WHERE Amount = 8000000.00;

-- STEP 11: Create orphaned transactions
-- =====================================

BEGIN;
INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Orphaned Test 1', 'M', '+250788777666', 'Test Address', CURRENT_DATE, 'Kigali');
PREPARE TRANSACTION 'orphan_kigali_003';

BEGIN;
INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Orphaned Test 2', 'F', '+250788777667', 'Test Address 2', CURRENT_DATE, 'Musanze');
PREPARE TRANSACTION 'orphan_musanze_003';

-- Simulate system crash here (transactions left in prepared state)
-- STEP 12: IDENTIFY ORPHANED TRANSACTIONS (Recovery Procedure)
-- ============================================================

SELECT 
    '=== ORPHANED TRANSACTION DETECTION ===' AS report_section;

SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    CURRENT_TIMESTAMP - prepared AS age,
    owner,
    database,
    CASE 
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '1 hour' THEN 'CRITICAL - Orphaned'
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '10 minutes' THEN 'WARNING - Long Running'
        ELSE 'NORMAL - Recent'
    END AS alert_level,
    'ROLLBACK RECOMMENDED' AS recommended_action
FROM pg_prepared_xacts
WHERE gid LIKE 'orphan%'
ORDER BY prepared ASC;

-- STEP 13: RECOVERY - Rollback orphaned transactions
-- ==================================================

ROLLBACK PREPARED 'orphan_kigali_003';
ROLLBACK PREPARED 'orphan_musanze_003';

-- STEP 14: FINAL VERIFICATION
-- ============================

SELECT 
    '=== FINAL STATUS - ALL TRANSACTIONS RESOLVED ===' AS report_section;

SELECT 
    COUNT(*) AS remaining_prepared_transactions,
    CASE 
        WHEN COUNT(*) = 0 THEN 'SUCCESS - All transactions resolved'
        ELSE 'WARNING - Transactions still pending'
    END AS recovery_status
FROM pg_prepared_xacts
WHERE gid LIKE '%demo%' OR gid LIKE '%orphan%' OR gid LIKE '%_002' OR gid LIKE '%_003';
