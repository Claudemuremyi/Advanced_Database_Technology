-- A3: Parallel vs Serial Aggregation (≤10 rows data)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- A3_1: Run SERIAL aggregation on OrderDetail_ALL
-- Screenshot: A3 Serial Aggregation Output – normal aggregation result

-- Reset parallel settings for serial execution
SET max_parallel_workers_per_gather = 0;
SET parallel_tuple_cost = 0.01;
SET parallel_setup_cost = 1000.0;

-- SERIAL aggregation (totals by menuid - ensure 3–10 groups)
SELECT menuid, SUM(quantity) AS total_qty, SUM(subtotal) AS total_amount
FROM node_a.orderdetail_all
GROUP BY menuid
ORDER BY menuid;

-- Verification for A3_1: Show row count
SELECT COUNT(*) AS serial_result_groups
FROM (
  SELECT menuid FROM node_a.orderdetail_all GROUP BY menuid
) s;

-- A3_2: Run same aggregation with parallel plan (simulated via GUCs)
-- Screenshot: A3 Parallel Aggregation Output – parallel simulated result

-- Encourage PARALLEL (Postgres uses GUCs, not hints)
SET max_parallel_workers_per_gather = 2;
SET parallel_tuple_cost = 0.0;
SET parallel_setup_cost = 0.0;

-- Parallel aggregation
SELECT menuid, SUM(quantity) AS total_qty, SUM(subtotal) AS total_amount
FROM node_a.orderdetail_all
GROUP BY menuid
ORDER BY menuid;

-- Verification for A3_2: Show row count (should match serial)
SELECT COUNT(*) AS parallel_result_groups
FROM (
  SELECT menuid FROM node_a.orderdetail_all GROUP BY menuid
) s;

-- A3_3: Capture execution plans with EXPLAIN ANALYZE
-- Screenshot: A3 Execution Plan Serial vs Parallel – EXPLAIN ANALYZE comparison

-- Serial plan
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT menuid, SUM(quantity) AS total_qty
FROM node_a.orderdetail_all
GROUP BY menuid
ORDER BY menuid;

-- Parallel plan
SET max_parallel_workers_per_gather = 2;
SET parallel_tuple_cost = 0.0;
SET parallel_setup_cost = 0.0;
EXPLAIN (ANALYZE, VERBOSE, BUFFERS)
SELECT menuid, SUM(quantity) AS total_qty
FROM node_a.orderdetail_all
GROUP BY menuid
ORDER BY menuid;

-- A3_4: Produce 2-row comparison table (serial vs parallel)
-- Screenshot: A3 Comparison Table – 2-row summary (serial vs parallel)

-- Comparison summary (manual entry based on EXPLAIN output)
-- For actual timing, run each EXPLAIN ANALYZE separately and note the Execution Time

SELECT 
  'Serial' AS execution_mode,
  (SELECT COUNT(*) FROM node_a.orderdetail_all) AS total_rows_processed,
  (SELECT COUNT(DISTINCT menuid) FROM node_a.orderdetail_all) AS groups_produced
UNION ALL
SELECT 
  'Parallel' AS execution_mode,
  (SELECT COUNT(*) FROM node_a.orderdetail_all) AS total_rows_processed,
  (SELECT COUNT(DISTINCT menuid) FROM node_a.orderdetail_all) AS groups_produced;

-- Note: Actual execution time comparison should be taken from EXPLAIN ANALYZE output
-- serial_execution_time_ms and parallel_execution_time_ms would be extracted manually
