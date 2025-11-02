-- INTELLIGENT TASK 2: ACTIVE DATABASES (E-C-A TRIGGER) - LOAN PAYMENT TOTALS
-- ============================================================================
-- Description: Replace row-level trigger with statement-level trigger to keep
-- LOAN.TOTAL_PAID consistent whenever LOAN_PAYMENT changes. Must avoid
-- mutating-table issues and redundant work.
-- ============================================================================

-- STEP 1: Create prerequisite tables
-- ====================================

DROP TABLE IF EXISTS public.LOAN_AUDIT CASCADE;
DROP TABLE IF EXISTS public.LOAN_PAYMENT CASCADE;
DROP TABLE IF EXISTS public.LOAN CASCADE;

-- Create LOAN table (simplified version for this exercise)
CREATE TABLE public.LOAN (
    LOAN_ID SERIAL PRIMARY KEY,
    MEMBER_ID INT NOT NULL,
    LOAN_AMOUNT DECIMAL(12,2) NOT NULL,
    TOTAL_PAID DECIMAL(12,2) DEFAULT 0,  -- Derived total that must stay consistent
    REMAINING_BALANCE DECIMAL(12,2) GENERATED ALWAYS AS (LOAN_AMOUNT - TOTAL_PAID) STORED,
    CREATED_DATE DATE DEFAULT CURRENT_DATE
);

-- Create LOAN_PAYMENT table (equivalent to BILL_ITEM)
CREATE TABLE public.LOAN_PAYMENT (
    PAYMENT_ID SERIAL PRIMARY KEY,
    LOAN_ID INT NOT NULL REFERENCES public.LOAN(LOAN_ID) ON DELETE CASCADE,
    PAYMENT_AMOUNT DECIMAL(12,2) NOT NULL,
    PAYMENT_DATE DATE DEFAULT CURRENT_DATE,
    PAYMENT_METHOD VARCHAR(50),
    CONSTRAINT FK_LOAN_PAYMENT_LOAN FOREIGN KEY (LOAN_ID) REFERENCES public.LOAN(LOAN_ID)
);

