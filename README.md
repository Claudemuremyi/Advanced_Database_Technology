# Advanced Database Technology - Course Projects

## Overview

This repository contains comprehensive database projects demonstrating advanced database concepts including:
- **Relational Database Design** (CAT 1)
- **Parallel and Distributed Databases** (ASSIGNMENT_3)
- **Intelligent Databases** (INTELIGENT DATABASE)
- **Advanced Database Exam** (ADVANCED DATABASE EXAM)

All projects are implemented using **PostgreSQL**. Most projects use a **SACCO (Savings and Credit Cooperative) Insurance and Member Extension System** context in **Rwanda**, while the exam project uses a **Restaurant Order and Billing Management System**.

---

## Repository Structure

```
Advanced_Database_Technology/
├── README.md                          (This file)
├── CAT 1/                             (Relational Database Fundamentals)
│   ├── README.md                      (CAT 1 documentation)
│   ├── Queries/                       (SQL scripts)
│   └── Screenshoots/                  (Screenshots and documentation)
├── ASSIGNMENT_3/                      (Parallel and Distributed Databases)
│   ├── README.md                      (Assignment 3 documentation)
│   ├── Code/                          (SQL scripts and README)
│   ├── Screenshoots/                  (Task screenshots)
│   └── [Report files]
├── INTELIGENT DATABASE/               (Intelligent Database Concepts)
│   ├── README.md                      (Intelligent Database documentation)
│   ├── [Task SQL files]
│   └── Screenshoots/                  (Task screenshots)
└── ADVANCED DATABASE EXAM/            (Database Exam - Restaurant System)
    ├── README.md                      (Exam documentation in restaurant-db-exam/)
    ├── restaurant-db-exam/            (Main exam project with README)
    ├── RESTAURANTDB/                  (SQL scripts)
    ├── Screenshoots/                  (Task screenshots)
    └── [Report files]
```

---

## Project Components

### 1. CAT 1 - Relational Database Fundamentals
**Location**: `CAT 1/`

**Description**: Implements a complete relational database system with tables, constraints, queries, views, and triggers.

**Key Features**:
- Six-table database design (Member, Officer, LoanAccount, InsurancePolicy, Claim, Payment)
- CASCADE DELETE implementation
- Data insertion (5 members, 3 policies)
- Active policy queries
- Claim status updates
- Multiple policy identification
- Monthly premium views
- Auto-expiring policy triggers

**See**: [CAT 1/README.md](CAT%201/README.md) for detailed documentation.

---

### 2. ASSIGNMENT_3 - Parallel and Distributed Databases
**Location**: `ASSIGNMENT_3/`

**Description**: Demonstrates distributed database concepts including fragmentation, database links, parallel execution, and distributed transactions.

**Key Features**:
- Horizontal fragmentation (Kigali and Musanze branches)
- Foreign Data Wrappers (FDW) for database links
- Parallel query execution
- Two-phase commit (2PC) simulation
- Distributed rollback and recovery
- Concurrency control
- Parallel ETL operations
- Query optimization
- Performance benchmarking

**See**: [ASSIGNMENT_3/README.md](ASSIGNMENT_3/README.md) for detailed documentation.

---

### 3. INTELIGENT DATABASE - Intelligent Database Concepts
**Location**: `INTELIGENT DATABASE/`

**Description**: Implements intelligent database features including constraints, triggers, recursive queries, knowledge bases, and spatial databases.

**Key Features**:
- Declarative constraints (rules)
- Active databases (E-C-A triggers)
- Deductive databases (recursive CTEs)
- Knowledge bases (triple store ontology)
- Spatial databases (PostGIS)

**See**: [INTELIGENT DATABASE/README.md](INTELIGENT%20DATABASE/README.md) for detailed documentation.

---

### 4. ADVANCED DATABASE EXAM - Restaurant Order and Billing System
**Location**: `ADVANCED DATABASE EXAM/`

**Description**: Comprehensive database exam project implementing a **Restaurant Order and Billing Management System** with distributed database operations and advanced database features.

**Key Features**:
- **Section A - Distributed Database Operations**:
  - Horizontal fragmentation and fragment recombination
  - Database links using postgres_fdw
  - Parallel vs serial aggregation comparison
  - Two-phase commit (2PC) and recovery
  - Distributed lock conflict diagnosis
  
