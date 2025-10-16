-- Task 3: RETRIEVE ALL ACTIVE INSURANCE POLICIES
-- Display policy details for Rwandan SACCO members
-- =================================================

SELECT 
    ip.PolicyID,
    m.MemberID,
    m.FullName AS MemberName,
    m.Contact,
    ip.Type AS PolicyType,
    TO_CHAR(ip.Premium, 'FML999,999,999') || ' RWF' AS Premium,
    ip.StartDate,
    ip.EndDate,
    ip.Status,
    EXTRACT(YEAR FROM AGE(ip.EndDate, ip.StartDate)) * 12 + 
    EXTRACT(MONTH FROM AGE(ip.EndDate, ip.StartDate)) AS DurationMonths
FROM 
    InsurancePolicy ip
INNER JOIN 
    Member m ON ip.MemberID = m.MemberID
WHERE 
    ip.Status = 'Active'
ORDER BY 
    ip.StartDate DESC;
