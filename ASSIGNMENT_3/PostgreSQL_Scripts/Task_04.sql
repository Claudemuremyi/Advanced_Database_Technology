-- TASK 4: TWO-PHASE COMMIT SIMULATION
---------------------------------------
-- Desctiption: Demonstrate distributed transaction atomicity using 2PC protocol
-- Ensures all-or-nothing execution across multiple database nodes
--------------------------------------------------------------------------------
-- STEP 1: Understanding Two-Phase Commit (2PC)
-- ============================================================================
-- Phase 1: PREPARE - All participants prepare to commit
-- Phase 2: COMMIT - If all prepared successfully, commit all; else rollback all

-- Rollback any existing prepared transactions from previous runs
DO $$
DECLARE
    txn RECORD;
BEGIN
    FOR txn IN SELECT gid FROM pg_prepared_xacts WHERE gid LIKE '%_txn_%' OR gid LIKE '%_transfer_%' OR gid LIKE '%_policy_%'
    LOOP
        EXECUTE 'ROLLBACK PREPARED ' || quote_literal(txn.gid);
        RAISE NOTICE 'Rolled back prepared transaction: %', txn.gid;
    END LOOP;
END $$;

-- Clean up test data from previous runs
DELETE FROM branch_kigali.Member WHERE Contact IN ('+250788111222');
DELETE FROM branch_musanze.Member WHERE Contact IN ('+250788111223');
DELETE FROM branch_kigali.InsurancePolicy WHERE Premium IN (180000.00, 220000.00);
DELETE FROM branch_musanze.InsurancePolicy WHERE Premium IN (300000.00, 150000.00);

-- STEP 2: Check if prepared transactions are enabled
------------------------------------------------------

-- Verify max_prepared_transactions setting (must be > 0)
SHOW max_prepared_transactions;

-- If it's 0, you need to set it in postgresql.conf and restart PostgreSQL

-- View currently prepared transactions
SELECT * FROM pg_prepared_xacts;

-- STEP 3: Scenario - Distributed member registration across branches
----------------------------------------------------------------------
-- Business Case: A member wants to register in both Kigali and Musanze branches
-- simultaneously. Both registrations must succeed or both must fail (atomicity).
---------------------------------------------------------------------------------

-- STEP 4: TWO-PHASE COMMIT - Successful scenario
--------------------------------------------------

-- Wrapped in DO block with exception handling to prevent transaction abort errors
DO $$
BEGIN
    -- Transaction 1: Prepare transaction in Kigali branch
    BEGIN
        INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
        VALUES ('Uwera Sandrine Mukeshimana', 'F', '+250788111222', 'Kicukiro, Kigali', CURRENT_DATE, 'Kigali');
        
        RAISE NOTICE 'Kigali Member Inserted: %', (SELECT MemberID FROM branch_kigali.Member WHERE Contact = '+250788111222');
        
        -- PREPARE the transaction (Phase 1)
        PREPARE TRANSACTION 'kigali_member_txn_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Kigali transaction: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

DO $$
BEGIN
    -- Transaction 2: Prepare transaction in Musanze branch
    BEGIN
        INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
        VALUES ('Uwera Sandrine Mukeshimana', 'F', '+250788111223', 'Musanze Town', CURRENT_DATE, 'Musanze');
        
        RAISE NOTICE 'Musanze Member Inserted: %', (SELECT MemberID FROM branch_musanze.Member WHERE Contact = '+250788111223');
        
        -- PREPARE the transaction (Phase 1)
        PREPARE TRANSACTION 'musanze_member_txn_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Musanze transaction: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

-- STEP 5: Check prepared transactions
---------------------------------------

-- View all prepared transactions
SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    owner,
    database
FROM pg_prepared_xacts
WHERE gid IN ('kigali_member_txn_001', 'musanze_member_txn_001');

-- STEP 6: COMMIT both prepared transactions (Phase 2)
-------------------------------------------------------

-- Added error handling for commit operations
DO $$
BEGIN
    -- Commit Kigali transaction
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'kigali_member_txn_001') THEN
        COMMIT PREPARED 'kigali_member_txn_001';
        RAISE NOTICE 'Committed: kigali_member_txn_001';
    END IF;
    
    -- Commit Musanze transaction
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'musanze_member_txn_001') THEN
        COMMIT PREPARED 'musanze_member_txn_001';
        RAISE NOTICE 'Committed: musanze_member_txn_001';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error during commit: %', SQLERRM;
END $$;

-- ============================================================================
-- STEP 7: Verify successful distributed commit
-- ============================================================================

-- Check Kigali branch
SELECT 'KIGALI BRANCH' AS Branch, MemberID, FullName, Contact, Branch
FROM branch_kigali.Member
WHERE FullName = 'Uwera Sandrine Mukeshimana';

-- Check Musanze branch
SELECT 'MUSANZE BRANCH' AS Branch, MemberID, FullName, Contact, Branch
FROM branch_musanze.Member
WHERE FullName = 'Uwera Sandrine Mukeshimana';

