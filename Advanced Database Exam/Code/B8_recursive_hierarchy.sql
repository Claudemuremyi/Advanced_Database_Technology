-- B8: Recursive Hierarchy Roll-Up (6–10 rows)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- B8_1: Create table HIER(parent_id, child_id) for natural hierarchy
-- Screenshot: B8 Create HIER Table – DDL for hierarchy

CREATE TEMP TABLE hier(parent_id INT, child_id INT);

-- Verification for B8_1: Show table created
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name='hier' AND table_schema LIKE 'pg_temp%'
ORDER BY ordinal_position;

-- B8_2: Insert 6–10 rows forming a 3-level hierarchy
-- Screenshot: B8 Insert Hierarchy Data – 6–10 inserted rows

INSERT INTO hier VALUES
(1,2),
(1,3),
(2,4),
(2,5),
(3,6),
(3,7);

-- Verification for B8_2: Show inserted rows
SELECT 
  parent_id,
  child_id,
  'Level 1: Root->Child1' AS level_description
FROM hier
ORDER BY parent_id, child_id;

SELECT COUNT(*) AS total_hierarchy_rows FROM hier;

-- B8_3: Write recursive WITH query producing (child_id, root_id, depth)
-- Screenshot: B8 Recursive With Query Output – recursive roll-up query result

WITH RECURSIVE tree AS (
  -- Anchor: Direct children of root (parent_id = 1)
  SELECT child_id, parent_id, parent_id AS root_id, 1 AS depth 
  FROM hier 
  WHERE parent_id = 1
  UNION ALL
  -- Recursive: Find children of previous level
  SELECT h.child_id, h.parent_id, t.root_id, t.depth + 1
  FROM hier h 
  JOIN tree t ON h.parent_id = t.child_id
)
SELECT 
  child_id,
  root_id,
  depth,
  CASE 
    WHEN depth = 1 THEN 'Direct child of root'
    WHEN depth = 2 THEN 'Grandchild (2 levels)'
    WHEN depth = 3 THEN 'Great-grandchild (3 levels)'
    ELSE 'Deeper level'
  END AS level_description
FROM tree 
ORDER BY root_id, depth, child_id;

-- Verification for B8_3: Show result count (should be 6–10 rows)
SELECT COUNT(*) AS recursive_query_result_rows
FROM (
  WITH RECURSIVE tree AS (
    SELECT child_id, parent_id, parent_id AS root_id, 1 AS depth 
    FROM hier 
    WHERE parent_id = 1
    UNION ALL
    SELECT h.child_id, h.parent_id, t.root_id, t.depth + 1
    FROM hier h 
    JOIN tree t ON h.parent_id = t.child_id
  )
  SELECT * FROM tree
) s;

-- B8_4: Control aggregation validating rollup correctness
-- Screenshot: B8 Control Aggregation Check – validation of roll-up correctness

WITH RECURSIVE tree AS (
  SELECT child_id, parent_id, parent_id AS root_id, 1 AS depth 
  FROM hier 
  WHERE parent_id = 1
  UNION ALL
  SELECT h.child_id, h.parent_id, t.root_id, t.depth + 1
  FROM hier h 
  JOIN tree t ON h.parent_id = t.child_id
)
SELECT 
  depth,
  COUNT(*) AS nodes_at_depth,
  STRING_AGG(child_id::TEXT, ', ' ORDER BY child_id) AS children_list
FROM tree
GROUP BY depth
ORDER BY depth;

-- Control: Validate total nodes match source
SELECT 
  'Source hierarchy' AS source,
  COUNT(*) AS total_rows
FROM hier
UNION ALL
SELECT 
  'Recursive tree output',
  (SELECT COUNT(*) FROM (
    WITH RECURSIVE tree AS (
      SELECT child_id, parent_id, parent_id AS root_id, 1 AS depth 
      FROM hier 
      WHERE parent_id = 1
      UNION ALL
      SELECT h.child_id, h.parent_id, t.root_id, t.depth + 1
      FROM hier h 
      JOIN tree t ON h.parent_id = t.child_id
    )
    SELECT * FROM tree
  ) s);
