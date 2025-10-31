-- ============================================================================
-- TASK 10: PERFORMANCE BENCHMARK AND REPORT
-- ============================================================================
-- Goal: Run one complex query three ways – centralized, parallel, distributed –
-- and measure time and I/O using EXPLAIN (ANALYZE, BUFFERS, TIMING).
-- PostgreSQL alternative to AUTOTRACE is used below.
-- ============================================================================

-- Optional logging table for results
CREATE TABLE IF NOT EXISTS public.performance_benchmark_results (
    RunID SERIAL PRIMARY KEY,
    Mode VARCHAR(20) NOT NULL, -- Centralized | Parallel | Distributed | Dist+Parallel
    TotalTime_ms DECIMAL(12,2),
    RowsReturned BIGINT,
    RunTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ensure stats are up to date
ANALYZE branch_kigali.Member;
ANALYZE branch_kigali.LoanAccount;
ANALYZE branch_musanze.Member;
ANALYZE branch_musanze.LoanAccount;

-- 1) CENTRALIZED: Single-node (Kigali)
SET max_parallel_workers_per_gather = 0;
SELECT 'CENTRALIZED (Kigali only)' AS mode;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT m.Branch,
       COUNT(l.LoanID) AS LoanCount,
       SUM(l.Amount) AS TotalLoanAmount,
       ROUND(AVG(l.InterestRate), 2) AS AvgRate
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON l.MemberID = m.MemberID
WHERE l.Status = 'Active'
GROUP BY m.Branch;

-- 2) PARALLEL: Single-node with parallel workers
SET max_parallel_workers_per_gather = 4;
SELECT 'PARALLEL (Kigali only)' AS mode;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT m.Branch,
       COUNT(l.LoanID) AS LoanCount,
       SUM(l.Amount) AS TotalLoanAmount,
       ROUND(AVG(l.InterestRate), 2) AS AvgRate
FROM branch_kigali.Member m
JOIN branch_kigali.LoanAccount l ON l.MemberID = m.MemberID
WHERE l.Status = 'Active'
GROUP BY m.Branch;

-- 3) DISTRIBUTED: Combine results from both nodes (UNION ALL pattern)
SET max_parallel_workers_per_gather = 0; -- measure distributed without parallel first
SELECT 'DISTRIBUTED (Kigali + Musanze)' AS mode;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT Branch,
       COUNT(*) AS LoanCount,
       SUM(Amount) AS TotalLoanAmount,
       ROUND(AVG(InterestRate), 2) AS AvgRate
FROM (
    SELECT 'Kigali' AS Branch, l.LoanID, l.Amount, l.InterestRate
    FROM branch_kigali.LoanAccount l
    WHERE l.Status = 'Active'
    UNION ALL
    SELECT 'Musanze' AS Branch, l.LoanID, l.Amount, l.InterestRate
    FROM branch_musanze.LoanAccount l
    WHERE l.Status = 'Active'
) t
GROUP BY Branch
ORDER BY TotalLoanAmount DESC;

-- 4) DISTRIBUTED + PARALLEL: Enable parallel workers and compare
SET max_parallel_workers_per_gather = 4;
SELECT 'DISTRIBUTED + PARALLEL' AS mode;
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT Branch,
       COUNT(*) AS LoanCount,
       SUM(Amount) AS TotalLoanAmount,
       ROUND(AVG(InterestRate), 2) AS AvgRate
FROM (
    SELECT 'Kigali' AS Branch, l.LoanID, l.Amount, l.InterestRate
    FROM branch_kigali.LoanAccount l
    WHERE l.Status = 'Active'
    UNION ALL
    SELECT 'Musanze' AS Branch, l.LoanID, l.Amount, l.InterestRate
    FROM branch_musanze.LoanAccount l
    WHERE l.Status = 'Active'
) t
GROUP BY Branch
ORDER BY TotalLoanAmount DESC;

-- Reset settings
RESET max_parallel_workers_per_gather;
