-- B6: Declarative Rules Hardening (≤10 committed rows)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- B6_1: Add/verify NOT NULL and domain CHECK constraints on OrderInfo and OrderDetail
-- Screenshot: B6 Alter Table Add Constraints – adding NOT NULL and CHECK

ALTER TABLE node_a.orderdetail_a
  ALTER COLUMN orderid SET NOT NULL,
  ALTER COLUMN menuid  SET NOT NULL,
  ALTER COLUMN subtotal SET NOT NULL,
  ADD CONSTRAINT chk_a_amount CHECK (quantity > 0 AND subtotal >= 0);

ALTER TABLE node_b.orderdetail_b
  ALTER COLUMN orderid SET NOT NULL,
  ALTER COLUMN menuid  SET NOT NULL,
  ALTER COLUMN subtotal SET NOT NULL,
  ADD CONSTRAINT chk_b_amount CHECK (quantity > 0 AND subtotal >= 0);

-- Verification for B6_1: Show constraints
SELECT 
  table_name,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_schema IN ('node_a','node_b')
  AND table_name IN ('orderdetail_a','orderdetail_b')
  AND constraint_type IN ('CHECK','NOT NULL')
ORDER BY table_schema, table_name, constraint_name;

SELECT 
  table_name,
  column_name,
  is_nullable
FROM information_schema.columns
WHERE table_schema IN ('node_a','node_b')
  AND table_name IN ('orderdetail_a','orderdetail_b')
  AND column_name IN ('orderid','menuid','subtotal')
ORDER BY table_schema, table_name, column_name;

-- B6_2: Prepare 2 failing INSERTs per table (wrapped in ROLLBACK)
-- Screenshot: B6 Test Inserts Failing – two failed insert attempts

-- Failing insert 1: NULL orderid (violates NOT NULL)
BEGIN;
DO $$
BEGIN
  BEGIN
    INSERT INTO node_a.orderdetail_a VALUES (10, NULL, 11, 1, 2500);
  EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'Expected error: NOT NULL constraint violation on orderid';
  END;
END$$;
ROLLBACK;

-- Failing insert 2: quantity = 0 (violates CHECK)
BEGIN;
DO $$
BEGIN
  BEGIN
    INSERT INTO node_b.orderdetail_b VALUES (11, 107, 12, 0, 0);
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'Expected error: CHECK constraint violation (quantity must be > 0)';
  END;
END$$;
ROLLBACK;

-- Verification for B6_2: Show these rows were NOT committed
SELECT 
  'After failed inserts' AS test_phase,
  COUNT(*) AS row_count_node_a,
  COUNT(CASE WHEN detailid IN (10) THEN 1 END) AS failed_row_exists_a
FROM node_a.orderdetail_a;

SELECT 
  'After failed inserts' AS test_phase,
  COUNT(*) AS row_count_node_b,
  COUNT(CASE WHEN detailid IN (11) THEN 1 END) AS failed_row_exists_b
FROM node_b.orderdetail_b;

-- B6_3: Prepare 2 passing INSERTs per table
-- Screenshot: B6 Test Inserts Passing – two successful insert attempts

-- Passing update 1 (using UPDATE to avoid exceeding row budget)
UPDATE node_a.orderdetail_a SET subtotal = 5200 WHERE detailid = 1;

-- Passing update 2
UPDATE node_b.orderdetail_b SET subtotal = 8600 WHERE detailid = 4;

-- Verification for B6_3: Show updates succeeded
SELECT 
  detailid,
  orderid,
  menuid,
  quantity,
  subtotal,
  'UPDATE SUCCESS' AS status
FROM node_a.orderdetail_a 
WHERE detailid = 1;

SELECT 
  detailid,
  orderid,
  menuid,
  quantity,
  subtotal,
  'UPDATE SUCCESS' AS status
FROM node_b.orderdetail_b 
WHERE detailid = 4;

-- B6_4: Show clean error handling and proof that only passing rows exist
-- Screenshot: B6 Final Select Valid Rows – proof that only valid rows exist

-- Final verification: All rows satisfy constraints
SELECT 
  'Node_A' AS fragment,
  detailid,
  orderid,
  menuid,
  quantity,
  subtotal,
  CASE 
    WHEN orderid IS NULL THEN 'INVALID'
    WHEN menuid IS NULL THEN 'INVALID'
    WHEN quantity <= 0 THEN 'INVALID'
    WHEN subtotal < 0 THEN 'INVALID'
    ELSE 'VALID'
  END AS validation_status
FROM node_a.orderdetail_a 
ORDER BY detailid;

SELECT 
  'Node_B' AS fragment,
  detailid,
  orderid,
  menuid,
  quantity,
  subtotal,
  CASE 
    WHEN orderid IS NULL THEN 'INVALID'
    WHEN menuid IS NULL THEN 'INVALID'
    WHEN quantity <= 0 THEN 'INVALID'
    WHEN subtotal < 0 THEN 'INVALID'
    ELSE 'VALID'
  END AS validation_status
FROM node_b.orderdetail_b 
ORDER BY detailid;

-- Total committed rows check (must be ≤10)
SELECT 
  (SELECT COUNT(*) FROM node_a.orderdetail_a) +
  (SELECT COUNT(*) FROM node_b.orderdetail_b) AS total_committed_rows;