- **Section B - Advanced Database Features**:
  - Declarative rules (constraints hardening)
  - E-C-A triggers for denormalized totals
  - Recursive CTE for hierarchical queries
  - Knowledge base with triple store
  - Business limit alerts with triggers

**Database**: `restaurant` with Node_A and Node_B (simulated using postgres_fdw)

**See**: [ADVANCED DATABASE EXAM/restaurant-db-exam/README.md](ADVANCED%20DATABASE%20EXAM/restaurant-db-exam/README.md) for detailed documentation.

---

## Prerequisites

### Software Requirements
- **PostgreSQL 12+** (recommended: PostgreSQL 14 or later)
- **pgAdmin 4** (for GUI management)
- **PostGIS Extension** (for spatial database tasks)

### PostgreSQL Extensions Required
```sql
-- For distributed databases (ASSIGNMENT_3)
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- For spatial queries (INTELIGENT DATABASE)
CREATE EXTENSION IF NOT EXISTS postgis;
```

### System Configuration
- **Prepared Transactions** (for ASSIGNMENT_3 Task 5):
  - Edit `postgresql.conf`: `max_prepared_transactions = 10`
  - Restart PostgreSQL server after configuration change

---

## Quick Start Guide

### 1. Database Setup
```sql
-- Create the main database
CREATE DATABASE sacco;

-- Connect to the database
\c sacco
```

### 2. Run Projects

#### CAT 1 - Basic Database
```sql
-- Navigate to CAT 1/Queries/
\i 01_02_create_tables.sql
\i 03_insert_data.sql
\i 04_query_active_policies.sql
```

#### ASSIGNMENT_3 - Distributed Databases
```sql
-- Navigate to ASSIGNMENT_3/Code/
\i Task_01.sql  -- Create distributed schemas
\i Task_02.sql  -- Setup FDW
\i Task_03.sql  -- Parallel queries
-- ... continue with remaining tasks
```

#### INTELIGENT DATABASE
```sql
-- Navigate to INTELIGENT DATABASE/
CREATE EXTENSION IF NOT EXISTS postgis;
\i Intelligent_Task_01_Constraints.sql
\i Intelligent_Task_02_Triggers.sql
-- ... continue with remaining tasks
```

#### ADVANCED DATABASE EXAM - Restaurant System
```sql
-- Create restaurant database
CREATE DATABASE restaurant;
\c restaurant

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Navigate to ADVANCED DATABASE EXAM/restaurant-db-exam/scripts/
-- See restaurant-db-exam/README.md for detailed execution instructions
```

---

## Database Schema Overview

### Core Tables (SACCO System)
1. **Member** - Member profile information
2. **Officer** - SACCO officer details across branches
3. **LoanAccount** - Member loan accounts
4. **InsurancePolicy** - Insurance policy details
5. **Claim** - Insurance claims
6. **Payment** - Claim payment records

### Relationships
- Member → LoanAccount (1:many)
- Member → InsurancePolicy (1:many)
- InsurancePolicy → Claim (1:many)
- Claim → Payment (1:1 with CASCADE DELETE)
- Officer → LoanAccount (1:many)

---

## Context: Database Systems

### Rwanda SACCO System (CAT 1, ASSIGNMENT_3, INTELIGENT DATABASE)
All main projects are designed with a **Rwandan context**:
- **Locations**: Kigali, Musanze, Huye, Rubavu, Nyagatare
- **Currency**: Rwandan Francs (RWF)
- **Phone Format**: +250 7XX XXX XXX
- **Realistic Data**: Rwandan names and addresses

### Restaurant Order and Billing System (ADVANCED DATABASE EXAM)
The exam project implements a **Restaurant Order and Billing Management System**:
- **Context**: Restaurant operations with orders, menus, staff, and billing
- **Database**: `restaurant` with distributed nodes (Node_A and Node_B)
- **Focus**: Distributed database operations and advanced database features

---

## Key Database Concepts Demonstrated

### 1. Relational Database Design
- Entity-Relationship modeling
- Normalization
- Referential integrity
- Constraints (CHECK, FOREIGN KEY, UNIQUE, NOT NULL)
- CASCADE DELETE

