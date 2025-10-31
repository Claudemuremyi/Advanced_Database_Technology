-- TASK 4: TWO-PHASE COMMIT SIMULATION (SERVER-COMPATIBLE)
---------------------------------------
-- Description: Demonstrate distributed transaction atomicity using a portable
-- simulation that DOES NOT require prepared transactions. This runs smoothly
-- even when max_prepared_transactions = 0.
-- We operate across two schemas in a single database transaction to ensure
-- all-or-nothing behavior (atomicity), mirroring 2PC outcome.
--------------------------------------------------------------------------------

-- STEP 0: Cleanup from previous runs (idempotent)
DO $$
BEGIN
    DELETE FROM branch_kigali.Member WHERE Contact IN ('+250788111222');
    DELETE FROM branch_musanze.Member WHERE Contact IN ('+250788111223');
    DELETE FROM branch_kigali.InsurancePolicy WHERE Premium IN (180000.00, 220000.00);
    DELETE FROM branch_musanze.InsurancePolicy WHERE Premium IN (300000.00, 150000.00);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Cleanup notice: %', SQLERRM;
END $$;

-- STEP 1: Atomic registration across branches (single transaction)
-- This simulates successful 2PC outcome without using PREPARE TRANSACTION.
BEGIN;
    INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
    VALUES ('Uwera Sandrine Mukeshimana', 'F', '+250788111222', 'Kicukiro, Kigali', CURRENT_DATE, 'Kigali');

    INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
    VALUES ('Uwera Sandrine Mukeshimana', 'F', '+250788111223', 'Musanze Town', CURRENT_DATE, 'Musanze');
COMMIT;

-- Verify success
SELECT 'KIGALI BRANCH' AS Branch, MemberID, FullName, Contact, Branch
FROM branch_kigali.Member
WHERE Contact = '+250788111222'
UNION ALL
SELECT 'MUSANZE BRANCH', MemberID, FullName, Contact, Branch
FROM branch_musanze.Member
WHERE Contact = '+250788111223';

-- STEP 2: Atomic loan transfer simulation (close in Kigali, create in Musanze)
BEGIN;
    UPDATE branch_kigali.LoanAccount
    SET Status = 'Closed'
    WHERE LoanID = 1;

    INSERT INTO branch_musanze.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status)
    VALUES (1, 1, 5000000.00, 12.50, CURRENT_DATE, 'Active');
COMMIT;

-- Verify the distributed operation outcome
SELECT * FROM (
    SELECT 'KIGALI - Loan Closed' AS msg, LoanID AS loan_id, Status AS loan_status
    FROM branch_kigali.LoanAccount WHERE LoanID = 1
    UNION ALL
    SELECT 'MUSANZE - New Loan Created' AS msg, LoanID AS loan_id, Status AS loan_status
    FROM branch_musanze.LoanAccount WHERE Amount = 5000000.00 AND MemberID = 1
) s
ORDER BY loan_status DESC;

-- STEP 3: Bulk policy creation across branches (atomic group)
BEGIN;
    INSERT INTO branch_kigali.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
    VALUES 
        (1, 'Health', 180000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active'),
        (2, 'Life', 220000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 years', 'Active');

    INSERT INTO branch_musanze.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
    VALUES 
        (1, 'Property', 300000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active'),
        (2, 'Accident', 150000.00, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', 'Active');
COMMIT;

-- Verify bulk outcome
SELECT 'TOTAL POLICIES CREATED' AS Status, 
       (SELECT COUNT(*) FROM branch_kigali.InsurancePolicy WHERE Premium IN (180000.00, 220000.00)) +
       (SELECT COUNT(*) FROM branch_musanze.InsurancePolicy WHERE Premium IN (300000.00, 150000.00)) AS Total_Count;

-- STEP 4: Failure simulation to show atomic rollback (2PC negative outcome)
-- Intentionally cause an error in the second operation to ensure both revert.
DO $$
BEGIN
    PERFORM pg_advisory_lock(987654); -- prevent concurrent interference during demo
    BEGIN
        -- First op succeeds
        INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
        VALUES ('Will Rollback', 'M', '+250700000001', 'Test Address', CURRENT_DATE, 'Kigali');

        -- Second op fails (force a controlled error)
        INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
        VALUES (NULL, 'F', '+250700000002', 'Test Address 2', CURRENT_DATE, 'Musanze'); -- NULL FullName violates NOT NULL
    EXCEPTION WHEN OTHERS THEN
        -- The inner block is rolled back automatically (subtransaction)
        RAISE NOTICE 'Simulated failure occurred: %', SQLERRM;
    END;
    PERFORM pg_advisory_unlock(987654);
END $$;

-- Verify rollback: both inserts above should NOT persist
SELECT 'Rollback Check - Kigali Insert Exists?' AS Check, COUNT(*) AS cnt
FROM branch_kigali.Member WHERE Contact = '+250700000001'
UNION ALL
SELECT 'Rollback Check - Musanze Insert Exists?', COUNT(*)
FROM branch_musanze.Member WHERE Contact = '+250700000002';