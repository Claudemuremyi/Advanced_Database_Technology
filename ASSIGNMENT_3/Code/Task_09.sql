-- ============================================================================
-- TASK 9: DISTRIBUTED QUERY OPTIMIZATION (SIMPLIFIED FOR BEGINNERS)
-- ============================================================================
-- Goal: Learn how to optimize distributed queries using EXPLAIN ANALYZE
-- Key Skills: Index creation, join optimization, data movement reduction
-- ============================================================================

-- ============================================================================
-- SETUP: Update Table Statistics (Always run first!)
-- ============================================================================
-- WHY? PostgreSQL uses statistics to choose the best query plan
ANALYZE branch_kigali.Member;
ANALYZE branch_kigali.Officer;
ANALYZE branch_kigali.LoanAccount;
ANALYZE branch_musanze.Member;
ANALYZE branch_musanze.LoanAccount;

-- ============================================================================
-- OPTIMIZATION 1: INDEX ON FILTER COLUMN
-- ============================================================================
-- Scenario: Find recent members

-- BEFORE: No index (Sequential Scan - reads entire table)
EXPLAIN (ANALYZE, BUFFERS)
SELECT MemberID, FullName, Contact, Branch
FROM branch_kigali.Member
WHERE JoinDate >= '2020-01-01'
ORDER BY JoinDate DESC;

-- Look for: "Seq Scan" and high "Total Cost"

-- CREATE INDEX for optimization
CREATE INDEX IF NOT EXISTS idx_kigali_member_joindate 
ON branch_kigali.Member(JoinDate DESC);

CREATE INDEX IF NOT EXISTS idx_musanze_member_joindate 
ON branch_musanze.Member(JoinDate DESC);

-- AFTER: With index (Index Scan - reads only relevant rows)
EXPLAIN (ANALYZE, BUFFERS)
SELECT MemberID, FullName, Contact, Branch
FROM branch_kigali.Member
WHERE JoinDate >= '2020-01-01'
ORDER BY JoinDate DESC;

-- Look for: "Index Scan using idx_kigali_member_joindate"
-- Expected: 70-90% cost reduction

-- ✓ WHY BETTER: Index allows direct access to rows matching the date filter
-- ✓ BONUS: Index already sorted DESC, so no sort step needed!

-- ============================================================================
-- OPTIMIZATION 2: FILTER PUSHDOWN (Filter Early)
-- ============================================================================
-- Scenario: Get active loans with member and officer details

-- BEFORE: Filter after all joins (more rows to join)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    m.FullName AS MemberName,
    l.Amount AS LoanAmount,
    l.InterestRate,
    o.FullName AS OfficerName
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON m.MemberID = l.MemberID
JOIN branch_kigali.Officer o ON l.OfficerID = o.OfficerID
WHERE l.Status = 'Active'
ORDER BY l.Amount DESC;

-- OPTIMIZED: Filter first, then join (fewer rows to process)
CREATE INDEX IF NOT EXISTS idx_loan_status_amount 
ON branch_kigali.LoanAccount(Status, Amount DESC);

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    m.FullName AS MemberName,
    l.Amount AS LoanAmount,
    l.InterestRate,
    o.FullName AS OfficerName
FROM branch_kigali.LoanAccount l              -- Start with filtered table
JOIN branch_kigali.Member m ON l.MemberID = m.MemberID
JOIN branch_kigali.Officer o ON l.OfficerID = o.OfficerID
WHERE l.Status = 'Active'
ORDER BY l.Amount DESC
LIMIT 50;  -- Add LIMIT for even faster results

-- ✓ WHY BETTER: 
--   - Index on Status filters loans first
--   - Smaller result set flows through joins
--   - LIMIT stops processing early
-- Expected: 60-80% cost reduction

-- ============================================================================
-- OPTIMIZATION 3: LOCAL AGGREGATION BEFORE UNION
-- ============================================================================
-- Scenario: Count members per branch