-- Create LOAN_AUDIT table (equivalent to BILL_AUDIT)
CREATE TABLE public.LOAN_AUDIT (
    AUDIT_ID SERIAL PRIMARY KEY,
    LOAN_ID INT,
    OLD_TOTAL_PAID DECIMAL(12,2),
    NEW_TOTAL_PAID DECIMAL(12,2),
    CHANGED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- STEP 2: Create statement-level trigger
-- =======================================

-- Create a temporary table to track affected loans (session-level)
CREATE TEMP TABLE IF NOT EXISTS affected_loans_temp (
    loan_id INT PRIMARY KEY
) ON COMMIT DELETE ROWS;

-- Row-level trigger to collect affected loans
CREATE OR REPLACE FUNCTION public.TRG_LOAN_COLLECT_LOANS()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO affected_loans_temp (loan_id) VALUES (OLD.LOAN_ID) ON CONFLICT DO NOTHING;
        RETURN OLD;
    ELSE
        INSERT INTO affected_loans_temp (loan_id) VALUES (NEW.LOAN_ID) ON CONFLICT DO NOTHING;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Statement-level trigger to process collected loans
CREATE OR REPLACE FUNCTION public.TRG_LOAN_TOTAL_STMT_FUNC()
RETURNS TRIGGER AS $$
DECLARE
    v_loan_id INT;
    v_old_total DECIMAL(12,2);
    v_new_total DECIMAL(12,2);
BEGIN
    -- Process each affected loan exactly once
    FOR v_loan_id IN SELECT DISTINCT loan_id FROM affected_loans_temp
    LOOP
        -- Get old total
        SELECT COALESCE(TOTAL_PAID, 0) INTO v_old_total 
        FROM public.LOAN 
        WHERE LOAN_ID = v_loan_id;

        -- Recompute total from all current payments
        SELECT COALESCE(SUM(PAYMENT_AMOUNT), 0) INTO v_new_total 
        FROM public.LOAN_PAYMENT 
        WHERE LOAN_ID = v_loan_id;

        -- Update loan total
        UPDATE public.LOAN 
        SET TOTAL_PAID = v_new_total 
        WHERE LOAN_ID = v_loan_id;

        -- Insert audit record
        INSERT INTO public.LOAN_AUDIT (LOAN_ID, OLD_TOTAL_PAID, NEW_TOTAL_PAID) 
        VALUES (v_loan_id, v_old_total, v_new_total);
    END LOOP;

    -- Clear temp table
    DELETE FROM affected_loans_temp;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create two triggers: one to collect, one to process
DROP TRIGGER IF EXISTS TRG_LOAN_COLLECT ON public.LOAN_PAYMENT;
DROP TRIGGER IF EXISTS TRG_LOAN_TOTAL_STMT ON public.LOAN_PAYMENT;

CREATE TRIGGER TRG_LOAN_COLLECT
BEFORE INSERT OR UPDATE OR DELETE ON public.LOAN_PAYMENT
FOR EACH ROW
EXECUTE FUNCTION public.TRG_LOAN_COLLECT_LOANS();

CREATE TRIGGER TRG_LOAN_TOTAL_STMT
AFTER INSERT OR UPDATE OR DELETE ON public.LOAN_PAYMENT
FOR EACH STATEMENT
EXECUTE FUNCTION public.TRG_LOAN_TOTAL_STMT_FUNC();

-- STEP 3: Test script - Mixed DML operations
-- ===========================================

-- Create test loans (using sample member IDs from branch_kigali)
DO $$
DECLARE
    v_member_id INT;
BEGIN
    SELECT MemberID INTO v_member_id FROM branch_kigali.Member LIMIT 1;
    
    -- Create test loans
    INSERT INTO public.LOAN (MEMBER_ID, LOAN_AMOUNT, TOTAL_PAID) VALUES
    (v_member_id, 100000.00, 0),
    (v_member_id, 200000.00, 0),
    (v_member_id, 500000.00, 0);
END $$;

-- Test 1: INSERT batch (multiple payments for same loan)
INSERT INTO public.LOAN_PAYMENT (LOAN_ID, PAYMENT_AMOUNT, PAYMENT_METHOD) VALUES
(1, 10000.00, 'Cash'),
(1, 15000.00, 'Bank Transfer'),
(1, 5000.00, 'Mobile Money');

-- Check results after INSERT batch
SELECT 'After INSERT batch - Loan 1' AS Test, LOAN_ID, LOAN_AMOUNT, TOTAL_PAID, REMAINING_BALANCE 
FROM public.LOAN WHERE LOAN_ID = 1;

SELECT 'Audit records after INSERT' AS Test, LOAN_ID, OLD_TOTAL_PAID, NEW_TOTAL_PAID, CHANGED_AT 
FROM public.LOAN_AUDIT 
ORDER BY CHANGED_AT DESC 
LIMIT 3;

-- Test 2: UPDATE batch (modify existing payments)
UPDATE public.LOAN_PAYMENT SET PAYMENT_AMOUNT = 12000.00 WHERE LOAN_ID = 1 AND PAYMENT_AMOUNT = 10000.00;
UPDATE public.LOAN_PAYMENT SET PAYMENT_AMOUNT = 18000.00 WHERE LOAN_ID = 1 AND PAYMENT_AMOUNT = 15000.00;

-- Check results after UPDATE
SELECT 'After UPDATE batch - Loan 1' AS Test, LOAN_ID, LOAN_AMOUNT, TOTAL_PAID, REMAINING_BALANCE 
FROM public.LOAN WHERE LOAN_ID = 1;

-- Test 3: DELETE batch (remove some payments)
DELETE FROM public.LOAN_PAYMENT WHERE LOAN_ID = 1 AND PAYMENT_AMOUNT = 5000.00;

-- Check results after DELETE
SELECT 'After DELETE - Loan 1' AS Test, LOAN_ID, LOAN_AMOUNT, TOTAL_PAID, REMAINING_BALANCE 
FROM public.LOAN WHERE LOAN_ID = 1;

-- Test 4: Multiple loans in one statement
INSERT INTO public.LOAN_PAYMENT (LOAN_ID, PAYMENT_AMOUNT, PAYMENT_METHOD) VALUES
(2, 30000.00, 'Cash'),
(2, 40000.00, 'Bank Transfer'),
(3, 50000.00, 'Mobile Money'),
(3, 60000.00, 'Cash');

-- Check results for multiple loans
SELECT 'Multiple loans updated' AS Test, LOAN_ID, LOAN_AMOUNT, TOTAL_PAID, REMAINING_BALANCE 
FROM public.LOAN WHERE LOAN_ID IN (2, 3);

-- STEP 4: Final verification
-- ==========================

SELECT 
    'Final Verification - Loan Totals' AS Report,
    L.LOAN_ID,
    L.LOAN_AMOUNT,
    L.TOTAL_PAID AS STORED_TOTAL,
    COALESCE(SUM(P.PAYMENT_AMOUNT), 0) AS COMPUTED_TOTAL,
    L.REMAINING_BALANCE,
    CASE 
        WHEN L.TOTAL_PAID = COALESCE(SUM(P.PAYMENT_AMOUNT), 0) THEN 'CORRECT ✓'
        ELSE 'MISMATCH ✗'
    END AS STATUS
FROM public.LOAN L
LEFT JOIN public.LOAN_PAYMENT P ON L.LOAN_ID = P.LOAN_ID
GROUP BY L.LOAN_ID, L.LOAN_AMOUNT, L.TOTAL_PAID, L.REMAINING_BALANCE
ORDER BY L.LOAN_ID;

-- Display audit trail
SELECT 
    'Audit Trail Summary' AS Report,
    COUNT(*) AS Total_Audit_Records,
    COUNT(DISTINCT LOAN_ID) AS Loans_Audited
FROM public.LOAN_AUDIT;

-- Show recent audit records
SELECT 
    'Recent Audit Records' AS Report,
    AUDIT_ID,
    LOAN_ID,
    OLD_TOTAL_PAID,
    NEW_TOTAL_PAID,
    NEW_TOTAL_PAID - OLD_TOTAL_PAID AS CHANGE_AMOUNT,
    CHANGED_AT
FROM public.LOAN_AUDIT
ORDER BY CHANGED_AT DESC
LIMIT 10;

