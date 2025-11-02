-- INTELLIGENT TASK 1: RULES (DECLARATIVE CONSTRAINTS) - SAFE INSURANCE CLAIMS
-- ============================================================================
-- Description: Create MEMBER_CLAIM under SACCO schema and enforce
-- non-negative claim amounts, mandatory fields, referential integrity to MEMBER,
-- and sensible date logic (claim date not after processing date).
-- STEP 1: Create schema and prerequisite table
-- =============================================

-- Ensure we're using the SACCO schema structure
SET search_path TO public, branch_kigali, branch_musanze;

DROP TABLE IF EXISTS public.MEMBER_CLAIM CASCADE;

CREATE TABLE public.MEMBER_CLAIM (
    CLAIM_ID SERIAL PRIMARY KEY,                    -- FIXED: comma not needed (last in list), but kept for clarity
    MEMBER_ID INT NOT NULL REFERENCES branch_kigali.Member(MemberID) ON DELETE RESTRICT,  -- FIXED: Added NOT NULL
    CLAIM_TYPE VARCHAR(80) NOT NULL,                -- FIXED: Added NOT NULL
    CLAIM_AMOUNT DECIMAL(12,2) CHECK (CLAIM_AMOUNT >= 0),  -- FIXED: Added parentheses
    CLAIM_DATE DATE,
    PROCESSED_DATE DATE,
    STATUS VARCHAR(20) DEFAULT 'Pending',
    CONSTRAINT CK_CLAIM_DATES CHECK (                    -- FIXED: Proper NULL-aware date check
        (CLAIM_DATE IS NULL OR PROCESSED_DATE IS NULL) OR 
        (CLAIM_DATE IS NOT NULL AND PROCESSED_DATE IS NOT NULL AND CLAIM_DATE <= PROCESSED_DATE)
    )
);

-- STEP 2: Insert sample MEMBER records for testing (if not already exist)
-- ========================================================================

-- Assuming members already exist from Task_01, but adding check
INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch)
SELECT 'Test Member Claim', 'M', '+250788999999', 'Test Address', CURRENT_DATE, 'Kigali'
WHERE NOT EXISTS (SELECT 1 FROM branch_kigali.Member WHERE Contact = '+250788999999');

-- Get member IDs for testing
SELECT 'Available Members for Testing' AS Info, MemberID, FullName FROM branch_kigali.Member LIMIT 5;

-- STEP 3: Test INSERT statements - FAILING cases (showing constraint violations)
-- =============================================================================

-- FAILING INSERT 1: Negative claim amount (violates CHECK constraint on CLAIM_AMOUNT)
-- Expected Error: new row for relation "member_claim" violates check constraint "member_claim_claim_amount_check"
DO $$
DECLARE
    v_member_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    BEGIN
        INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
        VALUES (v_member_id, 'Medical', -5000.00, '2024-01-01', '2024-01-15');
        RAISE NOTICE 'ERROR: This should have failed due to negative claim amount!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS: Constraint violation caught - Negative claim amount rejected. Error: %', SQLERRM;
    END;
END $$;

-- FAILING INSERT 2: Missing member reference (violates foreign key constraint)
-- Expected Error: insert or update on table "member_claim" violates foreign key constraint
DO $$
BEGIN
    BEGIN
        INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
        VALUES (99999, 'Property Damage', 10000.00, '2024-01-01', '2024-01-15');
        RAISE NOTICE 'ERROR: This should have failed due to non-existent member!';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'SUCCESS: Foreign key violation caught - Non-existent member rejected. Error: %', SQLERRM;
    END;
END $$;

-- FAILING INSERT 3: Missing CLAIM_TYPE (violates NOT NULL constraint)
-- Expected Error: null value in column "claim_type" violates not-null constraint
DO $$
DECLARE
    v_member_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    BEGIN
        INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
        VALUES (v_member_id, NULL, 5000.00, '2024-01-01', '2024-01-15');
        RAISE NOTICE 'ERROR: This should have failed due to NULL CLAIM_TYPE!';
    EXCEPTION WHEN not_null_violation THEN
        RAISE NOTICE 'SUCCESS: NOT NULL violation caught - Missing claim type rejected. Error: %', SQLERRM;
    END;
END $$;

