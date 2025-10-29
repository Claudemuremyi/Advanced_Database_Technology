-- A2: Database Link & Cross-Node Join (3–10 rows result)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- A2_1: From Node_A, create database link 'proj_link' to Node_B
-- Screenshot: A2 Create Database Link proj link – connection setup

-- Verify proj_link exists (should be created in A1_3)
SELECT srvname AS server_name, fdwname AS wrapper_name
FROM pg_foreign_server fs
JOIN pg_foreign_data_wrapper fdw ON fs.srvfdw = fdw.oid
WHERE srvname = 'proj_link';

-- pg_user_mappings has columns: usename, srvname, options
SELECT um.usename AS user_name, fs.srvname AS server_name, um.umoptions AS options
FROM pg_user_mappings um
JOIN pg_foreign_server fs ON um.srvid = fs.oid
WHERE fs.srvname = 'proj_link';

-- A2_2: Run remote SELECT on OrderDetail@proj_link showing up to 5 sample rows
-- Screenshot: A2 Remote Select OrderInfo proj link – remote select (≤5 rows)

SELECT *
FROM node_a.orderdetail_b_ft
ORDER BY detailid
FETCH FIRST 5 ROWS ONLY;

-- Verification for A2_2: Count remote rows
SELECT COUNT(*) AS remote_row_count FROM node_a.orderdetail_b_ft;

-- A2_3: Run distributed join: combine local A with remote B (3–10 rows)
-- Screenshot: A2 Distributed Join OrderDetail Menu – distributed join query result

-- Use FULL OUTER JOIN so we return rows even when there is no matching orderid
SELECT 
  COALESCE(a.orderid, b.orderid) AS orderid,
  a.detailid  AS detailid_a,
  a.menuid    AS menuid_a,
  a.quantity  AS qty_a,
  b.detailid  AS detailid_b,
  b.menuid    AS menuid_b,
  b.quantity  AS qty_b
FROM node_a.orderdetail_a a
FULL OUTER JOIN node_a.orderdetail_b_ft b
  ON a.orderid = b.orderid
WHERE COALESCE(a.orderid, b.orderid) IN (101,102,103,104)
ORDER BY COALESCE(a.orderid, b.orderid), COALESCE(a.detailid, b.detailid);

-- Alternative: If Menu exists in base schema, join with remote OrderDetail
-- SELECT m.ItemName, od.quantity
-- FROM node_a.orderdetail_a od
-- JOIN Menu m ON m.MenuID = od.menuid
-- WHERE od.orderid IN (101,102)
-- LIMIT 10;

-- Verification for A2_3: Count joined results
SELECT COUNT(*) AS join_result_count
FROM (
  SELECT 1
  FROM node_a.orderdetail_a a
  FULL OUTER JOIN node_a.orderdetail_b_ft b
    ON a.orderid = b.orderid
  WHERE COALESCE(a.orderid, b.orderid) IN (101,102,103,104)
) s;
