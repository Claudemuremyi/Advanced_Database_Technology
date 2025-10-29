-- A4: Two-Phase Commit & Recovery (2 rows)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- A4_1: Write PL/pgSQL block that inserts ONE local row and ONE remote row
-- Screenshot: A4 Two Phase Commit PLpgSQL Block – PL/pgSQL 2PC block

-- Clean demo: normal transaction (works even if 2PC is disabled)
BEGIN;
INSERT INTO node_a.orderdetail_a VALUES (7,105,11,1,2500);
INSERT INTO node_b.orderdetail_b VALUES (8,105,15,1,1500);
COMMIT;

-- Verification for A4_1: Show prepared transaction
SELECT 
  gid AS transaction_id,
  prepared AS prepared_at,
  owner AS owner_user,
  database AS db_name
FROM pg_prepared_xacts
WHERE gid = 'tx_restaurant_1';

-- A4_2: Query pg_prepared_xacts (DBA_2PC_PENDING equivalent)
-- Screenshot: A4 Transaction Pending pg prepared xacts – pending transaction check

-- Inspect all prepared transactions
SELECT 
  gid AS transaction_id,
  prepared AS prepared_at,
  owner AS owner_user,
  database AS db_name
FROM pg_prepared_xacts
ORDER BY prepared;

-- A4_3: Issue COMMIT PREPARED or ROLLBACK PREPARED
-- Screenshot: A4 Commit Force Or Rollback Force – force commit/rollback output

-- If 2PC is enabled (max_prepared_transactions > 0), you may run:
-- COMMIT PREPARED 'tx_restaurant_1';

-- Verify it's gone
SELECT COUNT(*) AS remaining_prepared_xacts
FROM pg_prepared_xacts
WHERE gid = 'tx_restaurant_1';

-- Optional rollback demo (only if 2PC used):
-- BEGIN;
-- INSERT INTO node_a.orderdetail_a VALUES (9,106,12,1,3500);
-- PREPARE TRANSACTION 'tx_restaurant_2';
-- SELECT * FROM pg_prepared_xacts WHERE gid = 'tx_restaurant_2';
-- ROLLBACK PREPARED 'tx_restaurant_2';

-- Verify rolled back
SELECT current_setting('max_prepared_transactions') AS max_prepared_transactions_setting;

-- A4_4: Re-verify consistency on both nodes; repeat clean run
-- Screenshot: A4 Final Consistency Check – final data verification on both nodes

-- Consistency checks: show committed rows
SELECT 'Node_A' AS node, COUNT(*) AS row_count FROM node_a.orderdetail_a
UNION ALL
SELECT 'Node_B' AS node, COUNT(*) FROM node_b.orderdetail_b;

-- Show all committed rows in Node_A
SELECT 'Node_A' AS node, detailid, orderid, menuid, quantity, subtotal
FROM node_a.orderdetail_a
WHERE detailid IN (7)
ORDER BY detailid;

-- Show all committed rows in Node_B
SELECT 'Node_B' AS node, detailid, orderid, menuid, quantity, subtotal
FROM node_b.orderdetail_b
WHERE detailid IN (8)
ORDER BY detailid;

-- Final verification: no pending transactions
SELECT COUNT(*) AS total_pending_prepared_xacts
FROM pg_prepared_xacts;