-- FAILING INSERT 4: Inverted dates (CLAIM_DATE > PROCESSED_DATE violates CK_CLAIM_DATES)
-- Expected Error: new row for relation "member_claim" violates check constraint "ck_claim_dates"
DO $$
DECLARE
    v_member_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    BEGIN
        INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
        VALUES (v_member_id, 'Accident', 15000.00, '2024-01-20', '2024-01-10');
        RAISE NOTICE 'ERROR: This should have failed due to inverted dates!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS: Date constraint violation caught - Inverted dates rejected. Error: %', SQLERRM;
    END;
END $$;

-- STEP 4: Test INSERT statements - PASSING cases
-- =============================================

-- PASSING INSERT 1: All valid values
DO $$
DECLARE
    v_member_id INT;
    v_claim_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE, STATUS)
    VALUES (v_member_id, 'Medical Expense', 50000.00, '2024-01-01', '2024-01-15', 'Approved')
    RETURNING CLAIM_ID INTO v_claim_id;
    
    RAISE NOTICE 'SUCCESS: Valid claim inserted with CLAIM_ID = %', v_claim_id;
END $$;

SELECT 'PASSING INSERT 1' AS Test_Case, CLAIM_ID, MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE, STATUS
FROM public.MEMBER_CLAIM
WHERE CLAIM_TYPE = 'Medical Expense'
ORDER BY CLAIM_ID DESC
LIMIT 1;

-- PASSING INSERT 2: Valid with NULL dates (constraint allows NULL dates)
DO $$
DECLARE
    v_member_id INT;
    v_claim_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
    VALUES (v_member_id, 'Property Loss', 75000.00, NULL, NULL)
    RETURNING CLAIM_ID INTO v_claim_id;
    
    RAISE NOTICE 'SUCCESS: Valid claim with NULL dates inserted with CLAIM_ID = %', v_claim_id;
END $$;

SELECT 'PASSING INSERT 2' AS Test_Case, CLAIM_ID, MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE, STATUS
FROM public.MEMBER_CLAIM
WHERE CLAIM_TYPE = 'Property Loss'
ORDER BY CLAIM_ID DESC
LIMIT 1;

-- PASSING INSERT 3: Valid with one NULL date
DO $$
DECLARE
    v_member_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    INSERT INTO public.MEMBER_CLAIM (MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE)
    VALUES (v_member_id, 'Life Insurance Claim', 200000.00, '2024-02-01', NULL);
    
    RAISE NOTICE 'SUCCESS: Valid claim with partial dates inserted';
END $$;

SELECT 'PASSING INSERT 3' AS Test_Case, CLAIM_ID, MEMBER_ID, CLAIM_TYPE, CLAIM_AMOUNT, CLAIM_DATE, PROCESSED_DATE
FROM public.MEMBER_CLAIM
WHERE CLAIM_TYPE = 'Life Insurance Claim'
ORDER BY CLAIM_ID DESC
LIMIT 1;

-- STEP 5: Verification Summary
-- ============================

SELECT 
    'Constraint Verification Summary' AS Report,
    (SELECT COUNT(*) FROM public.MEMBER_CLAIM WHERE CLAIM_AMOUNT < 0) AS Negative_Amount_Count,
    (SELECT COUNT(*) FROM public.MEMBER_CLAIM WHERE CLAIM_TYPE IS NULL) AS Null_Claim_Type_Count,
    (SELECT COUNT(*) FROM public.MEMBER_CLAIM 
     WHERE CLAIM_DATE IS NOT NULL AND PROCESSED_DATE IS NOT NULL 
     AND CLAIM_DATE > PROCESSED_DATE) AS Inverted_Dates_Count,
    (SELECT COUNT(*) FROM public.MEMBER_CLAIM) AS Total_Valid_Records,
    (SELECT COUNT(*) FROM public.MEMBER_CLAIM 
     WHERE MEMBER_ID NOT IN (SELECT MemberID FROM branch_kigali.Member)) AS Invalid_Member_Ref_Count;

-- Expected results:
-- Negative_Amount_Count: 0
-- Null_Claim_Type_Count: 0
-- Inverted_Dates_Count: 0
-- Invalid_Member_Ref_Count: 0
-- Total_Valid_Records: 3 (from passing inserts)

-- Display all valid claims
SELECT 
    'All Valid Claims' AS Report,
    C.CLAIM_ID,
    C.MEMBER_ID,
    M.FullName AS Member_Name,
    C.CLAIM_TYPE,
    C.CLAIM_AMOUNT,
    C.CLAIM_DATE,
    C.PROCESSED_DATE,
    C.STATUS
FROM public.MEMBER_CLAIM C
JOIN branch_kigali.Member M ON C.MEMBER_ID = M.MemberID
ORDER BY C.CLAIM_ID;