-- INEFFICIENT: Move all rows, then aggregate
EXPLAIN (ANALYZE, BUFFERS)
SELECT Branch, COUNT(*) AS TotalMembers
FROM (
    SELECT Branch FROM branch_kigali.Member
    UNION ALL
    SELECT Branch FROM branch_musanze.Member
) AS all_members
GROUP BY Branch;

-- OPTIMIZED: Aggregate locally first, then combine
EXPLAIN (ANALYZE, BUFFERS)
SELECT Branch, SUM(MemberCount) AS TotalMembers
FROM (
    SELECT 'Kigali' AS Branch, COUNT(*) AS MemberCount
    FROM branch_kigali.Member
    
    UNION ALL
    
    SELECT 'Musanze' AS Branch, COUNT(*) AS MemberCount
    FROM branch_musanze.Member
) AS branch_counts
GROUP BY Branch;

-- ✓ WHY BETTER: 
--   - Moves only 2 rows (1 per branch) instead of thousands
--   - Network traffic reduced by 99%
--   - Distributed systems benefit: Each branch counts its own data
-- Expected: 95%+ reduction in data movement

-- ============================================================================
-- OPTIMIZATION 4: LOCAL JOINS BEFORE UNION (Critical for distributed DBs)
-- ============================================================================
-- Scenario: Loan analysis across all branches

-- This is ALREADY OPTIMIZED - follow this pattern!
EXPLAIN (ANALYZE, BUFFERS)
WITH branch_loans AS (
    -- Join locally in Kigali
    SELECT 
        'Kigali' AS Branch,
        l.Status,
        m.Gender,
        l.Amount,
        l.InterestRate
    FROM branch_kigali.LoanAccount l
    JOIN branch_kigali.Member m ON l.MemberID = m.MemberID
    
    UNION ALL
    
    -- Join locally in Musanze
    SELECT 
        'Musanze' AS Branch,
        l.Status,
        m.Gender,
        l.Amount,
        l.InterestRate
    FROM branch_musanze.LoanAccount l
    JOIN branch_musanze.Member m ON l.MemberID = m.MemberID
)
SELECT 
    Branch,
    Status,
    Gender,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    ROUND(AVG(Amount), 2) AS AvgAmount,
    ROUND(AVG(InterestRate), 2) AS AvgRate
FROM branch_loans
GROUP BY Branch, Status, Gender
ORDER BY Branch, TotalAmount DESC;

-- ✓ WHY THIS IS OPTIMAL:
--   1. Joins happen locally (no cross-branch join overhead)
--   2. UNION ALL combines already-joined results
--   3. Final aggregation on smaller dataset
--   4. CTE makes query readable and maintainable

-- ============================================================================
-- OPTIMIZATION 5: CORRELATED SUBQUERY → JOIN (Major Performance Win)
-- ============================================================================
-- Scenario: Members with their active loan count

-- SLOW: Correlated subquery (scans LoanAccount for EVERY member)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    m.MemberID,
    m.FullName,
    m.Branch,
    (SELECT COUNT(*) 
     FROM branch_kigali.LoanAccount l 
     WHERE l.MemberID = m.MemberID AND l.Status = 'Active') AS ActiveLoans,
    (SELECT COALESCE(SUM(Amount), 0)
     FROM branch_kigali.LoanAccount l 
     WHERE l.MemberID = m.MemberID AND l.Status = 'Active') AS TotalLoanAmount
FROM branch_kigali.Member m
WHERE EXISTS (
    SELECT 1 
    FROM branch_kigali.LoanAccount l 
    WHERE l.MemberID = m.MemberID AND l.Status = 'Active'
)
ORDER BY ActiveLoans DESC;

-- Look for: "SubPlan" nodes in execution plan (BAD - indicates repeated scans)

