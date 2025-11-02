-- INTELLIGENT TASK 4: KNOWLEDGE BASES (TRIPLES & ONTOLOGY) - INSURANCE TAXONOMY
-- ============================================================================
-- Description: Compute transitive closure of isA relationships and find all
-- members whose insurance policy type ultimately isA* LifeInsuranceCategory.
-- STEP 1: Create prerequisite table
-- ==================================

DROP TABLE IF EXISTS public.INSURANCE_TRIPLE CASCADE;

CREATE TABLE public.INSURANCE_TRIPLE (
    S VARCHAR(100),  -- Subject (policy type, member, category)
    P VARCHAR(50),   -- Predicate (isA, hasPolicy)
    O VARCHAR(100),  -- Object (parent category, policy type)
    PRIMARY KEY (S, P, O)
);

-- STEP 2: Insert sample triples (~8 rows)
-- ========================================

-- Taxonomy relationships (isA hierarchy for insurance categories)
INSERT INTO public.INSURANCE_TRIPLE (S, P, O) VALUES
('TermLife', 'isA', 'LifeInsurance'),
('WholeLife', 'isA', 'LifeInsurance'),
('LifeInsurance', 'isA', 'LifeInsuranceCategory'),
('HealthInsurance', 'isA', 'HealthInsuranceCategory'),
('AccidentInsurance', 'isA', 'LifeInsuranceCategory'),  -- Accident can be life-related
('PropertyInsurance', 'isA', 'PropertyInsuranceCategory'),
('VehicleInsurance', 'isA', 'PropertyInsuranceCategory'),
('HealthInsuranceCategory', 'isA', 'GeneralInsurance');

-- Member policy relationships
INSERT INTO public.INSURANCE_TRIPLE (S, P, O) VALUES
('Member001', 'hasPolicy', 'TermLife'),
('Member002', 'hasPolicy', 'WholeLife'),
('Member003', 'hasPolicy', 'AccidentInsurance'),
('Member004', 'hasPolicy', 'HealthInsurance'),
('Member005', 'hasPolicy', 'LifeInsurance'),
('Member006', 'hasPolicy', 'PropertyInsurance'),
('Member007', 'hasPolicy', 'VehicleInsurance');


-- STEP 3: Corrected recursive CTE for isA closure
--=================================================
WITH RECURSIVE ISA_CLOSURE(CHILD, ANCESTOR) AS (
    -- Anchor: Direct isA relationships
    SELECT 
        S AS CHILD,           -- The child concept (e.g., TermLife)
        O AS ANCESTOR         -- The parent concept (e.g., LifeInsurance)
    FROM public.INSURANCE_TRIPLE
    WHERE P = 'isA'
    
    UNION ALL
    
    -- Recursive: Transitive closure - if A isA B and B isA C, then A isA* C
    SELECT 
        T.S AS CHILD,                    -- Start from child
        I.ANCESTOR AS ANCESTOR          -- FIXED: Get ancestor's ancestor (climb up)
    FROM public.INSURANCE_TRIPLE T
    JOIN ISA_CLOSURE I ON T.O = I.CHILD -- FIXED: Join via object (T.O) to child (I.CHILD)
    WHERE T.P = 'isA'
)
-- Find members with LifeInsuranceCategory policies
SELECT DISTINCT 
    T.S AS MEMBER_ID
FROM public.INSURANCE_TRIPLE T
JOIN ISA_CLOSURE IC ON T.O = IC.CHILD               -- Member's policy type matches CHILD in closure
WHERE T.P = 'hasPolicy'
  AND IC.ANCESTOR = 'LifeInsuranceCategory'         -- FIXED: Compare ANCESTOR (not CHILD) to target
ORDER BY MEMBER_ID;

-- Alternative clearer version with member details
WITH RECURSIVE ISA_CLOSURE(CHILD, ANCESTOR) AS (
    -- Base case: direct isA relationships
    SELECT S, O
    FROM public.INSURANCE_TRIPLE
    WHERE P = 'isA'
    
    UNION ALL
    
    -- Recursive case: transitive isA (if A isA B and B isA* C, then A isA* C)
    SELECT 
        T.S,                              -- Child concept
        I.ANCESTOR                        -- Ancestor's ancestor
    FROM public.INSURANCE_TRIPLE T
    JOIN ISA_CLOSURE I ON T.O = I.CHILD   -- FIXED: T.O (parent) matches I.CHILD, get I's ancestor
    WHERE T.P = 'isA'
)
SELECT DISTINCT 
    P.S AS MEMBER_ID,
    P.O AS POLICY_TYPE,
    IC.ANCESTOR AS ROLLED_UP_TO