### 2. Distributed Database Systems
- Horizontal fragmentation
- Database links (FDW)
- Distributed transactions
- Two-phase commit
- Concurrency control
- Query optimization

### 3. Parallel Database Processing
- Parallel query execution
- Parallel workers
- Performance optimization
- ETL operations

### 4. Intelligent Database Features
- Declarative constraints (rules)
- Active databases (triggers)
- Deductive databases (recursive queries)
- Knowledge bases (ontology)
- Spatial databases (PostGIS)

---

## File Organization

### SQL Script Naming Convention
- **CAT 1**: `01_02_create_tables.sql`, `03_insert_data.sql`, etc.
- **ASSIGNMENT_3**: `Task_01.sql`, `Task_02.sql`, etc.
- **INTELIGENT DATABASE**: `Intelligent_Task_01_Constraints.sql`, etc.
- **ADVANCED DATABASE EXAM**: `1_create_tables.sql`, `A1_fragment_recombine.sql`, `B6_constraints_hardening.sql`, etc.

### Documentation
- Each directory contains a `README.md` with detailed task descriptions
- Screenshots are organized in `Screenshoots/` directories
- Verification scripts are included for testing

---

## Common Issues and Solutions

### Issue 1: Extension Not Found
**Error**: `extension "postgres_fdw" does not exist`  
**Solution**: 
```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Issue 2: Prepared Transactions Disabled
**Error**: `prepared transactions are disabled`  
**Solution**: Set `max_prepared_transactions = 10` in `postgresql.conf` and restart PostgreSQL.

### Issue 3: Permission Denied
**Error**: `permission denied`  
**Solution**: Ensure database user has proper privileges:
```sql
GRANT ALL ON DATABASE sacco TO your_user;
GRANT ALL ON SCHEMA public TO your_user;
```

### Issue 4: Missing Prerequisites
**Error**: `relation "branch_kigali.member" does not exist`  
**Solution**: Run prerequisite scripts in order (e.g., Task_01.sql before intelligent tasks).

---

## Testing and Verification

### CAT 1 Verification
```sql
-- Run verification queries
\i 09_verification.sql

-- Test CASCADE DELETE
-- (See CAT 1/Queries/ for test scripts)
```

### ASSIGNMENT_3 Verification
- Check distributed schemas exist
- Verify FDW connections
- Test parallel query execution
- Monitor distributed transactions

### INTELIGENT DATABASE Verification
- Test constraint violations
- Verify trigger functionality
- Test recursive queries
- Validate spatial queries

### ADVANCED DATABASE EXAM Verification
- Verify fragment recombination (checksums)
- Test distributed joins and queries
- Compare parallel vs serial execution
- Validate two-phase commit recovery
- Test constraint hardening and triggers
- Verify recursive queries and knowledge bases

---

## Performance Tips

1. **Indexes**: Create indexes on frequently filtered columns
2. **Statistics**: Run `ANALYZE` regularly for better query plans
3. **Parallel Workers**: Adjust `max_parallel_workers_per_gather` based on CPU cores
4. **Spatial Indexes**: Always create GIST indexes on geometry columns
5. **Connection Pooling**: Use connection pooling for distributed queries

---

## Academic Information

**Course**: Advanced Database Technology  
**Student**: 216094186_NSHIMYUMUREMYI Claude  
**Institution**: University of Rwanda African Centre of Excellence in Data Science (ACE-DS) 
**Context**: SACCO Insurance and Member Extension System for CAT1 and Assignment_3 and Restaurant Order and Billing Management System for Exam 
**Database Management System**: PostgreSQL 12+ with pgAdmin 4

---

## References

- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **PostGIS Documentation**: https://postgis.net/documentation/
- **Foreign Data Wrappers**: https://www.postgresql.org/docs/current/postgres-fdw.html
- **Parallel Query Execution**: https://www.postgresql.org/docs/current/parallel-query.html
- **Recursive Queries**: https://www.postgresql.org/docs/current/queries-with.html
- **Triggers**: https://www.postgresql.org/docs/current/triggers.html

---

## License

This is an academic project for educational purposes demonstrating advanced database technology concepts.

---

## Contact

For questions or issues related to this project, please refer to the individual README files in each directory for specific task documentation.

---