-- FAST: Single JOIN with aggregation
CREATE INDEX IF NOT EXISTS idx_loan_member_status 
ON branch_kigali.LoanAccount(MemberID, Status);

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    m.MemberID,
    m.FullName,
    m.Branch,
    COUNT(l.LoanID) AS ActiveLoans,
    COALESCE(SUM(l.Amount), 0) AS TotalLoanAmount
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON m.MemberID = l.MemberID
WHERE l.Status = 'Active'
GROUP BY m.MemberID, m.FullName, m.Branch
ORDER BY ActiveLoans DESC;

-- Look for: "Hash Join" or "Merge Join" (GOOD - single scan)

-- ✓ WHY BETTER:
--   - Scans LoanAccount once (not N times for N members)
--   - Hash join is much faster than repeated lookups
--   - Index on (MemberID, Status) speeds up the join
-- Expected: 70-85% faster

-- ============================================================================
-- OPTIMIZATION 6: INDEX SELECTIVITY TEST
-- ============================================================================
-- Rule of thumb: Index is useful if it filters to <20% of rows

-- Create index on Status column
CREATE INDEX IF NOT EXISTS idx_kigali_loan_status 
ON branch_kigali.LoanAccount(Status);

CREATE INDEX IF NOT EXISTS idx_musanze_loan_status 
ON branch_musanze.LoanAccount(Status);

-- Test: Will PostgreSQL use the index?
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM branch_kigali.LoanAccount WHERE Status = 'Active';

-- If "Index Scan" → Index is selective (Status has few Active loans)
-- If "Seq Scan" → Index not selective (Status has many Active loans)
-- PostgreSQL automatically chooses the cheaper method!

-- ✓ LEARNING POINT: Indexes aren't always used - and that's OK!
--   If >20% rows match, Seq Scan is actually faster

-- ============================================================================
-- OPTIMIZATION 7: MATERIALIZED VIEW (Pre-compute Expensive Queries)
-- ============================================================================
-- Use case: Dashboard that runs same aggregation query repeatedly

-- Create materialized view (runs aggregation once, stores result)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_loan_summary AS
SELECT 
    'Kigali' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    ROUND(AVG(Amount), 2) AS AvgAmount,
    ROUND(AVG(InterestRate), 2) AS AvgRate
FROM branch_kigali.LoanAccount
GROUP BY Status

UNION ALL

SELECT 
    'Musanze' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    ROUND(AVG(Amount), 2) AS AvgAmount,
    ROUND(AVG(InterestRate), 2) AS AvgRate
FROM branch_musanze.LoanAccount
GROUP BY Status;

-- Index the materialized view for fast lookups
CREATE INDEX IF NOT EXISTS idx_mv_loan_summary 
ON mv_loan_summary(Branch, Status);

-- QUERY 1: Using materialized view (SUPER FAST - no aggregation)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_loan_summary
WHERE Branch = 'Kigali' AND Status = 'Active';

-- QUERY 2: Original query (SLOW - aggregates every time)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    'Kigali' AS Branch,
    Status,
    COUNT(*) AS LoanCount,
    SUM(Amount) AS TotalAmount,
    ROUND(AVG(Amount), 2) AS AvgAmount,
    ROUND(AVG(InterestRate), 2) AS AvgRate
FROM branch_kigali.LoanAccount
WHERE Status = 'Active'
GROUP BY Status;

-- ✓ WHY BETTER:
--   - Materialized view: Simple index lookup (cost: ~10-20)
--   - Original query: Full aggregation (cost: ~500-1000)
--   - 95-99% faster for repeated queries

-- ⚠️ TRADE-OFF: Must refresh periodically
REFRESH MATERIALIZED VIEW mv_loan_summary;  -- Run when data changes

-- ============================================================================
-- OPTIMIZATION 8: UNION ALL vs UNION
-- ============================================================================
-- Rule: Use UNION ALL unless you NEED to remove duplicates

-- FAST: UNION ALL (no duplicate check)
EXPLAIN (ANALYZE, BUFFERS)
SELECT MemberID, FullName, 'Kigali' AS Branch
FROM branch_kigali.Member
UNION ALL
SELECT MemberID, FullName, 'Musanze' AS Branch
FROM branch_musanze.Member;