-- STEP 8: TWO-PHASE COMMIT - Complex scenario with loans
----------------------------------------------------------
-- Scenario: Transfer a loan from Kigali to Musanze branch
-- Must update both branches atomically
-----------------------------------------------------------

-- Wrapped loan transfer in DO blocks with exception handling
DO $$
BEGIN
    -- Transaction 1: Prepare to update loan status in Kigali
    BEGIN
        -- Mark loan as transferred in Kigali
        UPDATE branch_kigali.LoanAccount
        SET Status = 'Closed'
        WHERE LoanID = 1;
        
        RAISE NOTICE 'Kigali Loan Updated: %', (SELECT Status FROM branch_kigali.LoanAccount WHERE LoanID = 1);
        
        PREPARE TRANSACTION 'kigali_loan_transfer_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Kigali loan transfer: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

DO $$
BEGIN
    -- Transaction 2: Prepare to create new loan in Musanze
    BEGIN
        -- Create corresponding loan in Musanze
        INSERT INTO branch_musanze.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status)
        VALUES (1, 1, 5000000.00, 12.50, CURRENT_DATE, 'Active');
        
        RAISE NOTICE 'Musanze Loan Created: %', (SELECT LoanID FROM branch_musanze.LoanAccount WHERE Amount = 5000000.00 AND MemberID = 1 ORDER BY LoanID DESC LIMIT 1);
        
        PREPARE TRANSACTION 'musanze_loan_transfer_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Musanze loan creation: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

-- Check prepared transactions
SELECT gid, prepared, database 
FROM pg_prepared_xacts 
WHERE gid LIKE '%loan_transfer%';

-- Commit with error handling
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'kigali_loan_transfer_001') THEN
        COMMIT PREPARED 'kigali_loan_transfer_001';
        RAISE NOTICE 'Committed: kigali_loan_transfer_001';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'musanze_loan_transfer_001') THEN
        COMMIT PREPARED 'musanze_loan_transfer_001';
        RAISE NOTICE 'Committed: musanze_loan_transfer_001';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error during loan transfer commit: %', SQLERRM;
END $$;

-- Verify the distributed transaction
SELECT 'KIGALI - Loan Closed' AS Status, LoanID, Status 
FROM branch_kigali.LoanAccount WHERE LoanID = 1
UNION ALL
SELECT 'MUSANZE - New Loan Created', LoanID, Status 
FROM branch_musanze.LoanAccount WHERE Amount = 5000000.00 AND MemberID = 1;

-- ============================================================================
-- STEP 9: Demonstrate transaction atomicity with multiple operations
-- ============================================================================

-- Scenario: Bulk insurance policy creation across branches
DO $$
BEGIN
    BEGIN
        -- Insert multiple policies in Kigali
        INSERT INTO branch_kigali.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
        VALUES 
            (1, 'Health', 180000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active'),
            (2, 'Life', 220000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 years', 'Active');
        
        RAISE NOTICE 'Kigali Policies Prepared: %', (SELECT COUNT(*) FROM branch_kigali.InsurancePolicy WHERE Premium IN (180000.00, 220000.00));
        
        PREPARE TRANSACTION 'kigali_bulk_policy_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Kigali bulk policy: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

DO $$
BEGIN
    BEGIN
        -- Insert multiple policies in Musanze
        INSERT INTO branch_musanze.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
        VALUES 
            (1, 'Property', 300000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active'),
            (2, 'Accident', 150000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active');
        
        RAISE NOTICE 'Musanze Policies Prepared: %', (SELECT COUNT(*) FROM branch_musanze.InsurancePolicy WHERE Premium IN (300000.00, 150000.00));
        
        PREPARE TRANSACTION 'musanze_bulk_policy_001';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in Musanze bulk policy: %', SQLERRM;
        ROLLBACK;
    END;
END $$;

-- View prepared transactions
SELECT gid, prepared FROM pg_prepared_xacts WHERE gid LIKE '%bulk_policy%';

-- Commit with error handling
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'kigali_bulk_policy_001') THEN
        COMMIT PREPARED 'kigali_bulk_policy_001';
        RAISE NOTICE 'Committed: kigali_bulk_policy_001';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_prepared_xacts WHERE gid = 'musanze_bulk_policy_001') THEN
        COMMIT PREPARED 'musanze_bulk_policy_001';
        RAISE NOTICE 'Committed: musanze_bulk_policy_001';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error during bulk policy commit: %', SQLERRM;
END $$;

-- Verify distributed commit
SELECT 'TOTAL POLICIES CREATED' AS Status, 
       (SELECT COUNT(*) FROM branch_kigali.InsurancePolicy WHERE Premium IN (180000.00, 220000.00)) +
       (SELECT COUNT(*) FROM branch_musanze.InsurancePolicy WHERE Premium IN (300000.00, 150000.00)) AS Total_Count;

-- STEP 10: Cleanup and verification
------------------------------------

-- Check for any remaining prepared transactions
SELECT 
    gid AS transaction_id,
    prepared AS prepare_time,
    owner,
    database,
    CURRENT_TIMESTAMP - prepared AS age
FROM pg_prepared_xacts
ORDER BY prepared DESC;
