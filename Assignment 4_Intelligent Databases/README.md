# Intelligent Databases - Assignment Tasks

## Overview

This assignment demonstrates **intelligent database concepts** including:
- **Declarative constraints** (rules)
- **Active databases** (triggers)
- **Deductive databases** (recursive queries)
- **Knowledge bases** (ontology)
- **Spatial databases** (PostGIS)

All tasks are implemented using **PostgreSQL** with a **SACCO (Savings and Credit Cooperative) system** context in **Rwanda**.

---

## Database Structure

- **Database Name**: `sacco`
- **DBMS**: PostgreSQL (pgAdmin 4)
- **Schemas Used**: 
  - `public` (main schema for new tables)
  - `branch_kigali` (referenced from distributed database tasks)
  - `branch_musanze` (referenced from distributed database tasks)

---

## Prerequisites

### Software Requirements
- PostgreSQL 12+ with pgAdmin 4
- `postgis` extension (for Task 05 - Spatial Queries)

### Setup Extensions
```sql
-- For Spatial Queries (Task 05)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verify installation
SELECT PostGIS_version();
```

### Prerequisites from ASSIGNMENT_3
Some tasks reference tables from the distributed database assignment:
- Run `ASSIGNMENT_3/Code/Task_01.sql` first to create:
  - `branch_kigali.Member`
  - `branch_kigali.Officer`

---

## Tasks Overview

### Intelligent Task 01: Rules (Declarative Constraints)
**File**: `Intelligent_Task_01_Constraints.sql`

**Description**: Implements declarative constraints to enforce data integrity rules on insurance claims.

**Key Concepts**:
- Declarative constraints (CHECK constraints)
- Referential integrity (FOREIGN KEY)
- NOT NULL constraints
- Date validation logic
- Constraint violation handling

**Tables Created**:
- `public.MEMBER_CLAIM` - Stores member insurance claims with constraints

---

### Intelligent Task 02: Active Databases (E-C-A Trigger)
**File**: `Intelligent_Task_02_Triggers.sql`

**Description**: Implements an active database using Event-Condition-Action (E-C-A) triggers to maintain data consistency.

**Key Concepts**:
- Active databases
- Event-Condition-Action (E-C-A) pattern
- Statement-level triggers (vs row-level)
- Mutating table issues avoidance
- Derived attribute consistency
- Trigger auditing

**Tables Created**:
- `public.LOAN` - Loan accounts with `TOTAL_PAID` derived attribute
- `public.LOAN_PAYMENT` - Payment records
- `public.LOAN_AUDIT` - Audit trail for trigger executions

---

### Intelligent Task 03: Deductive Databases (Recursive CTE)
**File**: `Intelligent_Task_03_Recursive_CTE.sql`

**Description**: Uses recursive Common Table Expressions (CTE) to compute transitive closure of officer supervision hierarchy.

**Key Concepts**:
- Deductive databases
- Recursive queries (WITH RECURSIVE)
- Transitive closure
- Hierarchical data structures
- Cycle detection and handling
- Graph traversal

**Tables Created**:
- `public.OFFICER_SUPERVISOR` - Supervisor relationships (directed graph)

---

### Intelligent Task 04: Knowledge Bases (Triples & Ontology)
**File**: `Intelligent_Task_04_Knowledge_Base.sql`

**Description**: Implements a knowledge base using triple store (subject-predicate-object) representation.

**Key Concepts**:
- Knowledge bases
- Triple store representation
- Ontology and taxonomy
- Transitive closure
- `isA` relationship hierarchy
- Recursive reasoning

**Tables Created**:
- `public.INSURANCE_TRIPLE` - Triple store (S, P, O representation)

---

### Intelligent Task 05: Spatial Databases (Geography & Distance)
**File**: `Intelligent_Task_05_Spatial_Queries.sql`

**Description**: Demonstrates spatial database capabilities using PostGIS.

**Key Concepts**:
- Spatial databases
- PostGIS extension
- Geographic coordinates (WGS84, SRID 4326)
- Distance calculations
- Spatial indexing (GIST)
- Radius queries
- Nearest neighbor queries

**Tables Created**:
- `public.BRANCH_LOCATION` - Branch locations with spatial geometry

---

## Directory Structure

```
INTELIGENT DATABASE/
├── README.md                              (This file)
├── Intelligent_Task_01_Constraints.sql    (Rules - Declarative Constraints)
├── Intelligent_Task_02_Triggers.sql        (Active Databases - E-C-A Triggers)
├── Intelligent_Task_03_Recursive_CTE.sql   (Deductive Databases - Recursive Queries)
├── Intelligent_Task_04_Knowledge_Base.sql (Knowledge Bases - Triple Store)
├── Intelligent_Task_05_Spatial_Queries.sql (Spatial Databases - PostGIS)
└── Screenshoots/
    ├── I01_Rules Declarative ConstraintsSafe Prescriptions.jpg
    ├── I02_Active Databases Trigger Bill Totals That Stay Correct.jpg
    ├── I03_Deductive Databases Recursive WITH Referral or Supervision Chain.jpg
    └── I04_Knowledge Bases.jpg
```