-- SLOW: UNION (sorts and removes duplicates)
EXPLAIN (ANALYZE, BUFFERS)
SELECT MemberID, FullName, 'Kigali' AS Branch
FROM branch_kigali.Member
UNION  -- Adds "Sort" + "Unique" step
SELECT MemberID, FullName, 'Musanze' AS Branch
FROM branch_musanze.Member;

-- ✓ WHY BETTER: UNION ALL skips expensive sort/unique operations
-- Expected: 15-30% faster for large result sets

-- ============================================================================
-- OPTIMIZATION 9: CREATE SUPPORTING INDEXES
-- ============================================================================
-- Add indexes for common join and filter patterns

-- Foreign key indexes (speed up joins)
CREATE INDEX IF NOT EXISTS idx_kigali_loan_memberid 
ON branch_kigali.LoanAccount(MemberID);

CREATE INDEX IF NOT EXISTS idx_kigali_loan_officerid 
ON branch_kigali.LoanAccount(OfficerID);

CREATE INDEX IF NOT EXISTS idx_musanze_loan_memberid 
ON branch_musanze.LoanAccount(MemberID);

CREATE INDEX IF NOT EXISTS idx_musanze_loan_officerid 
ON branch_musanze.LoanAccount(OfficerID);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_member_branch_joindate 
ON branch_kigali.Member(Branch, JoinDate DESC);

CREATE INDEX IF NOT EXISTS idx_loan_status_amount 
ON branch_kigali.LoanAccount(Status, Amount DESC);

-- ✓ BEST PRACTICE: Index foreign keys and frequently filtered columns

-- ============================================================================
-- PERFORMANCE COMPARISON TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS query_optimization_results (
    ID SERIAL PRIMARY KEY,
    QueryType VARCHAR(60),
    Technique VARCHAR(100),
    BeforeCost DECIMAL(10,2),
    AfterCost DECIMAL(10,2),
    ImprovementPct DECIMAL(5,1),
    Explanation TEXT
);

-- Insert your actual EXPLAIN results here (replace with real costs)
INSERT INTO query_optimization_results 
(QueryType, Technique, BeforeCost, AfterCost, ImprovementPct, Explanation) VALUES
('Filtered SELECT', 'Index on JoinDate', 125.50, 8.25, 93.4, 'Index scan vs seq scan'),
('Multi-table JOIN', 'Filter pushdown + index', 450.75, 89.30, 80.2, 'Reduced rows before join'),
('Correlated subquery', 'Convert to JOIN', 678.90, 156.40, 77.0, 'Single scan vs N scans'),
('Distributed aggregation', 'Local agg before UNION', 1250.00, 15.50, 98.8, 'Minimal data movement'),
('Complex aggregation', 'Materialized view', 890.20, 12.30, 98.6, 'Pre-computed results'),
('Cross-branch query', 'UNION ALL vs UNION', 234.50, 187.20, 20.2, 'No deduplication needed'),
('Local join', 'Join locally before UNION', 1100.00, 420.00, 61.8, 'Avoided cross-branch join');

-- View results sorted by improvement
SELECT 
    QueryType,
    Technique,
    BeforeCost,
    AfterCost,
    ImprovementPct || '%' AS Improvement,
    CASE 
        WHEN ImprovementPct >= 90 THEN 'Excellent'
        WHEN ImprovementPct >= 70 THEN 'Very Good'
        WHEN ImprovementPct >= 50 THEN 'Good'
        ELSE 'Moderate'
    END AS Rating
FROM query_optimization_results
ORDER BY ImprovementPct DESC;