FROM public.INSURANCE_TRIPLE P
JOIN ISA_CLOSURE IC ON P.O = IC.CHILD
WHERE P.P = 'hasPolicy'
  AND IC.ANCESTOR = 'LifeInsuranceCategory'   -- FIXED: Check ancestor column
ORDER BY MEMBER_ID;

-- STEP 4: Display complete results with policy details
-- =====================================================

SELECT 
    'Member Policy Roll-Up to LifeInsuranceCategory' AS Report,
    MEMBER_ID,
    POLICY_TYPE,
    ROLLED_UP_TO AS ULTIMATE_CATEGORY
FROM (
    WITH RECURSIVE ISA_CLOSURE(CHILD, ANCESTOR) AS (
        SELECT S, O
        FROM public.INSURANCE_TRIPLE
        WHERE P = 'isA'
        
        UNION ALL
        
        SELECT 
            T.S,
            I.ANCESTOR
        FROM public.INSURANCE_TRIPLE T
        JOIN ISA_CLOSURE I ON T.O = I.CHILD
        WHERE T.P = 'isA'
    )
    SELECT DISTINCT 
        P.S AS MEMBER_ID,
        P.O AS POLICY_TYPE,
        IC.ANCESTOR AS ROLLED_UP_TO
    FROM public.INSURANCE_TRIPLE P
    JOIN ISA_CLOSURE IC ON P.O = IC.CHILD
    WHERE P.P = 'hasPolicy'
      AND IC.ANCESTOR = 'LifeInsuranceCategory'
) results
ORDER BY MEMBER_ID;

-- STEP 5: Show the complete isA hierarchy for verification
-- =========================================================

SELECT 
    'Complete Insurance Taxonomy Hierarchy' AS Report,
    CHILD AS Policy_Type,
    ANCESTOR AS Parent_Category,
    HOPS AS Hierarchy_Level
FROM (
    WITH RECURSIVE ISA_CLOSURE(CHILD, ANCESTOR, HOPS, PATH) AS (
        SELECT 
            S AS CHILD,
            O AS ANCESTOR,
            0 AS HOPS,
            S || ' -> ' || O AS PATH
        FROM public.INSURANCE_TRIPLE
        WHERE P = 'isA'
        
        UNION ALL
        
        SELECT 
            T.S AS CHILD,
            I.ANCESTOR AS ANCESTOR,
            I.HOPS + 1,
            T.S || ' -> ' || I.PATH
        FROM public.INSURANCE_TRIPLE T
        JOIN ISA_CLOSURE I ON T.O = I.CHILD
        WHERE T.P = 'isA'
          AND I.PATH NOT LIKE '%' || T.S || '%'  -- Cycle guard
    )
    SELECT CHILD, ANCESTOR, MIN(HOPS) AS HOPS
    FROM ISA_CLOSURE
    GROUP BY CHILD, ANCESTOR
) hierarchy
ORDER BY CHILD, HOPS;

-- Display all members and their policy categories
SELECT 
    'All Member Policies and Categories' AS Report,
    M.S AS MEMBER_ID,
    M.O AS POLICY_TYPE,
    COALESCE(IC.ANCESTOR, 'No Category Found') AS ULTIMATE_CATEGORY
FROM public.INSURANCE_TRIPLE M
LEFT JOIN (
    WITH RECURSIVE ISA_CLOSURE(CHILD, ANCESTOR) AS (
        SELECT S, O FROM public.INSURANCE_TRIPLE WHERE P = 'isA'
        UNION ALL
        SELECT T.S, I.ANCESTOR
        FROM public.INSURANCE_TRIPLE T
        JOIN ISA_CLOSURE I ON T.O = I.CHILD
        WHERE T.P = 'isA'
    )
    SELECT CHILD, MAX(ANCESTOR) AS ANCESTOR  -- Get topmost ancestor
    FROM ISA_CLOSURE
    GROUP BY CHILD
) IC ON M.O = IC.CHILD
WHERE M.P = 'hasPolicy'
ORDER BY M.S;

