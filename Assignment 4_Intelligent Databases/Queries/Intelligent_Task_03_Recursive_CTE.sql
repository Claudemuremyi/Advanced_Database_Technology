-- INTELLIGENT TASK 3: DEDUCTIVE DATABASES (RECURSIVE WITH) - OFFICER SUPERVISION
-- ============================================================================
-- Description: Use recursive CTE to compute each officer's top supervisor
-- and the hops (path length) to reach them. Handle cycles gracefully.
-- STEP 1: Create prerequisite table
-- ===================================

DROP TABLE IF EXISTS public.OFFICER_SUPERVISOR CASCADE;

CREATE TABLE public.OFFICER_SUPERVISOR (
    OFFICER_ID INT,
    SUPERVISOR_ID INT,
    PRIMARY KEY (OFFICER_ID, SUPERVISOR_ID),
    CONSTRAINT FK_OFFICER FOREIGN KEY (OFFICER_ID) REFERENCES branch_kigali.Officer(OfficerID) ON DELETE CASCADE,
    CONSTRAINT FK_SUPERVISOR FOREIGN KEY (SUPERVISOR_ID) REFERENCES branch_kigali.Officer(OfficerID) ON DELETE RESTRICT
);

-- STEP 2: Insert sample data (5-6 rows with potential cycles)
-- ===========================================================

-- First, ensure we have enough officers for the hierarchy
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM branch_kigali.Officer;
    
    IF v_count < 6 THEN
        INSERT INTO branch_kigali.Officer (FullName, Branch, Contact, Role) VALUES
        ('Senior Manager Alpha', 'Kigali', '+250788111111', 'Senior Manager'),
        ('Manager Beta', 'Kigali', '+250788222222', 'Manager'),
        ('Supervisor Gamma', 'Kigali', '+250788333333', 'Supervisor'),
        ('Officer Delta', 'Kigali', '+250788444444', 'Loan Officer'),
        ('Officer Epsilon', 'Kigali', '+250788555555', 'Claims Officer'),
        ('Officer Zeta', 'Kigali', '+250788666666', 'Assistant Officer')
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Create supervision hierarchy
-- Hierarchy: Zeta -> Delta -> Gamma -> Beta -> Alpha (top)
--            Epsilon -> Gamma (shares supervisor with Delta)
INSERT INTO public.OFFICER_SUPERVISOR (OFFICER_ID, SUPERVISOR_ID)
SELECT 
    o1.OfficerID AS OFFICER_ID,
    o2.OfficerID AS SUPERVISOR_ID
FROM branch_kigali.Officer o1
CROSS JOIN branch_kigali.Officer o2
WHERE (o1.FullName = 'Officer Zeta' AND o2.FullName = 'Officer Delta')
   OR (o1.FullName = 'Officer Delta' AND o2.FullName = 'Supervisor Gamma')
   OR (o1.FullName = 'Officer Epsilon' AND o2.FullName = 'Supervisor Gamma')
   OR (o1.FullName = 'Supervisor Gamma' AND o2.FullName = 'Manager Beta')
   OR (o1.FullName = 'Manager Beta' AND o2.FullName = 'Senior Manager Alpha')
ON CONFLICT DO NOTHING;

-- STEP 3Corrected recursive CTE
-- ==============================
WITH RECURSIVE OFFICER_HIERARCHY(OFFICER_ID, SUPERVISOR_ID, HOPS, PATH) AS (
    -- Anchor: Direct supervisor relationships (hop count = 0)
    SELECT 
        OFFICER_ID,
        SUPERVISOR_ID,
        0 AS HOPS,
        OFFICER_ID::VARCHAR || '>' || SUPERVISOR_ID::VARCHAR AS PATH
    FROM public.OFFICER_SUPERVISOR
    
    UNION ALL
    
    -- Recursive: Climb the supervision chain
    SELECT 
        O.OFFICER_ID,                              -- Keep original officer
        H.SUPERVISOR_ID,                           -- Get supervisor's supervisor
        O.HOPS + 1,                                -- Increment hop count
        O.PATH || '>' || H.SUPERVISOR_ID::VARCHAR  -- Append to path
    FROM OFFICER_HIERARCHY O
    JOIN public.OFFICER_SUPERVISOR H 
        ON O.SUPERVISOR_ID = H.OFFICER_ID          -- FIXED: Correct join (supervisor becomes officer in next level)
    WHERE O.PATH NOT LIKE '%>' || H.SUPERVISOR_ID::VARCHAR || '%'  -- FIXED: Better cycle detection
)
-- Get the top supervisor for each officer (one with maximum hops)
SELECT 
    OH.OFFICER_ID,
    O1.FullName AS Officer_Name,
    OH.SUPERVISOR_ID AS TOP_SUPERVISOR_ID,
    O2.FullName AS Top_Supervisor_Name,
    OH.HOPS AS HOPS_TO_TOP
FROM (
    SELECT 
        OFFICER_ID,
        SUPERVISOR_ID,
        HOPS,
        MAX(HOPS) OVER (PARTITION BY OFFICER_ID) AS MAX_HOPS  -- FIXED: Use window function
    FROM OFFICER_HIERARCHY
) ranked
JOIN OFFICER_HIERARCHY OH ON ranked.OFFICER_ID = OH.OFFICER_ID 
    AND ranked.SUPERVISOR_ID = OH.SUPERVISOR_ID
    AND ranked.MAX_HOPS = OH.HOPS
JOIN branch_kigali.Officer O1 ON OH.OFFICER_ID = O1.OfficerID
JOIN branch_kigali.Officer O2 ON OH.SUPERVISOR_ID = O2.OfficerID
ORDER BY OH.OFFICER_ID;

