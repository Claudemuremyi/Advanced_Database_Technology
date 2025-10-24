-- TASK 3: PARALLEL QUERY EXECUTION
-----------------------------------
-- Desctiption: Demonstrate PostgreSQL's parallel query capabilities
-- Compare serial vs parallel execution performance
---------------------------------------------------------------------

-- STEP 1: Check current parallel query settings
------------------------------------------------

-- Display current parallel query configuration
SELECT 
    name,
    setting,
    unit,
    short_desc
FROM pg_settings
WHERE name IN (
    'max_parallel_workers_per_gather',
    'max_parallel_workers',
    'max_worker_processes',
    'parallel_setup_cost',
    'parallel_tuple_cost',
    'min_parallel_table_scan_size'
)
ORDER BY name;

-- STEP 2: Configure parallel query settings for optimal performance
--------------------------------------------------------------------

-- Enable parallel query execution
SET max_parallel_workers_per_gather = 4;  -- Allow up to 4 parallel workers
SET parallel_setup_cost = 1000;           -- Cost of starting parallel workers
SET parallel_tuple_cost = 0.1;            -- Cost per tuple in parallel mode
SET min_parallel_table_scan_size = '8MB'; -- Minimum table size for parallel scan

-- Show updated settings
SHOW max_parallel_workers_per_gather;
SHOW parallel_setup_cost;

-- STEP 3: Create large dataset for parallel query testing
----------------------------------------------------------

-- Create a large table with insurance policy data
DROP TABLE IF EXISTS large_policy_dataset CASCADE;

CREATE TABLE large_policy_dataset AS
SELECT 
    generate_series(1, 100000) AS PolicyID,
    (random() * 100 + 1)::INT AS MemberID,
    (ARRAY['Life', 'Health', 'Property', 'Loan Protection', 'Accident'])[floor(random() * 5 + 1)] AS Type,
    (random() * 500000 + 50000)::DECIMAL(10, 2) AS Premium,
    CURRENT_DATE - (random() * 730)::INT AS StartDate,
    CURRENT_DATE + (random() * 365)::INT AS EndDate,
    (ARRAY['Active', 'Expired', 'Cancelled'])[floor(random() * 3 + 1)] AS Status;

-- Create indexes
CREATE INDEX idx_large_policy_status ON large_policy_dataset(Status);
CREATE INDEX idx_large_policy_type ON large_policy_dataset(Type);
CREATE INDEX idx_large_policy_premium ON large_policy_dataset(Premium);

-- Analyze table for query planner
ANALYZE large_policy_dataset;

-- Verify table size
SELECT 
    pg_size_pretty(pg_total_relation_size('large_policy_dataset')) AS table_size,
    COUNT(*) AS row_count
FROM large_policy_dataset;

-- STEP 4: SERIAL EXECUTION (Parallel disabled)
-----------------------------------------------

-- Disable parallel execution
SET max_parallel_workers_per_gather = 0;

-- Query 1: Aggregate query (SERIAL)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    Type,
    Status,
    COUNT(*) AS Policy_Count,
    SUM(Premium) AS Total_Premium,
    AVG(Premium) AS Avg_Premium,
    MIN(Premium) AS Min_Premium,
    MAX(Premium) AS Max_Premium
FROM large_policy_dataset
WHERE Status = 'Active'
GROUP BY Type, Status
ORDER BY Total_Premium DESC;

-- Query 2: Complex aggregation (SERIAL)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    COUNT(*) AS Total_Policies,
    SUM(Premium) AS Total_Premium,
    AVG(Premium) AS Average_Premium
FROM large_policy_dataset
WHERE Premium > 100000;

-- STEP 5: PARALLEL EXECUTION (Parallel enabled)
------------------------------------------------

-- Enable parallel execution
SET max_parallel_workers_per_gather = 4;

-- Query 1: Same aggregate query (PARALLEL)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    Type,
    Status,
    COUNT(*) AS Policy_Count,
    SUM(Premium) AS Total_Premium,
    AVG(Premium) AS Avg_Premium,
    MIN(Premium) AS Min_Premium,
    MAX(Premium) AS Max_Premium
FROM large_policy_dataset
WHERE Status = 'Active'
GROUP BY Type, Status
ORDER BY Total_Premium DESC;

-- Query 2: Same complex aggregation (PARALLEL)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    COUNT(*) AS Total_Policies,
    SUM(Premium) AS Total_Premium,
    AVG(Premium) AS Average_Premium
FROM large_policy_dataset
WHERE Premium > 100000;

-- STEP 6: Parallel join operations
-----------------------------------

-- Create another large table for join testing
DROP TABLE IF EXISTS large_member_dataset CASCADE;

CREATE TABLE large_member_dataset AS
SELECT 
    generate_series(1, 100) AS MemberID,
    'Member_' || generate_series(1, 100) AS FullName,
    (ARRAY['M', 'F'])[floor(random() * 2 + 1)]::CHAR(1) AS Gender,
    '+25078' || lpad((random() * 10000000)::TEXT, 7, '0') AS Contact,
    (ARRAY['Kigali', 'Musanze', 'Huye', 'Rubavu'])[floor(random() * 4 + 1)] AS Branch;

ANALYZE large_member_dataset;

-- Parallel join query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    m.Branch,
    COUNT(p.PolicyID) AS Total_Policies,
    SUM(p.Premium) AS Total_Premium,
    AVG(p.Premium) AS Avg_Premium
FROM large_member_dataset m
INNER JOIN large_policy_dataset p ON m.MemberID = p.MemberID
WHERE p.Status = 'Active'
GROUP BY m.Branch
ORDER BY Total_Premium DESC;

-- STEP 7: Parallel sequential scan demonstration
-------------------------------------------------

-- Force sequential scan with parallel workers
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    Type,
    COUNT(*) AS Count,
    SUM(Premium) AS Total
FROM large_policy_dataset
WHERE Premium BETWEEN 100000 AND 300000
GROUP BY Type;

-- Re-enable index scans
SET enable_indexscan = on;
SET enable_bitmapscan = on;

-- STEP 8: Performance comparison summary
-----------------------------------------

-- Create a summary view of parallel vs serial performance
CREATE OR REPLACE VIEW vw_parallel_performance_summary AS
SELECT 
    'Parallel Query Execution' AS Feature,
    'Enabled' AS Status,
    current_setting('max_parallel_workers_per_gather') AS Max_Workers,
    pg_size_pretty(pg_total_relation_size('large_policy_dataset')) AS Dataset_Size,
    (SELECT COUNT(*) FROM large_policy_dataset) AS Row_Count;

SELECT * FROM vw_parallel_performance_summary;

-- STEP 9: Real-world SACCO parallel query examples
----------------------------------------------------

-- Parallel query on distributed branches
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    'Kigali' AS Branch,
    COUNT(*) AS Total_Loans,
    SUM(Amount) AS Total_Amount
FROM branch_kigali.LoanAccount
UNION ALL
SELECT 
    'Musanze',
    COUNT(*),
    SUM(Amount)
FROM branch_musanze.LoanAccount;
