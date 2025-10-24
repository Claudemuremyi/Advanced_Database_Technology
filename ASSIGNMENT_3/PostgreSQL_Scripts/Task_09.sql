-- ============================================================================
-- TASK 9: DISTRIBUTED QUERY OPTIMIZATION
-- ============================================================================
-- Desctiption: Analyze distributed joins using EXPLAIN PLAN, discuss optimizer
-- strategies, and demonstrate how data movement is minimized
-- ============================================================================

-- ============================================================================
-- STEP 1: Setup - Ensure statistics are up to date
-- ============================================================================

-- Analyze all tables for accurate query planning
ANALYZE branch_kigali.Member;
ANALYZE branch_kigali.Officer;
ANALYZE branch_kigali.LoanAccount;
ANALYZE branch_kigali.InsurancePolicy;
ANALYZE branch_musanze.Member;
ANALYZE branch_musanze.Officer;
ANALYZE branch_musanze.LoanAccount;
ANALYZE branch_musanze.InsurancePolicy;

-- ============================================================================
-- STEP 2: Simple local query optimization
-- ============================================================================

-- Query 1: Simple SELECT with filter (local query)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    MemberID,
    FullName,
    Contact,
    Branch
FROM branch_kigali.Member
WHERE JoinDate >= '2020-01-01'
ORDER BY JoinDate DESC;

-- Observation: Should use index scan if available, sequential scan otherwise

-- ============================================================================
-- STEP 3: Local join optimization
-- ============================================================================

-- Query 2: Join within single branch (local join)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    m.FullName AS MemberName,
    m.Contact,
    l.Amount AS LoanAmount,
    l.InterestRate,
    l.Status,
    o.FullName AS OfficerName
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON m.MemberID = l.MemberID
JOIN branch_kigali.Officer o ON l.OfficerID = o.OfficerID
WHERE l.Status = 'Active'
ORDER BY l.Amount DESC;

-- Observation: 
-- - Join order optimization
-- - Index usage on foreign keys
-- - Filter pushdown (Status = 'Active')

-- ============================================================================
-- STEP 4: Distributed query across branches (UNION)
-- ============================================================================

-- Query 3: Aggregate data from both branches
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    Branch,
    COUNT(*) AS TotalMembers,
    COUNT(DISTINCT Gender) AS GenderVariety,
    MIN(JoinDate) AS EarliestMember,
    MAX(JoinDate) AS LatestMember
FROM (
    SELECT MemberID, FullName, Gender, Branch, JoinDate FROM branch_kigali.Member
    UNION ALL
    SELECT MemberID, FullName, Gender, Branch, JoinDate FROM branch_musanze.Member
) AS all_members
GROUP BY Branch;

-- Observation:
-- - Append node combines data from both branches
-- - Aggregation performed after union
-- - Minimal data movement (only final results)

-- ============================================================================
-- STEP 5: Complex distributed join with aggregation
-- ============================================================================

-- Query 4: Loan portfolio analysis across all branches
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
WITH all_loans AS (
    SELECT 
        'Kigali' AS source_branch,
        l.LoanID,
        l.MemberID,
        l.Amount,
        l.InterestRate,
        l.Status,
        m.FullName AS MemberName,
        m.Gender
    FROM branch_kigali.LoanAccount l
    JOIN branch_kigali.Member m ON l.MemberID = m.MemberID
    
    UNION ALL
    
    SELECT 
        'Musanze' AS source_branch,
        l.LoanID,
        l.MemberID,
        l.Amount,
        l.InterestRate,
        l.Status,
        m.FullName AS MemberName,
        m.Gender
    FROM branch_musanze.LoanAccount l
    JOIN branch_musanze.Member m ON l.MemberID = m.MemberID
)
SELECT 
    source_branch,
    Status,
    Gender,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    AVG(InterestRate) AS AvgInterestRate
FROM all_loans
GROUP BY source_branch, Status, Gender
ORDER BY source_branch, Status;

-- Observation:
-- - CTE optimization
-- - Local joins before union (reduces data movement)
-- - Aggregation after combining data
-- - Efficient grouping strategy

