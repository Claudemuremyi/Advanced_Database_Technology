-- TASK 6: IDENTIFY MEMBERS WITH MULTIPLE INSURANCE POLICIES
-- Lists SACCO members who have more than one insurance policy
-- ============================================================================

-- Query showing members with multiple policies
SELECT 
    m.MemberID,
    m.FullName,
    m.Contact,
    m.Address AS Location,
    COUNT(ip.PolicyID) AS TotalPolicies,
    TO_CHAR(SUM(ip.Premium), 'FML999,999,999') || ' RWF' AS TotalPremiumAmount,
    STRING_AGG(ip.Type, ', ' ORDER BY ip.Type) AS PolicyTypes
FROM 
    Member m
INNER JOIN 
    InsurancePolicy ip ON m.MemberID = ip.MemberID
GROUP BY 
    m.MemberID, m.FullName, m.Contact, m.Address
HAVING 
    COUNT(ip.PolicyID) > 1
ORDER BY 
    TotalPolicies DESC, m.FullName;
