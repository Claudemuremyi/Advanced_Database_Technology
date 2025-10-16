-- Drop views if they exist (for clean execution)
DROP VIEW IF EXISTS vw_MonthlyPremiumCollection;
DROP VIEW IF EXISTS vw_MonthlyPremiumSummary;
DROP VIEW IF EXISTS vw_YearlyPremiumComparison;

-- View 1: Monthly Premium Collection
CREATE VIEW vw_MonthlyPremiumCollection AS
SELECT 
    EXTRACT(YEAR FROM ip.StartDate) AS Year,
    EXTRACT(MONTH FROM ip.StartDate) AS Month,
    TO_CHAR(ip.StartDate, 'Month YYYY') AS MonthYear,
    COUNT(ip.PolicyID) AS TotalPolicies,
    COUNT(DISTINCT ip.MemberID) AS UniqueMembersInsured,
    SUM(ip.Premium) AS TotalPremiumCollected,
    AVG(ip.Premium) AS AveragePremium,
    MIN(ip.Premium) AS MinimumPremium,
    MAX(ip.Premium) AS MaximumPremium,
    STRING_AGG(DISTINCT ip.Type, ', ') AS PolicyTypes
FROM 
    InsurancePolicy ip
WHERE 
    ip.Status IN ('Active', 'Expired')
GROUP BY 
    EXTRACT(YEAR FROM ip.StartDate),
    EXTRACT(MONTH FROM ip.StartDate),
    TO_CHAR(ip.StartDate, 'Month YYYY')
ORDER BY 
    Year DESC, Month DESC;

-- View 2: Monthly Premium Summary
CREATE VIEW vw_MonthlyPremiumSummary AS
SELECT 
    TO_CHAR(ip.StartDate, 'YYYY-MM') AS YearMonth,
    TO_CHAR(ip.StartDate, 'Month YYYY') AS Period,
    COUNT(ip.PolicyID) AS PoliciesIssued,
    SUM(ip.Premium) AS TotalPremium,
    AVG(ip.Premium) AS AvgPremium,
    ROUND(
        (SUM(ip.Premium) * 100.0 / 
        SUM(SUM(ip.Premium)) OVER ()), 2
    ) AS PercentageOfTotal
FROM 
    InsurancePolicy ip
WHERE 
    ip.Status IN ('Active', 'Expired')
GROUP BY 
    TO_CHAR(ip.StartDate, 'YYYY-MM'),
    TO_CHAR(ip.StartDate, 'Month YYYY')
ORDER BY 
    YearMonth DESC;

-- View 3: Yearly Premium Comparison
CREATE VIEW vw_YearlyPremiumComparison AS
SELECT 
    EXTRACT(YEAR FROM ip.StartDate) AS Year,
    COUNT(ip.PolicyID) AS TotalPolicies,
    SUM(ip.Premium) AS TotalPremium,
    AVG(ip.Premium) AS AveragePremium,
    COUNT(DISTINCT ip.MemberID) AS UniqueMembers
FROM 
    InsurancePolicy ip
GROUP BY 
    EXTRACT(YEAR FROM ip.StartDate)
ORDER BY 
    Year DESC;
	

-- VIEWS QUERY - Display the Results from Created Views
-- ====================================================

-- View 1: Monthly Premium Collection (detailed)
SELECT * FROM vw_MonthlyPremiumCollection;

-- View 2: Monthly Premium Summary (formatted)
SELECT * FROM vw_MonthlyPremiumSummary;

-- View 3: Yearly Premium Comparison
SELECT * FROM vw_YearlyPremiumComparison;

-- Optional: Query specific months or years
-- =========================================

-- Show only 2023 data
SELECT * FROM vw_MonthlyPremiumCollection 
WHERE Year = 2023;

-- Show highest premium collection month
SELECT * FROM vw_MonthlyPremiumCollection 
ORDER BY TotalPremiumCollected DESC 
LIMIT 1;

