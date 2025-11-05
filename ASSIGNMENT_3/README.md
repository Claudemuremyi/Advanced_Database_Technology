# ASSIGNMENT_3 - Parallel and Distributed Databases

## Overview

This assignment demonstrates **parallel and distributed database concepts** using PostgreSQL. The project implements a **SACCO (Savings and Credit Cooperative) Insurance and Member Extension System** distributed across two branches: **Kigali** and **Musanze** in Rwanda.

## Quick Navigation

- **Code and Scripts**: See [Code/README.md](Code/README.md) for detailed task documentation
- **SQL Scripts**: Located in `Code/` directory
- **Screenshots**: Located in `Screenshoots/` directory
- **Reports**: Assignment reports and documentation in root directory

---

## Database Structure

- **Database Name**: `sacco`
- **DBMS**: PostgreSQL (pgAdmin 4)
- **Distributed Nodes**: 
  - `branch_kigali` (Schema 1)
  - `branch_musanze` (Schema 2)

---

## Prerequisites

### Software Requirements
- PostgreSQL 12+ with pgAdmin 4
- `postgres_fdw` extension (for database links simulation)
- `postgis` extension (optional, for spatial queries)

### Configuration Required
- **Prepared Transactions** (for Task 5):
  - Edit `postgresql.conf`: `max_prepared_transactions = 10`
  - Restart PostgreSQL server after configuration change

### Setup Extensions
```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
```

---

## Tasks Overview

### Task 01: Distributed Schema Design and Fragmentation
Horizontal fragmentation by splitting the SACCO database into two logical nodes based on branch location.

### Task 02: Database Links Simulation Using POSTGRES_FDW
Simulates distributed database access using Foreign Data Wrappers (FDW) to enable cross-node queries.

### Task 03: Parallel Query Execution
Demonstrates PostgreSQL's parallel query capabilities and compares serial vs parallel execution performance.

### Task 04: Two-Phase Commit Simulation
Demonstrates distributed transaction atomicity using cross-schema transactions.

### Task 05: Distributed Rollback and Recovery
Simulates network failure during distributed transactions and demonstrates recovery using prepared transactions.

### Task 06: Distributed Concurrency Control
Demonstrates lock conflicts when updating the same record from different nodes.

### Task 07: Parallel Data Loading / ETL Simulation
Demonstrates parallel data aggregation and loading using PostgreSQL parallel query execution.

### Task 08: Three-Tier Architecture
Demonstrates three-tier architecture concepts.

### Task 09: Distributed Query Optimization
Demonstrates query optimization techniques for distributed databases.

### Task 10: Performance Benchmark and Report
Comprehensive performance benchmarking comparing centralized, parallel, and distributed execution modes.

---

## Directory Structure

```
ASSIGNMENT_3/
├── README.md                              (This file)
├── Code/
│   ├── README.md                          (Detailed task documentation)
│   ├── Task_01.sql                        (Distributed Schema Design)
│   ├── Task_02.sql                        (Database Links/FDW)
│   ├── Task_03.sql                        (Parallel Query Execution)
│   ├── Task_04.sql                        (Two-Phase Commit)
│   ├── Task_05.sql                        (Rollback and Recovery)
│   ├── Task_06.sql                        (Concurrency Control)
│   ├── Task_07.sql                        (Parallel ETL)
│   ├── TASK_08_three_tier_architecture.sql (Three-Tier Architecture)
│   ├── Task_09.sql                        (Query Optimization)
│   ├── Task_10.sql                        (Performance Benchmark)
│   └── All_Tasks_01_10.sql                (Combined script)
├── Screenshoots/
│   ├── Task_01_Kigali Node data.png
│   ├── Task_01_Musanze Node data.png
│   ├── Task_02_Distributed Join Query.png
│   ├── Task_02_Remote Query from Kigali to Musanze.png
│   ├── Task_02_Remote Query from Musanze to Kigali.png
│   ├── Task_03_Explain Plan and Excution Time.png
│   ├── Task_04_Two phase commit A.png
│   ├── Task_04_Two phase commit B.png
│   ├── Task_05_Distributed Rollback and RecoveryA.jpg
│   ├── Task_05_Distributed Rollback and RecoveryB.jpg
│   ├── Task_07_Parallel DML aggregation.jpg
│   ├── Task_09_Distributed query optimization.png
│   ├── Task_10_Performance Benchmark and Report4.jpg
│   ├── Task_10_Performance Benchmark and ReportA.jpg
│   ├── Task_10_Performance Benchmark and ReportB.jpg
│   └── Task_10_Three tier.jpg
└── [Report files]
    ├── 216094186_NSHIMYUMUREMYI Claude_Assignment_3.docx
    ├── 216094186_NSHIMYUMUREMYI Claude_Assignment_3.pdf
    └── ...
```

---

## Quick Start

### 1. Create Database
```sql
CREATE DATABASE sacco;
\c sacco
```

### 2. Enable Extensions
```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
```

### 3. Run Tasks
```sql
-- Navigate to Code directory
\cd Code

-- Run tasks in order
\i Task_01.sql
\i Task_02.sql
\i Task_03.sql
-- ... continue with remaining tasks
```

**Or run all tasks at once:**
```sql
\i All_Tasks_01_10.sql
```

---

## Key Concepts Demonstrated

1. **Horizontal Fragmentation**: Data split across nodes by branch
2. **Database Links**: Foreign Data Wrappers for cross-node queries
3. **Parallel Execution**: Multi-worker query processing
4. **Distributed Transactions**: Atomic operations across nodes
5. **Recovery Mechanisms**: Handling transaction failures
6. **Concurrency Control**: Lock management in distributed systems
7. **Query Optimization**: Performance tuning for distributed queries
8. **Performance Benchmarking**: Comparing execution modes

---

## Common Issues

### Issue 1: FDW Connection Errors
**Error**: `could not connect to server`  
**Solution**: Verify server host, port, and database name in foreign server definitions.

### Issue 2: Prepared Transactions Disabled
**Error**: `prepared transactions are disabled`  
**Solution**: Set `max_prepared_transactions = 10` in `postgresql.conf` and restart PostgreSQL.

### Issue 3: Permission Errors
**Error**: `permission denied`  
**Solution**: Ensure user has proper privileges on all schemas and tables.

---

## For Detailed Documentation

See [Code/README.md](Code/README.md) for:
- Complete task descriptions
- Detailed setup instructions
- Execution examples
- Troubleshooting guides
- Performance tips
- Reference materials

---

## Academic Information

**Course**: Advanced Database Technology  
**Assignment**: ASSIGNMENT_3 - Parallel and Distributed Databases  
**Student**: 216094186_NSHIMYUMUREMYI Claude  
**Context**: Rwanda SACCO System  
**Database**: PostgreSQL with pgAdmin 4

---

## License

This is an academic project for educational purposes.

---

**Last Updated**: 2025


