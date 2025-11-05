-- Drop trigers if they exist (for clean execution)
DROP TRIGGER IF EXISTS trg_AutoExpirePolicy ON InsurancePolicy;
DROP FUNCTION IF EXISTS fn_AutoExpirePolicy();
DROP FUNCTION IF EXISTS sp_ExpireOldPolicies();

-- STEP 5: TRIGGER THAT AUTOMATICALLY CLOSES POLICY UPON END DATE
-- ==============================================================

-- Create trigger function
CREATE OR REPLACE FUNCTION fn_AutoExpirePolicy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.EndDate <= CURRENT_DATE AND NEW.Status = 'Active' THEN
        NEW.Status := 'Expired';
        RAISE NOTICE 'Policy % for Member % has been automatically expired on %', 
                     NEW.PolicyID, NEW.MemberID, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trg_AutoExpirePolicy
BEFORE INSERT OR UPDATE ON InsurancePolicy
FOR EACH ROW
EXECUTE FUNCTION fn_AutoExpirePolicy();

-- Create stored procedure for batch expiration
CREATE OR REPLACE FUNCTION sp_ExpireOldPolicies()
RETURNS TABLE(
    PolicyID INT,
    MemberID INT,
    PolicyType VARCHAR,
    EndDate DATE,
    OldStatus VARCHAR,
    NewStatus VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    UPDATE InsurancePolicy ip
    SET Status = 'Expired'
    WHERE ip.EndDate < CURRENT_DATE 
      AND ip.Status = 'Active'
    RETURNING 
        ip.PolicyID,
        ip.MemberID,
        ip.Type,
        ip.EndDate,
        'Active'::VARCHAR AS OldStatus,
        ip.Status AS NewStatus;
END;
$$ LANGUAGE plpgsql;

-- Commit transaction
COMMIT;

--=========================
-- TRIGER TESTING QUERIES
-- ========================
-- Triger testing query when doesn't meet the condition
UPDATE InsurancePolicy
SET Premium = '500000'
WHERE PolicyID = 6 AND Type = 'Life';

-- Triger testing query when meet the condition 
UPDATE InsurancePolicy
SET Premium = '100000'
WHERE PolicyID = 3 AND MemberID = 2;

-- Insert expired policy (should auto-expire)
INSERT INTO InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
VALUES (1, 'Health', 180000.00, '2022-01-01', '2023-01-01', 'Active');

-- Retrieve all from InsurancePolicy table 
SELECT * from InsurancePolicy;