-- ============================================================================
-- STEP 6: Subquery optimization
-- ============================================================================

-- Query 5: Members with multiple active loans (correlated subquery)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    m.MemberID,
    m.FullName,
    m.Branch,
    (SELECT COUNT(*) 
     FROM branch_kigali.LoanAccount l 
     WHERE l.MemberID = m.MemberID AND l.Status = 'Active') AS ActiveLoans,
    (SELECT SUM(Amount) 
     FROM branch_kigali.LoanAccount l 
     WHERE l.MemberID = m.MemberID AND l.Status = 'Active') AS TotalLoanAmount
FROM branch_kigali.Member m
WHERE EXISTS (
    SELECT 1 
    FROM branch_kigali.LoanAccount l 
    WHERE l.MemberID = m.MemberID AND l.Status = 'Active'
)
ORDER BY ActiveLoans DESC;

-- Better optimized version using JOIN
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    m.MemberID,
    m.FullName,
    m.Branch,
    COUNT(l.LoanID) AS ActiveLoans,
    SUM(l.Amount) AS TotalLoanAmount
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON m.MemberID = l.MemberID
WHERE l.Status = 'Active'
GROUP BY m.MemberID, m.FullName, m.Branch
ORDER BY ActiveLoans DESC;

-- Observation:
-- - JOIN version is more efficient than correlated subquery
-- - Single table scan instead of multiple
-- - Better use of indexes

-- ============================================================================
-- STEP 7: Partition-wise join simulation
-- ============================================================================

-- Query 6: Cross-branch member comparison
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS)
SELECT 
    k.FullName AS Kigali_Member,
    k.JoinDate AS Kigali_JoinDate,
    m.FullName AS Musanze_Member,
    m.JoinDate AS Musanze_JoinDate
FROM branch_kigali.Member k
FULL OUTER JOIN branch_musanze.Member m 
    ON k.Contact = m.Contact
WHERE k.MemberID IS NULL OR m.MemberID IS NULL;

-- Observation:
-- - Full outer join across branches
-- - Data movement required for join
-- - Hash join or merge join strategy

-- ============================================================================
-- STEP 8: Index usage analysis
-- ============================================================================

-- Query 7: Test index effectiveness
-- Without index hint
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM branch_kigali.LoanAccount WHERE Status = 'Active';

-- Create index if not exists
CREATE INDEX IF NOT EXISTS idx_kigali_loan_status ON branch_kigali.LoanAccount(Status);

-- With index
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM branch_kigali.LoanAccount WHERE Status = 'Active';

-- Observation:
-- - Compare sequential scan vs index scan
-- - Analyze buffer hits vs reads
-- - Cost comparison

-- ============================================================================
-- STEP 9: Materialized view for optimization
-- ============================================================================

-- Create materialized view for frequently accessed aggregated data
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_loan_summary AS
SELECT 
    'Kigali' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    AVG(InterestRate) AS AvgRate
FROM branch_kigali.LoanAccount
GROUP BY Status

UNION ALL

SELECT 
    'Musanze' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    AVG(InterestRate) AS AvgRate
FROM branch_musanze.LoanAccount
GROUP BY Status;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_mv_loan_branch_status ON public.mv_loan_summary(Branch, Status);

-- Query using materialized view (optimized)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM public.mv_loan_summary
WHERE Branch = 'Kigali' AND Status = 'Active';

-- Compare with original query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    'Kigali' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    AVG(InterestRate) AS AvgRate
FROM branch_kigali.LoanAccount
WHERE Status = 'Active'
GROUP BY Status;

-- Observation:
-- - Materialized view provides pre-computed results
-- - Significantly faster for complex aggregations
-- - Trade-off: storage vs query performance

-- ============================================================================
-- STEP 10: Query optimization techniques summary
-- ============================================================================

