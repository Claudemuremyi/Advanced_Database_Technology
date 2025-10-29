-- B10: Business Limit Alert (Function + Trigger) (row-budget safe)

SET client_min_messages = warning;

CREATE SCHEMA IF NOT EXISTS node_a;

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- B10_1: Create BUSINESS_LIMITS table and seed exactly one active rule
-- Screenshot: B10 Create BusinessLimits Table – DDL creation and seed one rule

CREATE TABLE IF NOT EXISTS node_a.business_limits(
  rule_key TEXT PRIMARY KEY,
  threshold INT NOT NULL,
  active CHAR(1) NOT NULL CHECK (active IN ('Y','N'))
);

INSERT INTO node_a.business_limits(rule_key, threshold, active)
VALUES ('max_items_per_order', 5, 'Y')
ON CONFLICT (rule_key) DO UPDATE SET threshold=EXCLUDED.threshold, active=EXCLUDED.active;

-- Verification for B10_1: Show business limits table
SELECT 
  rule_key,
  threshold,
  active,
  CASE WHEN active='Y' THEN 'ENFORCED' ELSE 'DISABLED' END AS status
FROM node_a.business_limits;

SELECT 
  table_name,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_schema='node_a' AND table_name='business_limits';

-- B10_2: Implement function fn_should_alert that reads BUSINESS_LIMITS
-- Screenshot: B10 Create Function fn should alert – function definition

CREATE OR REPLACE FUNCTION node_a.fn_should_alert(p_orderid BIGINT) RETURNS INT AS $$
DECLARE 
  lim INT; 
  tot INT;
BEGIN
  SELECT threshold INTO lim 
  FROM node_a.business_limits 
  WHERE rule_key='max_items_per_order' AND active='Y';
  SELECT COALESCE(SUM(quantity),0) INTO tot 
  FROM node_a.orderdetail_a 
  WHERE orderid=p_orderid;
  IF lim IS NOT NULL AND tot > lim THEN
    RETURN 1;
  END IF;
  RETURN 0;
END; $$ LANGUAGE plpgsql;

-- Verification for B10_2: Show function exists and test it
SELECT 
  routine_name,
  routine_type,
  data_type AS return_type
FROM information_schema.routines
WHERE routine_schema='node_a' AND routine_name='fn_should_alert';

-- Test function with sample orderid
SELECT 
  101 AS test_orderid,
  node_a.fn_should_alert(101) AS should_alert,
  (SELECT SUM(quantity) FROM node_a.orderdetail_a WHERE orderid=101) AS current_total_items;

-- B10_3: Create BEFORE INSERT OR UPDATE trigger that raises error on violation
-- Screenshot: B10 Create Trigger Before Insert Update – trigger creation output

CREATE OR REPLACE FUNCTION node_a.fn_enforce_limit() RETURNS TRIGGER AS $$
DECLARE
  target_orderid BIGINT;
  lim INT;
  base_sum INT;
  new_total INT;
BEGIN
  target_orderid := COALESCE(NEW.orderid, OLD.orderid);
  SELECT threshold INTO lim FROM node_a.business_limits WHERE rule_key='max_items_per_order' AND active='Y';
  SELECT COALESCE(SUM(quantity),0) INTO base_sum FROM node_a.orderdetail_a WHERE orderid = target_orderid;

  IF TG_OP = 'UPDATE' THEN
    new_total := base_sum - OLD.quantity + NEW.quantity;
  ELSIF TG_OP = 'INSERT' THEN
    new_total := base_sum + NEW.quantity;
  ELSE
    new_total := base_sum - OLD.quantity; -- DELETE path, always allowed
  END IF;

  IF lim IS NOT NULL AND new_total > lim THEN
    RAISE EXCEPTION 'Business limit exceeded for order % (new_total=% > limit=%)', target_orderid, new_total, lim;
  END IF;
  RETURN COALESCE(NEW, OLD);
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_limit ON node_a.orderdetail_a;
CREATE TRIGGER trg_enforce_limit
BEFORE INSERT OR UPDATE ON node_a.orderdetail_a
FOR EACH ROW EXECUTE FUNCTION node_a.fn_enforce_limit();

-- Verification for B10_3: Show trigger exists
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema='node_a' 
  AND event_object_table='orderdetail_a'
  AND trigger_name='trg_enforce_limit';

-- B10_4: Demonstrate 2 failing and 2 passing DML cases
-- Screenshot: B10 Test DML Failing Cases / B10 Test DML Passing Cases / B10 Final Select Verification

-- Show current state before tests
SELECT 
  orderid,
  SUM(quantity) AS total_items,
  (SELECT threshold FROM node_a.business_limits WHERE rule_key='max_items_per_order' AND active='Y') AS max_limit
FROM node_a.orderdetail_a
GROUP BY orderid
ORDER BY orderid;

-- Test 1: Failing case (would exceed limit)
BEGIN;
DO $$
BEGIN
  BEGIN
    UPDATE node_a.orderdetail_a SET quantity = 100 WHERE detailid = 2; -- ensure exceed
    RAISE NOTICE 'Unexpected: limit not enforced';
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
  END;
END$$;
ROLLBACK;

-- Test 2: Failing case (would exceed limit)
BEGIN;
DO $$
BEGIN
  BEGIN
    UPDATE node_a.orderdetail_a SET quantity = 50 WHERE detailid = 3; -- ensure exceed
    RAISE NOTICE 'Unexpected: limit not enforced';
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
  END;
END$$;
ROLLBACK;

-- Test 3: Passing case (within limit)
UPDATE node_a.orderdetail_a SET quantity = 3 WHERE detailid = 1;

-- Test 4: Passing case (within limit)
UPDATE node_a.orderdetail_a SET quantity = 2 WHERE detailid = 2;

-- Final verification: Show committed data
-- Ensure rule table exists to avoid missing-relation error on fresh sessions
CREATE TABLE IF NOT EXISTS node_a.business_limits(
  rule_key TEXT PRIMARY KEY,
  threshold INT NOT NULL,
  active CHAR(1) NOT NULL CHECK (active IN ('Y','N'))
);

SELECT 
  detailid,
  orderid,
  menuid,
  quantity,
  subtotal,
  (SELECT SUM(quantity) 
   FROM node_a.orderdetail_a od2 
   WHERE od2.orderid = od1.orderid) AS total_items_per_order,
  CASE 
    WHEN (SELECT SUM(quantity) FROM node_a.orderdetail_a od2 WHERE od2.orderid = od1.orderid) > 
         (SELECT threshold FROM node_a.business_limits WHERE rule_key='max_items_per_order' AND active='Y')
    THEN 'LIMIT EXCEEDED'
    ELSE 'WITHIN LIMIT'
  END AS limit_status
FROM node_a.orderdetail_a od1
ORDER BY orderid, detailid;

-- Final row count check (must be ≤10)
SELECT 
  (SELECT COUNT(*) FROM node_a.orderdetail_a) +
  (SELECT COUNT(*) FROM node_b.orderdetail_b) AS total_committed_rows_after_tests;