-- Alternative simpler version
WITH RECURSIVE OFFICER_HIERARCHY(OFFICER_ID, SUPERVISOR_ID, HOPS, PATH) AS (
    -- Anchor
    SELECT 
        OFFICER_ID,
        SUPERVISOR_ID,
        0,
        OFFICER_ID::VARCHAR || '>' || SUPERVISOR_ID::VARCHAR
    FROM public.OFFICER_SUPERVISOR
    
    UNION ALL
    
    -- Recursive
    SELECT 
        O.OFFICER_ID,
        H.SUPERVISOR_ID,                           -- FIXED: Get next level supervisor
        O.HOPS + 1,
        O.PATH || '>' || H.SUPERVISOR_ID::VARCHAR
    FROM OFFICER_HIERARCHY O
    JOIN public.OFFICER_SUPERVISOR H 
        ON O.SUPERVISOR_ID = H.OFFICER_ID          -- FIXED: Correct join direction
    WHERE O.PATH NOT LIKE '%>' || H.SUPERVISOR_ID::VARCHAR || '%'  -- Cycle guard
)
SELECT 
    OH.OFFICER_ID,
    O1.FullName AS Officer_Name,
    OH.SUPERVISOR_ID AS TOP_SUPERVISOR_ID,
    O2.FullName AS Top_Supervisor_Name,
    OH.HOPS AS HOPS_TO_TOP
FROM (
    SELECT 
        OFFICER_ID,
        SUPERVISOR_ID,
        HOPS,
        ROW_NUMBER() OVER (PARTITION BY OFFICER_ID ORDER BY HOPS DESC) AS rn
    FROM OFFICER_HIERARCHY
) ranked
JOIN OFFICER_HIERARCHY OH ON ranked.OFFICER_ID = OH.OFFICER_ID 
    AND ranked.SUPERVISOR_ID = OH.SUPERVISOR_ID
    AND ranked.rn = 1
JOIN branch_kigali.Officer O1 ON OH.OFFICER_ID = O1.OfficerID
JOIN branch_kigali.Officer O2 ON OH.SUPERVISOR_ID = O2.OfficerID
ORDER BY OH.OFFICER_ID;

-- STEP 4: Display results with officer names
-- ===========================================

SELECT 
    'Officer Supervision Hierarchy Results' AS Report,
    OFFICER_ID,
    Officer_Name,
    TOP_SUPERVISOR_ID,
    Top_Supervisor_Name,
    HOPS_TO_TOP,
    CASE 
        WHEN HOPS_TO_TOP = 0 THEN 'Direct Report'
        WHEN HOPS_TO_TOP = 1 THEN 'One Level Up'
        WHEN HOPS_TO_TOP = 2 THEN 'Two Levels Up'
        WHEN HOPS_TO_TOP = 3 THEN 'Three Levels Up'
        ELSE 'Higher Up'
    END AS Relationship_Level
FROM (
    WITH RECURSIVE OFFICER_HIERARCHY(OFFICER_ID, SUPERVISOR_ID, HOPS, PATH) AS (
        SELECT 
            OFFICER_ID,
            SUPERVISOR_ID,
            0,
            OFFICER_ID::VARCHAR || '>' || SUPERVISOR_ID::VARCHAR
        FROM public.OFFICER_SUPERVISOR
        
        UNION ALL
        
        SELECT 
            O.OFFICER_ID,
            H.SUPERVISOR_ID,
            O.HOPS + 1,
            O.PATH || '>' || H.SUPERVISOR_ID::VARCHAR
        FROM OFFICER_HIERARCHY O
        JOIN public.OFFICER_SUPERVISOR H ON O.SUPERVISOR_ID = H.OFFICER_ID
        WHERE O.PATH NOT LIKE '%>' || H.SUPERVISOR_ID::VARCHAR || '%'
    )
    SELECT 
        OH.OFFICER_ID,
        O1.FullName AS Officer_Name,
        OH.SUPERVISOR_ID AS TOP_SUPERVISOR_ID,
        O2.FullName AS Top_Supervisor_Name,
        OH.HOPS AS HOPS_TO_TOP
    FROM (
        SELECT 
            OFFICER_ID,
            SUPERVISOR_ID,
            HOPS,
            MAX(HOPS) OVER (PARTITION BY OFFICER_ID) AS MAX_HOPS
        FROM OFFICER_HIERARCHY
    ) ranked
    JOIN OFFICER_HIERARCHY OH ON ranked.OFFICER_ID = OH.OFFICER_ID 
        AND ranked.SUPERVISOR_ID = OH.SUPERVISOR_ID
        AND ranked.MAX_HOPS = OH.HOPS
    JOIN branch_kigali.Officer O1 ON OH.OFFICER_ID = O1.OfficerID
    JOIN branch_kigali.Officer O2 ON OH.SUPERVISOR_ID = O2.OfficerID
) final_results
ORDER BY HOPS_TO_TOP, OFFICER_ID;

-- Show the direct supervision relationships for comparison
SELECT 
    'Direct Supervision Relationships' AS Report,
    OS.OFFICER_ID,
    O1.FullName AS Officer_Name,
    OS.SUPERVISOR_ID,
    O2.FullName AS Supervisor_Name
FROM public.OFFICER_SUPERVISOR OS
JOIN branch_kigali.Officer O1 ON OS.OFFICER_ID = O1.OfficerID
JOIN branch_kigali.Officer O2 ON OS.SUPERVISOR_ID = O2.OfficerID
ORDER BY OS.OFFICER_ID;

