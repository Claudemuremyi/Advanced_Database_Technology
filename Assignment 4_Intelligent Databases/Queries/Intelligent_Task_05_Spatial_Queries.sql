-- INTELLIGENT TASK 5: SPATIAL DATABASES (GEOGRAPHY & DISTANCE) - BRANCH PROXIMITY
-- ===============================================================================
-- Description: Find SACCO branches within 1 km radius and nearest 3 branches
-- using PostGIS spatial functions.

-- STEP 1: Enable PostGIS extension
-- ===================================

-- Check if PostGIS is installed
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verify PostGIS version
SELECT PostGIS_version() AS PostGIS_Version;

-- STEP 2: Create prerequisite table with spatial column
-- ======================================================

DROP TABLE IF EXISTS public.BRANCH_LOCATION CASCADE;

CREATE TABLE public.BRANCH_LOCATION (
    BRANCH_ID SERIAL PRIMARY KEY,
    BRANCH_NAME VARCHAR(100) NOT NULL,
    ADDRESS TEXT,
    GEOM GEOMETRY(POINT, 4326),  -- Using SRID 4326 (WGS84)
    CREATED_DATE DATE DEFAULT CURRENT_DATE
);

-- Create spatial index
CREATE INDEX BRANCH_LOCATION_SPX ON public.BRANCH_LOCATION USING GIST(GEOM);

-- STEP 3: Insert sample branch data (with coordinates near reference point)
-- =============================================================================
-- Reference location: lon=30.0600, lat=-1.9570 (Kigali, Rwanda area)
-- This represents a central SACCO office or member location

INSERT INTO public.BRANCH_LOCATION (BRANCH_NAME, ADDRESS, GEOM) VALUES
('Central Kigali Branch', 'KG 15 Ave, Kigali City', ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)),              -- Same as reference
('Nyarugenge Branch', 'Nyarugenge District, Kigali', ST_SetSRID(ST_MakePoint(30.0610, -1.9560), 4326)),              -- ~100m away
('Gasabo Branch', 'Gasabo District, Kigali', ST_SetSRID(ST_MakePoint(30.0590, -1.9580), 4326)),                      -- ~150m away
('Kicukiro Branch', 'Kicukiro District, Kigali', ST_SetSRID(ST_MakePoint(30.0620, -1.9570), 4326)),                 -- ~200m away
('Kimisagara Branch', 'Kimisagara, Kigali', ST_SetSRID(ST_MakePoint(30.0580, -1.9570), 4326)),                      -- ~200m away
('Musanze Branch', 'Musanze District, Northern Province', ST_SetSRID(ST_MakePoint(29.6000, -1.5000), 4326)),        -- ~50km away
('Huye Branch', 'Huye District, Southern Province', ST_SetSRID(ST_MakePoint(29.7500, -2.6000), 4326));              -- ~100km away

-- STEP 4: Create corrected query for branches within 1 km
-- ========================================================
-- Using ST_DWithin (more efficient than ST_Distance for radius queries)
SELECT 
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,                    -- Convert to geography for meter-based distance
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
        ) / 1000.0,                               -- Convert meters to kilometers
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
WHERE ST_DWithin(
    B.GEOM::geography,                           -- FIXED: Convert to geography
    ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography,  -- FIXED: Correct SRID and lon/lat order
    1000                                         -- FIXED: Distance in meters (1 km = 1000 m)
)
ORDER BY DISTANCE_KM;

-- Alternative using ST_DistanceSphere (faster, less accurate)
SELECT 
    B.BRANCH_ID,
    B.BRANCH_NAME,
    ROUND(
        ST_DistanceSphere(
            B.GEOM,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)  -- FIXED: lon, lat order
        ) / 1000.0,
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
WHERE ST_DistanceSphere(
    B.GEOM,
    ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)
) <= 1000  -- 1 km in meters
ORDER BY DISTANCE_KM;

-- STEP 5: Create query for nearest 3 branches
-- ===========================================
-- Create reference location point once (store in CTE)
WITH REFERENCE_LOCATION AS (
    SELECT ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326) AS REF_POINT  -- FIXED: lon, lat order
)
-- Corrected query 2: Nearest 3 branches with distances
SELECT 
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,
            R.REF_POINT::geography
        ) / 1000.0,                        
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
CROSS JOIN REFERENCE_LOCATION R
ORDER BY B.GEOM::geography <-> R.REF_POINT::geography  
LIMIT 3;

-- Alternative simpler version
SELECT 
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography  -- FIXED: Proper point construction
        ) / 1000.0,
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
ORDER BY B.GEOM::geography <-> ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
LIMIT 3;

-- STEP 6: Display comprehensive results
-- =====================================

-- Query 1: Within 1 km radius
SELECT 
    'Branches Within 1 km Radius' AS Query_Type,
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
        ) / 1000.0,
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
WHERE ST_DWithin(
    B.GEOM::geography,
    ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography,
    1000
)
ORDER BY DISTANCE_KM;

-- Query 2: Nearest 3 branches
SELECT 
    'Nearest 3 Branches' AS Query_Type,
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
        ) / 1000.0,
        3
    ) AS DISTANCE_KM
FROM public.BRANCH_LOCATION B
ORDER BY B.GEOM::geography <-> ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
LIMIT 3;

-- STEP 7: Verification - Show all branches with distances
-- ========================================================

SELECT 
    'All Branches with Distances from Reference Point' AS Report,
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.ADDRESS,
    ROUND(
        ST_Distance(
            B.GEOM::geography,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography
        ) / 1000.0,
        3
    ) AS DISTANCE_KM,
    CASE 
        WHEN ST_DWithin(
            B.GEOM::geography,
            ST_SetSRID(ST_MakePoint(30.0600, -1.9570), 4326)::geography,
            1000
        ) THEN 'WITHIN 1 KM ✓'
        ELSE 'OUTSIDE 1 KM'
    END AS STATUS
FROM public.BRANCH_LOCATION B
ORDER BY DISTANCE_KM;

-- Display coordinate information
SELECT 
    'Branch Coordinates' AS Report,
    BRANCH_ID,
    BRANCH_NAME,
    ST_X(GEOM) AS Longitude,
    ST_Y(GEOM) AS Latitude,
    ST_AsText(GEOM) AS WKT_Format
FROM public.BRANCH_LOCATION
ORDER BY BRANCH_ID;

