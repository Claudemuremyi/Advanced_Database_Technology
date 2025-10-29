-- A1: Fragment & Recombine Main Fact (≤10 rows)

-- Ensure we are connected to the correct database
DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- A1_1: Create horizontally fragmented tables OrderDetail_A and OrderDetail_B
-- Screenshot: A1 Create Tables OrderDetail A B – table creation (DDL)

CREATE SCHEMA IF NOT EXISTS node_a;
CREATE SCHEMA IF NOT EXISTS node_b;

CREATE TABLE IF NOT EXISTS node_a.orderdetail_a (
  detailid BIGINT PRIMARY KEY,
  orderid  BIGINT NOT NULL,
  menuid   BIGINT NOT NULL,
  quantity INT    NOT NULL CHECK (quantity > 0),
  subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

CREATE TABLE IF NOT EXISTS node_b.orderdetail_b (
  detailid BIGINT PRIMARY KEY,
  orderid  BIGINT NOT NULL,
  menuid   BIGINT NOT NULL,
  quantity INT    NOT NULL CHECK (quantity > 0),
  subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

-- Ensure access (avoid permission issues for FDW user)
GRANT USAGE ON SCHEMA node_b TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON node_b.orderdetail_b TO PUBLIC;

-- Verification for A1_1: Show created tables
SELECT 
  table_schema,
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns 
   WHERE table_schema=t.table_schema AND table_name=t.table_name) AS column_count
FROM information_schema.tables t
WHERE table_schema IN ('node_a','node_b')
  AND table_name IN ('orderdetail_a','orderdetail_b')
ORDER BY table_schema, table_name;

-- A1_2: Insert ≤10 committed rows split across fragments
-- Screenshot: A1 Insert Data NodeA NodeB – inserting ≤10 rows proof

INSERT INTO node_a.orderdetail_a VALUES
(1,101,11,2,5000),
(2,101,15,1,1500),
(3,102,12,1,3500)
ON CONFLICT DO NOTHING;

INSERT INTO node_b.orderdetail_b VALUES
(4,103,13,3,8400),
(5,103,18,2,1600),
(6,104,14,1,3000)
ON CONFLICT DO NOTHING;

-- Ensure DDL/DML are visible to the FDW remote session
COMMIT;

-- Verification for A1_2: Show inserted rows by fragment
SELECT 'Node_A' AS fragment, COUNT(*) AS row_count FROM node_a.orderdetail_a
UNION ALL
SELECT 'Node_B' AS fragment, COUNT(*) FROM node_b.orderdetail_b;

SELECT 'Node_A' AS fragment, detailid, orderid, menuid, quantity, subtotal 
FROM node_a.orderdetail_a
UNION ALL
SELECT 'Node_B' AS fragment, detailid, orderid, menuid, quantity, subtotal 
FROM node_b.orderdetail_b
ORDER BY detailid;

-- A1_3: Create database link 'proj_link' to Node_B
-- Screenshot: A1 Create Database Link proj link – foreign data wrapper / link setup

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create server only if missing (avoid NOTICE noise)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'proj_link') THEN
    EXECUTE 'CREATE SERVER proj_link FOREIGN DATA WRAPPER postgres_fdw '
         || 'OPTIONS (host ''localhost'', dbname ''restaurantdb'', port ''5432'')';
  END IF;
END$$;

-- Ensure user mapping exists (idempotent)
CREATE USER MAPPING IF NOT EXISTS FOR postgres SERVER proj_link
  OPTIONS (user 'postgres', password '');

-- Create foreign table only if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema='node_a' AND foreign_table_name='orderdetail_b_ft'
  ) THEN
    EXECUTE 'CREATE FOREIGN TABLE node_a.orderdetail_b_ft (
      detailid BIGINT,
      orderid  BIGINT,
      menuid   BIGINT,
      quantity INT,
      subtotal NUMERIC(12,2)
    ) SERVER proj_link OPTIONS (schema_name ''node_b'', table_name ''orderdetail_b'')';
  END IF;
END$$;

-- Verification for A1_3: Show FDW server and foreign table setup
SELECT srvname AS server_name, fdwname AS wrapper_name
FROM pg_foreign_server fs
JOIN pg_foreign_data_wrapper fdw ON fs.srvfdw = fdw.oid
WHERE srvname = 'proj_link';

SELECT 
  foreign_table_schema,
  foreign_table_name,
  foreign_server_name
FROM information_schema.foreign_tables
WHERE foreign_table_schema='node_a' AND foreign_table_name='orderdetail_b_ft';

-- A1_4: Create view OrderDetail_ALL as UNION ALL of fragments
-- Screenshot: A1 Create View OrderDetail ALL – view combining both fragments

CREATE OR REPLACE VIEW node_a.orderdetail_all AS
SELECT * FROM node_a.orderdetail_a
UNION ALL
SELECT * FROM node_a.orderdetail_b_ft;

-- Verification for A1_4: Show view definition
SELECT * FROM node_a.orderdetail_all;

-- A1_5: Validate with COUNT(*) and checksum - results must match
-- Screenshot: A1 Validate Count Checksum – COUNT(*) and checksum validation

DO $$
DECLARE has_ft BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema='node_a' AND foreign_table_name='orderdetail_b_ft'
  ) INTO has_ft;

  IF has_ft THEN
    RAISE NOTICE 'Validating remote fragment via foreign table node_a.orderdetail_b_ft';
  ELSE
    RAISE NOTICE 'Foreign table node_a.orderdetail_b_ft is missing; skipping remote validation';
  END IF;
END$$;

-- Validation: counts
SELECT
  'Fragment A' AS source,
  (SELECT COUNT(*) FROM node_a.orderdetail_a) AS row_count
UNION ALL
SELECT
  'Fragment B (via FT)',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema='node_a' AND foreign_table_name='orderdetail_b_ft'
  ) THEN (SELECT COUNT(*) FROM node_a.orderdetail_b_ft) ELSE NULL END
UNION ALL
SELECT
  'Combined View (ALL)',
  (SELECT COUNT(*) FROM node_a.orderdetail_all);

-- Validation: checksums
SELECT
  'Fragment A' AS source,
  (SELECT SUM(detailid % 97) FROM node_a.orderdetail_a) AS checksum_value
UNION ALL
SELECT
  'Fragment B (via FT)',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema='node_a' AND foreign_table_name='orderdetail_b_ft'
  ) THEN (SELECT SUM(detailid % 97) FROM node_a.orderdetail_b_ft) ELSE NULL END
UNION ALL
SELECT
  'Combined View (ALL)',
  (SELECT SUM(detailid % 97) FROM node_a.orderdetail_all);

-- Final verification: show all data from combined view
SELECT * FROM node_a.orderdetail_all ORDER BY detailid;
