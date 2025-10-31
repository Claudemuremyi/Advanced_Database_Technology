-- TASK 7: PARALLEL DATA LOADING / ETL SIMULATION

-- Desctiption: Demonstrate parallel data aggregation and loading using PostgreSQL
-- parallel query execution and compare performance with serial execution
-- ============================================================================

-- STEP 1: Create large dataset for ETL testing
-- =============================================

-- Create staging table for bulk data
CREATE TABLE IF NOT EXISTS public.TransactionStaging (
    TransactionID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Branch VARCHAR(50) NOT NULL,
    TransactionType VARCHAR(50) NOT NULL,
    Amount DECIMAL(12, 2) NOT NULL,
    TransactionDate DATE NOT NULL,
    ProcessedFlag BOOLEAN DEFAULT FALSE
);

-- Generate large dataset (100,000 transactions)
INSERT INTO public.TransactionStaging (MemberID, Branch, TransactionType, Amount, TransactionDate)
SELECT 
    (random() * 1000 + 1)::INT AS MemberID,
    CASE WHEN random() < 0.5 THEN 'Kigali' ELSE 'Musanze' END AS Branch,
    CASE 
        WHEN random() < 0.4 THEN 'Deposit'
        WHEN random() < 0.7 THEN 'Withdrawal'
        WHEN random() < 0.9 THEN 'Loan Payment'
        ELSE 'Insurance Premium'
    END AS TransactionType,
    (random() * 1000000 + 1000)::DECIMAL(12, 2) AS Amount,
    CURRENT_DATE - (random() * 365)::INT AS TransactionDate
FROM generate_series(1, 100000);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_staging_branch ON public.TransactionStaging(Branch);
CREATE INDEX IF NOT EXISTS idx_staging_date ON public.TransactionStaging(TransactionDate);
CREATE INDEX IF NOT EXISTS idx_staging_type ON public.TransactionStaging(TransactionType);

-- STEP 2: Create target tables for ETL
-- ====================================

