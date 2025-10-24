-- TASK 5: DISTRIBUTED ROLLBACK AND RECOVERY
---------------------------------------------
-- Desctiption: Demonstrate transaction failure handling and rollback in distributed systems
-- Show PostgreSQL's recovery mechanisms for prepared transactions
---------------------------------------------------------------------------------------------
-- STEP 0: CLEANUP - Remove test data from previous runs
--------------------------------------------------------

-- Clean up any orphaned prepared transactions from previous runs
DO $$
DECLARE
    txn RECORD;
BEGIN
    FOR txn IN SELECT gid FROM pg_prepared_xacts WHERE gid LIKE '%demo%' OR gid LIKE '%txn%'
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
    DELETE FROM branch_kigali.LoanAccount WHERE Amount = 8000000.00 AND Status = 'Pending';
    
    RAISE NOTICE 'Cleanup Complete - Ready for fresh test run';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup encountered error: %', SQLERRM;
END $$;

-- STEP 1: Scenario - Simulating transaction failure
----------------------------------------------------
-- Business Case: Attempting to create a member with duplicate contact number
-- across both branches. One will fail, requiring rollback of both.
-----------------------------------------------------------------------------

-- STEP 2: Prepare transactions that will need rollback
-------------------------------------------------------
-- Transaction 1: Prepare in Kigali (this will succeed)
BEGIN;

INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Mugisha Emmanuel Nkusi', 'M', '+250788999888', 'Remera, Kigali', CURRENT_DATE, 'Kigali');

SELECT 'Kigali Transaction Prepared' AS Status, MemberID, FullName, Contact
FROM branch_kigali.Member
WHERE Contact = '+250788999888';

-- Prepare the transaction
PREPARE TRANSACTION 'kigali_rollback_demo_001';

-- Transaction 2: Prepare in Musanze (this will also succeed initially)
BEGIN;

INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Mugisha Emmanuel Nkusi', 'M', '+250788999889', 'Musanze Center', CURRENT_DATE, 'Musanze');

SELECT 'Musanze Transaction Prepared' AS Status, MemberID, FullName, Contact
FROM branch_musanze.Member
WHERE Contact = '+250788999889';

-- Prepare the transaction
PREPARE TRANSACTION 'musanze_rollback_demo_001';

-- STEP 3: Check prepared transactions before rollback
-------------------------------------------------------
SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    owner,
    database,
    'PREPARED - Awaiting Commit or Rollback' AS status
FROM pg_prepared_xacts
WHERE gid IN ('kigali_rollback_demo_001', 'musanze_rollback_demo_001')
ORDER BY gid;

-- STEP 4: Simulate failure and perform ROLLBACK
------------------------------------------------
-- Scenario: Business logic detects an issue (e.g., duplicate member, 
-- insufficient funds, validation failure) and decides to rollback both transactions

-- Rollback Kigali transaction
ROLLBACK PREPARED 'kigali_rollback_demo_001';

-- Rollback Musanze transaction
ROLLBACK PREPARED 'musanze_rollback_demo_001';

-- STEP 5: Verify rollback was successful
------------------------------------------

-- Check that the members were NOT inserted in Kigali
SELECT 'KIGALI BRANCH - After Rollback' AS Status, COUNT(*) AS Member_Count
FROM branch_kigali.Member
WHERE Contact = '+250788999888';

-- Check that the members were NOT inserted in Musanze
SELECT 'MUSANZE BRANCH - After Rollback' AS Status, COUNT(*) AS Member_Count
FROM branch_musanze.Member
WHERE Contact = '+250788999889';

-- Verify prepared transactions are gone
SELECT 
    gid AS transaction_id,
    'Should be empty after rollback' AS note
FROM pg_prepared_xacts
WHERE gid IN ('kigali_rollback_demo_001', 'musanze_rollback_demo_001');

-- STEP 6: Complex rollback scenario - Loan application failure
----------------------------------------------------------------
-- Scenario: A loan application is being processed across branches
-- Kigali approves, but Musanze rejects due to credit check failure
-- Both transactions must be rolled back
-------------------------------------------------------------------

-- Transaction 1: Kigali loan approval (prepare)
BEGIN;

INSERT INTO branch_kigali.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status)
VALUES (1, 1, 8000000.00, 11.50, CURRENT_DATE, 'Pending');

SELECT 'Kigali Loan Prepared' AS Status, LoanID, Amount, Status
FROM branch_kigali.LoanAccount
WHERE Amount = 8000000.00 AND Status = 'Pending';

PREPARE TRANSACTION 'kigali_loan_app_002';

-- Transaction 2: Musanze credit check (prepare)
BEGIN;

-- Simulate credit check record
CREATE TEMP TABLE IF NOT EXISTS credit_check (
    CheckID SERIAL PRIMARY KEY,
    MemberID INT,
    Branch VARCHAR(50),
    CreditScore INT,
    Approved BOOLEAN,
    CheckDate DATE
);

INSERT INTO credit_check (MemberID, Branch, CreditScore, Approved, CheckDate)
VALUES (1, 'Musanze', 450, FALSE, CURRENT_DATE);  -- Failed credit check