---

## Quick Start

### 1. Enable PostGIS Extension
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### 2. Ensure Prerequisites (if needed)
```sql
-- For Tasks 01 and 03, ensure distributed database setup exists
-- Run ASSIGNMENT_3/Code/Task_01.sql first if needed
```

### 3. Run Tasks
```sql
-- Task 01: Rules/Constraints (requires branch_kigali.Member)
\i Intelligent_Task_01_Constraints.sql

-- Task 02: Triggers (standalone)
\i Intelligent_Task_02_Triggers.sql

-- Task 03: Recursive CTE (requires branch_kigali.Officer)
\i Intelligent_Task_03_Recursive_CTE.sql

-- Task 04: Knowledge Base (standalone)
\i Intelligent_Task_04_Knowledge_Base.sql

-- Task 05: Spatial Queries (requires PostGIS)
\i Intelligent_Task_05_Spatial_Queries.sql
```

---

## Key Concepts Summary

### 1. Declarative Constraints (Task 01)
- **Purpose**: Enforce data integrity at the database level
- **Implementation**: CHECK constraints, FOREIGN KEY, NOT NULL
- **Benefits**: Automatic validation, no application code needed

### 2. Active Databases (Task 02)
- **Purpose**: Maintain derived data consistency automatically
- **Implementation**: Triggers (E-C-A pattern)
- **Benefits**: Real-time consistency, reduced application complexity

### 3. Deductive Databases (Task 03)
- **Purpose**: Derive facts from existing data using rules
- **Implementation**: Recursive CTEs (WITH RECURSIVE)
- **Benefits**: Hierarchical queries, transitive closure

### 4. Knowledge Bases (Task 04)
- **Purpose**: Represent and reason about domain knowledge
- **Implementation**: Triple store, recursive reasoning
- **Benefits**: Flexible ontology, semantic queries

### 5. Spatial Databases (Task 05)
- **Purpose**: Handle geographic data and spatial relationships
- **Implementation**: PostGIS extension, spatial indexes
- **Benefits**: Location-based queries, distance calculations

---

## Common Issues and Solutions

### Issue 1: Missing PostGIS Extension
**Error**: `extension "postgis" does not exist`  
**Solution**: 
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
-- Or install via package manager: sudo apt-get install postgis
```

### Issue 2: Missing Prerequisite Tables
**Error**: `relation "branch_kigali.member" does not exist`  
**Solution**: Run `ASSIGNMENT_3/Code/Task_01.sql` first to create distributed database schemas.

### Issue 3: Cycle Detection in Recursive Queries
**Error**: Infinite recursion  
**Solution**: Add cycle prevention with `WHERE HOPS < MAX_DEPTH` in recursive CTE.

### Issue 4: Spatial Reference System Mismatch
**Error**: `ST_Distance: Operation on mixed SRID geometries`  
**Solution**: Ensure all geometries use the same SRID (4326 for WGS84).

### Issue 5: Trigger Mutating Table
**Error**: `mutating table` or `cannot modify table that is being read`  
**Solution**: Use statement-level triggers with temporary tracking tables (as in Task 02).

---

## Performance Tips

1. **Spatial Indexes**: Always create GIST indexes on geometry columns
2. **Recursive Query Depth**: Limit recursion depth to prevent infinite loops
3. **Trigger Efficiency**: Use statement-level triggers for bulk operations
4. **Constraint Indexes**: PostgreSQL automatically creates indexes for PRIMARY KEY and UNIQUE constraints
5. **Statistics**: Run `ANALYZE` after creating tables for better query plans

---

## Testing Recommendations

### Task 01 - Constraints
- Test all constraint violations
- Verify foreign key cascades
- Test edge cases (NULL values, boundary values)

### Task 02 - Triggers
- Test INSERT, UPDATE, DELETE operations
- Test bulk operations (multiple rows)
- Verify audit trail completeness

### Task 03 - Recursive CTE
- Test with various hierarchy depths
- Test cycle detection
- Verify top supervisor identification

### Task 04 - Knowledge Base
- Test transitive closure completeness
- Verify member policy categorization
- Test with different taxonomy structures

### Task 05 - Spatial Queries
- Test with different radius values
- Verify distance calculations
- Test K-nearest neighbor with various K values

---

## References

- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **PostGIS Documentation**: https://postgis.net/documentation/
- **Recursive Queries**: https://www.postgresql.org/docs/current/queries-with.html
- **Triggers**: https://www.postgresql.org/docs/current/triggers.html
- **Constraints**: https://www.postgresql.org/docs/current/ddl-constraints.html
- **Spatial Indexing**: https://postgis.net/docs/using_postgis_dbmanagement.html#spatial_indexes

---

## Academic Context

**Course**: Advanced Database Technology  
**Assignment**: Intelligent Databases  
**Context**: SACCO (Savings and Credit Cooperative) System - Rwanda  
**Database**: PostgreSQL with PostGIS extension

---

## License

This is an academic project for educational purposes demonstrating intelligent database concepts.

---

**Last Updated**: 2025

