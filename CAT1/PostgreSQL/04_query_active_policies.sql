-- TASK 4: RETRIEVE ALL ACTIVE INSURANCE POLICIES
-- Shows policy details for Rwandan SACCO members
-- ================================================

-- Main query to retrieve all active insurance policies
SELECT 
    ip.PolicyID,
    m.MemberID,
    m.FullName AS MemberName,
    m.Contact,
    m.Address AS Location,
    ip.Type AS PolicyType,
    TO_CHAR(ip.Premium, 'FML999,999,999') || ' RWF' AS Premium,
    TO_CHAR(ip.StartDate, 'DD-Mon-YYYY') AS StartDate,
    TO_CHAR(ip.EndDate, 'DD-Mon-YYYY') AS EndDate,
    ip.Status,
    CASE 
        WHEN ip.EndDate < CURRENT_DATE THEN 'Expired (Update Needed)'
        WHEN ip.EndDate <= CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
        ELSE 'Active'
    END AS PolicyHealth
FROM 
    InsurancePolicy ip
INNER JOIN 
    Member m ON ip.MemberID = m.MemberID
WHERE 
    ip.Status = 'Active'
ORDER BY 
    ip.StartDate DESC;
