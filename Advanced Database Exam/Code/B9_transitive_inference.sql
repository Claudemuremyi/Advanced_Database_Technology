-- B9: Mini-Knowledge Base with Transitive Inference (≤10 facts)

DO $$
BEGIN
  IF current_database() <> 'restaurantdb' THEN
    RAISE EXCEPTION 'Please connect to database restaurantdb, current=%', current_database();
  END IF;
END$$;

-- B9_1: Create table TRIPLE(s, p, o) for knowledge base
-- Screenshot: B9 Create TRIPLE Table – DDL creation

CREATE TEMP TABLE triple(s TEXT, p TEXT, o TEXT);

-- Verification for B9_1: Show table structure
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name='triple' AND table_schema LIKE 'pg_temp%'
ORDER BY ordinal_position;

-- B9_2: Insert 8–10 domain facts relevant to restaurant project
-- Screenshot: B9 Insert Domain Facts – inserted 8–10 facts

INSERT INTO triple VALUES
('Isombe','isA','Traditional'),
('Brochette','isA','Grill'),
('Chapati','isA','Bakery'),
('Traditional','isA','Dish'),
('Grill','isA','Dish'),
('Bakery','isA','Dish'),
('Dish','isA','Food'),
('Food','isA','Item');

-- Verification for B9_2: Show all facts
SELECT 
  s AS subject,
  p AS predicate,
  o AS object,
  ROW_NUMBER() OVER (ORDER BY s, p, o) AS fact_number
FROM triple
ORDER BY s, p, o;

SELECT COUNT(*) AS total_facts FROM triple;

-- B9_3: Write recursive inference query implementing transitive isA*
-- Screenshot: B9 Recursive Inference Query Output – recursive inference results

WITH RECURSIVE isa(s,o) AS (
  -- Anchor: Direct isA relationships
  SELECT s, o 
  FROM triple 
  WHERE p='isA'
  UNION
  -- Recursive: Transitive closure of isA
  SELECT i.s, t.o 
  FROM isa i 
  JOIN triple t ON i.o = t.s AND t.p='isA'
)
SELECT DISTINCT 
  s AS entity,
  o AS label,
  'isA*' AS inference_type
FROM isa
WHERE o IN ('Dish','Food','Item')
ORDER BY entity, label
LIMIT 10;

-- Verification for B9_3: Count inferred relationships
SELECT COUNT(*) AS inferred_relationships_count
FROM (
  WITH RECURSIVE isa(s,o) AS (
    SELECT s, o 
    FROM triple 
    WHERE p='isA'
    UNION
    SELECT i.s, t.o 
    FROM isa i 
    JOIN triple t ON i.o = t.s AND t.p='isA'
  )
  SELECT DISTINCT s, o FROM isa WHERE o IN ('Dish','Food','Item')
) s;

-- B9_4: Grouping counts proving inferred labels are consistent
-- Screenshot: B9 Grouping Consistency Check – label consistency proof

WITH RECURSIVE isa(s,o) AS (
  SELECT s, o FROM triple WHERE p='isA'
  UNION
  SELECT i.s, t.o FROM isa i JOIN triple t ON i.o = t.s AND t.p='isA'
)
SELECT 
  o AS label,
  COUNT(DISTINCT s) AS num_entities,
  STRING_AGG(DISTINCT s, ', ' ORDER BY s) AS entities_list
FROM isa
WHERE o IN ('Dish','Food','Item')
GROUP BY o
ORDER BY o;

-- Control: Show base vs inferred counts
SELECT 
  'Base facts (direct isA)' AS source_type,
  COUNT(*) AS fact_count
FROM triple
WHERE p='isA'
UNION ALL
SELECT 
  'Inferred relationships (isA*)',
  (SELECT COUNT(DISTINCT s||'->'||o) 
   FROM (
     WITH RECURSIVE isa(s,o) AS (
       SELECT s, o FROM triple WHERE p='isA'
       UNION
       SELECT i.s, t.o FROM isa i JOIN triple t ON i.o = t.s AND t.p='isA'
     )
     SELECT s, o FROM isa
   ) x);