-- Create table to document optimization strategies
CREATE TABLE IF NOT EXISTS public.query_optimization_analysis (
    AnalysisID SERIAL PRIMARY KEY,
    QueryDescription TEXT NOT NULL,
    OptimizationTechnique TEXT NOT NULL,
    BeforeCost DECIMAL(10, 2),
    AfterCost DECIMAL(10, 2),
    ImprovementPercent DECIMAL(5, 2),
    Notes TEXT,
    AnalysisDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample optimization results
INSERT INTO public.query_optimization_analysis 
(QueryDescription, OptimizationTechnique, BeforeCost, AfterCost, ImprovementPercent, Notes) VALUES
('Member lookup by contact', 'Added index on Contact column', 125.50, 8.25, 93.43, 'Index scan vs sequential scan'),
('Loan aggregation query', 'Created materialized view', 450.75, 12.30, 97.27, 'Pre-computed aggregations'),
('Cross-branch member join', 'Optimized join order', 890.20, 345.60, 61.18, 'Smaller table as outer'),
('Correlated subquery', 'Converted to JOIN', 678.90, 156.40, 76.96, 'Single scan instead of multiple'),
('Distributed union query', 'Added WHERE clause pushdown', 567.30, 234.10, 58.74, 'Filter before union'),
('Complex aggregation', 'Used CTE for readability', 789.45, 723.20, 8.39, 'Slight improvement with better plan');

-- View optimization summary
SELECT 
    QueryDescription,
    OptimizationTechnique,
    BeforeCost,
    AfterCost,
    ImprovementPercent,
    CASE 
        WHEN ImprovementPercent >= 80 THEN 'Excellent'
        WHEN ImprovementPercent >= 50 THEN 'Good'
        WHEN ImprovementPercent >= 20 THEN 'Moderate'
        ELSE 'Minimal'
    END AS ImprovementRating
FROM public.query_optimization_analysis
ORDER BY ImprovementPercent DESC;

-- ============================================================================
-- DISTRIBUTED QUERY OPTIMIZATION SUMMARY
-- ============================================================================
/*
KEY OPTIMIZATION STRATEGIES:

1. MINIMIZE DATA MOVEMENT
   - Perform local joins before distributed operations
   - Use WHERE clause pushdown to filter early
   - Aggregate data locally before combining

2. INDEX OPTIMIZATION
   - Create indexes on frequently queried columns
   - Use composite indexes for multi-column queries
   - Maintain index statistics with ANALYZE

3. JOIN OPTIMIZATION
   - Choose appropriate join type (hash, merge, nested loop)
   - Optimize join order (smaller table first)
   - Use EXISTS instead of IN for subqueries

4. QUERY REWRITING
   - Convert correlated subqueries to JOINs
   - Use CTEs for complex queries
   - Eliminate redundant operations

5. MATERIALIZED VIEWS
   - Pre-compute expensive aggregations
   - Refresh strategy (immediate vs scheduled)
   - Index materialized views

6. PARALLEL EXECUTION
   - Enable parallel workers for large scans
   - Configure parallel_setup_cost appropriately
   - Monitor parallel efficiency

7. PARTITION PRUNING
   - Use partitioning for very large tables
   - Ensure queries include partition key
   - Leverage constraint exclusion

8. STATISTICS MAINTENANCE
   - Regular ANALYZE to update statistics
   - Adjust statistics targets for important columns
   - Monitor query plan changes

EXPLAIN PLAN INTERPRETATION:
- Seq Scan: Full table scan (expensive for large tables)
- Index Scan: Uses index (efficient for selective queries)
- Bitmap Index Scan: Combines multiple indexes
- Hash Join: Good for large equi-joins
- Merge Join: Efficient for sorted data
- Nested Loop: Best for small datasets
- Append: Combines results from multiple sources (UNION)
- Aggregate: Grouping and aggregation operations

COST METRICS:
- Startup Cost: Cost before first row is returned
- Total Cost: Cost to return all rows
- Rows: Estimated number of rows
- Width: Average row size in bytes
- Actual Time: Real execution time (with ANALYZE)
- Buffers: Shared blocks hit/read (with BUFFERS)
*/

-- ============================================================================
-- END OF DISTRIBUTED QUERY OPTIMIZATION
-- ============================================================================