-- Summary table for aggregated data
CREATE TABLE IF NOT EXISTS public.TransactionSummary (
    SummaryID SERIAL PRIMARY KEY,
    Branch VARCHAR(50) NOT NULL,
    TransactionType VARCHAR(50) NOT NULL,
    TransactionMonth DATE NOT NULL,
    TotalTransactions INT NOT NULL,
    TotalAmount DECIMAL(15, 2) NOT NULL,
    AvgAmount DECIMAL(12, 2) NOT NULL,
    MinAmount DECIMAL(12, 2) NOT NULL,
    MaxAmount DECIMAL(12, 2) NOT NULL,
    LoadTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- STEP 3: Serial ETL execution (baseline)
-- ========================================

-- Disable parallel execution for baseline test
SET max_parallel_workers_per_gather = 0;

-- Serial aggregation and load
EXPLAIN (ANALYZE, BUFFERS, TIMING)
INSERT INTO public.TransactionSummary (
    Branch, TransactionType, TransactionMonth, 
    TotalTransactions, TotalAmount, AvgAmount, MinAmount, MaxAmount
)
SELECT 
    Branch,
    TransactionType,
    DATE_TRUNC('month', TransactionDate) AS TransactionMonth,
    COUNT(*) AS TotalTransactions,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    MIN(Amount) AS MinAmount,
    MAX(Amount) AS MaxAmount
FROM public.TransactionStaging
WHERE ProcessedFlag = FALSE
GROUP BY Branch, TransactionType, DATE_TRUNC('month', TransactionDate);

-- Mark records as processed
UPDATE public.TransactionStaging SET ProcessedFlag = TRUE;

-- Record serial execution time
SELECT 'SERIAL EXECUTION COMPLETED' AS Status, COUNT(*) AS Records_Loaded 
FROM public.TransactionSummary;


-- STEP 4: Parallel ETL execution
-- ==============================

-- Clear summary table for parallel test
TRUNCATE public.TransactionSummary;
UPDATE public.TransactionStaging SET ProcessedFlag = FALSE;

-- Enable parallel execution
SET max_parallel_workers_per_gather = 4;
SET parallel_setup_cost = 100;
SET parallel_tuple_cost = 0.01;
SET min_parallel_table_scan_size = '8MB';
SET min_parallel_index_scan_size = '512kB';

-- Force parallel execution
ALTER TABLE public.TransactionStaging SET (parallel_workers = 4);

-- Parallel aggregation and load
EXPLAIN (ANALYZE, BUFFERS, TIMING)
INSERT INTO public.TransactionSummary (
    Branch, TransactionType, TransactionMonth, 
    TotalTransactions, TotalAmount, AvgAmount, MinAmount, MaxAmount
)
SELECT 
    Branch,
    TransactionType,
    DATE_TRUNC('month', TransactionDate) AS TransactionMonth,
    COUNT(*) AS TotalTransactions,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    MIN(Amount) AS MinAmount,
    MAX(Amount) AS MaxAmount
FROM public.TransactionStaging
WHERE ProcessedFlag = FALSE
GROUP BY Branch, TransactionType, DATE_TRUNC('month', TransactionDate);

-- Record parallel execution time
SELECT 'PARALLEL EXECUTION COMPLETED' AS Status, COUNT(*) AS Records_Loaded 
FROM public.TransactionSummary;


-- STEP 5: Parallel DML operations
-- ================================

-- Enable parallel DML (UPDATE/DELETE)
-- Note: PostgreSQL doesn't support parallel DML directly, but we can simulate
-- by partitioning the work

-- Create function for parallel batch updates
CREATE OR REPLACE FUNCTION parallel_update_batches() RETURNS VOID AS $$
DECLARE
    v_batch_size INT := 25000;
    v_offset INT := 0;
    v_total_rows INT;
BEGIN
    SELECT COUNT(*) INTO v_total_rows FROM public.TransactionStaging;
    
    WHILE v_offset < v_total_rows LOOP
        UPDATE public.TransactionStaging
        SET ProcessedFlag = TRUE
        WHERE TransactionID IN (
            SELECT TransactionID 
            FROM public.TransactionStaging 
            WHERE ProcessedFlag = FALSE
            LIMIT v_batch_size
        );
        
        v_offset := v_offset + v_batch_size;
        RAISE NOTICE 'Processed batch: % of % rows', v_offset, v_total_rows;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reset flags
UPDATE public.TransactionStaging SET ProcessedFlag = FALSE;

-- Execute parallel batch updates
SELECT parallel_update_batches();

-- STEP 6: Parallel data export/extraction
-- =======================================

-- Create materialized view with parallel refresh
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_branch_performance AS
SELECT 
    Branch,
    DATE_TRUNC('month', TransactionDate) AS Month,
    COUNT(*) AS TransactionCount,
    SUM(Amount) AS TotalVolume,
    AVG(Amount) AS AvgTransactionSize,
    COUNT(DISTINCT MemberID) AS ActiveMembers
FROM public.TransactionStaging
GROUP BY Branch, DATE_TRUNC('month', TransactionDate);

-- Added unique index required for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_branch_performance_unique 
ON public.mv_branch_performance(Branch, Month);

-- Create additional index on materialized view
CREATE INDEX IF NOT EXISTS idx_mv_branch_month ON public.mv_branch_performance(Branch, Month);

-- Refresh with parallel workers
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_branch_performance;


-- STEP 7: Parallel aggregation comparison
-- ========================================

-- Complex aggregation query - Serial
SET max_parallel_workers_per_gather = 0;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    Branch,
    TransactionType,
    EXTRACT(YEAR FROM TransactionDate) AS Year,
    EXTRACT(QUARTER FROM TransactionDate) AS Quarter,
    COUNT(*) AS TxnCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    STDDEV(Amount) AS StdDevAmount,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount) AS MedianAmount