-- ============================================================================
-- KEY TAKEAWAYS FOR LAB REPORT
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────┐
│ TOP 5 OPTIMIZATION TECHNIQUES (Ordered by Impact)                      │
├─────────────────────────────────────────────────────────────────────────┤
│ 1. LOCAL AGGREGATION BEFORE UNION (95-99% improvement)                 │
│    • Aggregate at each branch, then combine results                    │
│    • Reduces network traffic by 95%+                                   │
│    • Example: COUNT locally, then SUM the counts                       │
│                                                                         │
│ 2. MATERIALIZED VIEWS (90-99% improvement)                             │
│    • Pre-compute expensive aggregations                                │
│    • Trade storage for query speed                                     │
│    • Refresh periodically: REFRESH MATERIALIZED VIEW                   │
│                                                                         │
│ 3. INDEX ON FILTER COLUMNS (70-95% improvement)                        │
│    • Index columns in WHERE, JOIN, and ORDER BY                        │
│    • Most impactful: date ranges, foreign keys, status fields         │
│    • Remember: Index only helps if query is selective (<20% rows)     │
│                                                                         │
│ 4. CORRELATED SUBQUERY → JOIN (70-85% improvement)                     │
│    • Joins scan tables once vs. N times for subqueries                │
│    • Use GROUP BY for aggregations                                     │
│    • Always prefer JOIN over EXISTS in SELECT list                     │
│                                                                         │
│ 5. LOCAL JOINS BEFORE UNION (60-80% improvement)                       │
│    • Join within each branch, then UNION results                       │
│    • Avoids expensive cross-branch joins                               │
│    • Pattern: Local JOIN → UNION ALL → Final aggregation              │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ HOW TO READ EXPLAIN ANALYZE OUTPUT                                      │
├─────────────────────────────────────────────────────────────────────────┤
│ Seq Scan         → Full table scan (slow for large tables)             │
│ Index Scan       → Uses index (fast if selective)                      │
│ Bitmap Scan      → Combines multiple indexes                           │
│ Hash Join        → Good for large equi-joins                           │
│ Merge Join       → Efficient for pre-sorted data                       │
│ Nested Loop      → Best when inner table is small                      │
│ Append           → UNION ALL results                                   │
│ Aggregate        → GROUP BY operations                                 │
│ Sort             → ORDER BY operations (expensive!)                    │
│                                                                         │
│ COST METRICS:                                                           │
│ • Total Cost: Lower = faster (focus on this)                           │
│ • Actual Time: Real execution time in milliseconds                     │
│ • Rows: Number of rows processed                                       │
│ • Buffers Hit: Data found in cache (fast)                              │
│ • Buffers Read: Data read from disk (slow)                             │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ DISTRIBUTED DATABASE BEST PRACTICES                                     │
├─────────────────────────────────────────────────────────────────────────┤
│ ✓ Minimize data movement between nodes                                 │
│ ✓ Filter data as early as possible (WHERE pushdown)                    │
│ ✓ Aggregate locally before combining results                           │
│ ✓ Join within same node/schema when possible                           │
│ ✓ Use UNION ALL instead of UNION (unless duplicates matter)            │
│ ✓ Index foreign keys and frequently filtered columns                   │
│ ✓ Run ANALYZE after data changes                                       │
│ ✓ Use materialized views for repeated complex queries                  │
└─────────────────────────────────────────────────────────────────────────┘
*/

-- ============================================================================
-- INSTRUCTIONS FOR YOUR LAB REPORT
-- ============================================================================
/*
1. RUN each query pair (before/after optimization)
2. COPY the "Total Cost" from EXPLAIN output
3. CALCULATE improvement: ((Before - After) / Before) × 100
4. UPDATE the query_optimization_results table with YOUR actual results
5. SCREENSHOT the EXPLAIN plans showing optimization (e.g., Seq Scan → Index Scan)
6. WRITE a brief explanation of why each optimization worked

EXAMPLE ANALYSIS FOR REPORT:
"Query 5 originally used correlated subqueries, resulting in a total cost 
of 678.90. By converting to a single JOIN with GROUP BY, the cost reduced 
to 156.40—a 77% improvement. The execution plan shows the optimizer changed 
from multiple SubPlan nodes to a single Hash Join, scanning the LoanAccount 
table once instead of once per member."
*/

-- ============================================================================
-- END OF TASK 9: DISTRIBUTED QUERY OPTIMIZATION
-- ============================================================================