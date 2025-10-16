-- Task 4: UPDATE CLAIM STATUS AFTER SETTLEMENT
-- Updates claim status to 'Settled' when payment is processed
-- ============================================================
-- Update all approved claims that have received payment
UPDATE Claim
SET Status = 'Settled'
WHERE ClaimID IN (
    SELECT c.ClaimID
    FROM Claim c
    INNER JOIN Payment p ON c.ClaimID = p.ClaimID
    WHERE c.Status = 'Approved'
);
SELECT * from Claim;