SELECT 'Musanze Credit Check Prepared' AS Status, CheckID, CreditScore, Approved
FROM credit_check
WHERE MemberID = 1;

PREPARE TRANSACTION 'musanze_credit_check_002';

-- Check prepared transactions
SELECT gid, prepared, database
FROM pg_prepared_xacts
WHERE gid LIKE '%_002';


-- STEP 7: Rollback due to credit check failure
------------------------------------------------

-- Rollback both transactions due to failed credit check
ROLLBACK PREPARED 'kigali_loan_app_002';
ROLLBACK PREPARED 'musanze_credit_check_002';

-- Verify loan was not created
SELECT 'Loan Application Rolled Back' AS Status, COUNT(*) AS Loan_Count
FROM branch_kigali.LoanAccount
WHERE Amount = 8000000.00 AND Status = 'Pending';

-- STEP 8: Recovery from orphaned prepared transactions
--------------------------------------------------------
-- Scenario: System crash leaves prepared transactions in limbo
-- Demonstrate how to identify and recover from orphaned transactions
---------------------------------------------------------------------

-- Create an orphaned prepared transaction (simulate crash scenario)
BEGIN;

INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Orphaned Transaction Test', 'M', '+250788777666', 'Test Address', CURRENT_DATE, 'Kigali');

PREPARE TRANSACTION 'orphaned_txn_001';

-- Simulate another orphaned transaction
BEGIN;

INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
VALUES ('Orphaned Transaction Test 2', 'F', '+250788777667', 'Test Address 2', CURRENT_DATE, 'Musanze');

PREPARE TRANSACTION 'orphaned_txn_002';

-- STEP 9: Identify orphaned prepared transactions
--------------------------------------------------

-- List all prepared transactions with age
SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    CURRENT_TIMESTAMP - prepared AS age,
    owner,
    database,
    CASE 
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '1 hour' THEN 'ORPHANED - Consider Rollback'
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '10 minutes' THEN 'WARNING - Long Running'
        ELSE 'NORMAL'
    END AS status
FROM pg_prepared_xacts
ORDER BY prepared ASC;

-- STEP 10: Recovery procedure - Clean up orphaned transactions
----------------------------------------------------------------

-- Rollback orphaned transactions
ROLLBACK PREPARED 'orphaned_txn_001';
ROLLBACK PREPARED 'orphaned_txn_002';

-- Verify cleanup
SELECT 
    'Orphaned Transactions Cleaned' AS Status,
    COUNT(*) AS Remaining_Prepared_Transactions
FROM pg_prepared_xacts;

-- STEP 11: Demonstrate partial failure and recovery
----------------------------------------------------
-- Scenario: Multi-step transaction where step 2 fails
------------------------------------------------------

DO $$
DECLARE
    v_member_id INT;
BEGIN
    -- Step 1: Insert member (succeeds)
    INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
    VALUES ('Partial Failure Test', 'M', '+250788555444', 'Kigali', CURRENT_DATE, 'Kigali')
    RETURNING MemberID INTO v_member_id;
    
    RAISE NOTICE 'Member inserted with ID: %', v_member_id;
    
    -- Step 2: Attempt to insert loan with invalid data
    BEGIN
        INSERT INTO branch_kigali.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status)
        VALUES (v_member_id, 1, -5000000.00, 12.00, CURRENT_DATE, 'Active');
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Constraint violation detected - Rolling back entire transaction';
            RAISE EXCEPTION 'Transaction failed due to constraint violation';
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Transaction rolled back: %', SQLERRM;
        -- Transaction automatically rolled back
END $$;

-- Verify member was NOT inserted (entire transaction rolled back)
SELECT 'Partial Failure Recovery' AS Status, COUNT(*) AS Member_Count
FROM branch_kigali.Member
WHERE Contact = '+250788555444';

-- STEP 12: Create recovery monitoring view
--------------------------------------------
CREATE OR REPLACE VIEW vw_prepared_transaction_monitor AS
SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    CURRENT_TIMESTAMP - prepared AS age,
    owner,
    database,
    CASE 
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '1 hour' THEN 'CRITICAL - Orphaned'
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '30 minutes' THEN 'WARNING - Long Running'
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '10 minutes' THEN 'ATTENTION - Monitor'
        ELSE 'NORMAL'
    END AS alert_level,
    CASE 
        WHEN CURRENT_TIMESTAMP - prepared > INTERVAL '1 hour' THEN 'ROLLBACK RECOMMENDED'
        ELSE 'MONITOR'
    END AS recommended_action
FROM pg_prepared_xacts
ORDER BY prepared ASC;

-- View the monitoring dashboard
SELECT * FROM vw_prepared_transaction_monitor;

-- STEP 13: Final verification and cleanup
-------------------------------------------

-- Check for any remaining prepared transactions
SELECT 
    'Final Status Check' AS Report,
    COUNT(*) AS Prepared_Transaction_Count,
    CASE 
        WHEN COUNT(*) = 0 THEN 'All transactions resolved'
        ELSE 'Transactions pending - review required'
    END AS Status
FROM pg_prepared_xacts;