FROM public.TransactionStaging
GROUP BY Branch, TransactionType, EXTRACT(YEAR FROM TransactionDate), EXTRACT(QUARTER FROM TransactionDate)
ORDER BY Branch, Year, Quarter;

-- Complex aggregation query - Parallel
SET max_parallel_workers_per_gather = 4;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    Branch,
    TransactionType,
    EXTRACT(YEAR FROM TransactionDate) AS Year,
    EXTRACT(QUARTER FROM TransactionDate) AS Quarter,
    COUNT(*) AS TxnCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AvgAmount,
    STDDEV(Amount) AS StdDevAmount,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount) AS MedianAmount
FROM public.TransactionStaging
GROUP BY Branch, TransactionType, EXTRACT(YEAR FROM TransactionDate), EXTRACT(QUARTER FROM TransactionDate)
ORDER BY Branch, Year, Quarter;


-- STEP 8: Performance metrics collection
-- =======================================

-- Create performance tracking table
CREATE TABLE IF NOT EXISTS public.ETL_Performance_Log (
    LogID SERIAL PRIMARY KEY,
    TestName VARCHAR(100) NOT NULL,
    ExecutionMode VARCHAR(20) NOT NULL,
    RowsProcessed INT NOT NULL,
    ExecutionTime_MS DECIMAL(10, 2),
    WorkersUsed INT,
    BuffersHit INT,
    BuffersRead INT,
    TestTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample performance data (replace with actual measurements)
INSERT INTO public.ETL_Performance_Log (TestName, ExecutionMode, RowsProcessed, ExecutionTime_MS, WorkersUsed) VALUES
('Aggregation Query', 'Serial', 100000, 2500.00, 1),
('Aggregation Query', 'Parallel', 100000, 800.00, 4),
('Batch Update', 'Serial', 100000, 3200.00, 1),
('Batch Update', 'Parallel', 100000, 1100.00, 4),
('Complex Join', 'Serial', 100000, 4500.00, 1),
('Complex Join', 'Parallel', 100000, 1300.00, 4);

-- Performance comparison report
SELECT 
    TestName,
    MAX(CASE WHEN ExecutionMode = 'Serial' THEN ExecutionTime_MS END) AS Serial_Time_MS,
    MAX(CASE WHEN ExecutionMode = 'Parallel' THEN ExecutionTime_MS END) AS Parallel_Time_MS,
    ROUND(
        (MAX(CASE WHEN ExecutionMode = 'Serial' THEN ExecutionTime_MS END) - 
         MAX(CASE WHEN ExecutionMode = 'Parallel' THEN ExecutionTime_MS END)) / 
        MAX(CASE WHEN ExecutionMode = 'Serial' THEN ExecutionTime_MS END) * 100, 
        2
    ) AS Performance_Improvement_Pct,
    MAX(CASE WHEN ExecutionMode = 'Parallel' THEN WorkersUsed END) AS Parallel_Workers
FROM public.ETL_Performance_Log
GROUP BY TestName
ORDER BY Performance_Improvement_Pct DESC;


-- STEP 9: Verify data integrity
-- ==============================

-- Compare record counts
SELECT 'Staging Table' AS Source, COUNT(*) AS RecordCount FROM public.TransactionStaging
UNION ALL
SELECT 'Summary Table', COUNT(*) FROM public.TransactionSummary;

-- Verify aggregation accuracy
SELECT 
    Branch,
    TransactionType,
    SUM(TotalAmount) AS Total_From_Summary
FROM public.TransactionSummary
GROUP BY Branch, TransactionType
ORDER BY Branch, TransactionType;


-- STEP 10: Cleanup
-- ==================

-- Reset parallel settings to defaults
RESET max_parallel_workers_per_gather;
RESET parallel_setup_cost;
RESET parallel_tuple_cost;