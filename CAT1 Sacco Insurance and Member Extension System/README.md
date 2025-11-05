# CAT 1 - Relational Database Fundamentals

## Overview

This assignment implements a complete relational database system for a **SACCO (Savings and Credit Cooperative) Insurance and Member Extension System** operating in **Rwanda**. The project demonstrates fundamental database concepts including table design, constraints, data manipulation, queries, views, and triggers.

## Database Information

- **Database Name**: `sacco`
- **DBMS**: PostgreSQL (pgAdmin 4)
- **Context**: Rwanda SACCO operations across multiple branches
- **Currency**: Rwandan Francs (RWF)

---

## Tasks Overview

### Task 1: Define All Six Tables and Their Constraints
**File**: `Queries/01_02_create_tables.sql`

**Description**: Creates the complete database schema with six tables and all necessary constraints.

**Tables Created**:
1. **Member** - Member profile information
2. **Officer** - SACCO officer details across branches
3. **LoanAccount** - Member loan accounts
4. **InsurancePolicy** - Insurance policy details
5. **Claim** - Insurance claims filed by members
6. **Payment** - Payment records for settled claims

**Constraints Implemented**:
- PRIMARY KEY constraints
- FOREIGN KEY constraints with referential integrity
- CHECK constraints (data validation)
- UNIQUE constraints
- NOT NULL constraints
- Custom validation rules (e.g., contact format, date validation)

**Key Features**:
- Serial primary keys for auto-increment
- Default values for dates and statuses
- Contact format validation using regex
- Status validation using CHECK constraints

---

### Task 2: Apply CASCADE DELETE between Claim → Payment
**File**: `Queries/01_02_create_tables.sql` (Payment table)

**Description**: Implements CASCADE DELETE so that when a Claim is deleted, its associated Payment is automatically deleted.

**Implementation**:
```sql
CONSTRAINT fk_payment_claim FOREIGN KEY (ClaimID) 
    REFERENCES Claim(ClaimID) ON DELETE CASCADE
```

**Behavior**:
- When a Claim record is deleted, its related Payment record is automatically deleted
- Ensures referential integrity
- Prevents orphaned payment records

**Testing**:
- Delete a claim and verify its payment is automatically deleted
- Check that the cascade works correctly

---

### Task 3: Insert Data for 5 Members and 3 Policies
**File**: `Queries/03_insert_data.sql`

**Description**: Inserts sample data with realistic Rwandan context.

**Data Inserted**:
- **5 Members**: Rwandan names, addresses, and contact information
- **5 Officers**: Branch officers across Rwandan cities
- **5 Loan Accounts**: Loan records with Rwandan Franc amounts
- **3 Insurance Policies**: Life, Health, and Property insurance
- **3 Claims**: Insurance claims for the policies
- **2 Payments**: Payments for settled claims

**Key Features**:
- Realistic Rwandan names (e.g., "Nshuti Alice Uwase", "Hirwa Jean Claude Mugabo")
- Rwandan phone format: +250 7XX XXX XXX
- Rwandan locations: Kigali, Musanze, Huye, Rubavu, Nyagatare
- Amounts in Rwandan Francs (RWF)
- Future dates to ensure policies remain active

**Important Note**: Policy EndDates are set to 2025-2026 to ensure they remain Active (not expired by trigger).

---

### Task 4: Retrieve All Active Insurance Policies
**File**: `Queries/04_query_active_policies.sql`

**Description**: Query to retrieve all insurance policies with status 'Active', including member details.

**Query Features**:
- Joins InsurancePolicy with Member table
- Filters by Status = 'Active'
- Displays comprehensive policy information:
  - Policy ID and Member ID
  - Member name, contact, and location
  - Policy type and premium (formatted in RWF)
  - Start and end dates
  - Policy health status (Active, Expiring Soon, Expired)

**Output Columns**:
- PolicyID
- MemberID
- MemberName
- Contact
- Location
- PolicyType
- Premium (formatted as RWF)
- StartDate
- EndDate
- Status
- PolicyHealth (calculated field)

**Ordering**: Results sorted by StartDate DESC (newest first)

---

### Task 5: Update Claim Status After Settlement
**File**: `Queries/05_update_claim_status.sql`

**Description**: Updates claim status to 'Settled' when payment is processed.

**Implementation Examples**:
1. **Update specific claim**:
   ```sql
   UPDATE Claim SET Status = 'Settled' 
   WHERE ClaimID = 3 AND Status = 'Approved';
   ```

2. **Update all approved claims with payments**:
   ```sql
   UPDATE Claim SET Status = 'Settled'
   WHERE ClaimID IN (
       SELECT c.ClaimID
       FROM Claim c
       INNER JOIN Payment p ON c.ClaimID = p.ClaimID
       WHERE c.Status = 'Approved'
   );
   ```

**Features**:
- Before/after verification queries
- Payment status checking
- Automatic status updates based on payment existence

---

### Task 6: Identify Members with Multiple Insurance Policies
**File**: `Queries/06_multiple_policies.sql`

**Description**: Identifies and lists members who have more than one insurance policy.

**Query Features**:
- Uses GROUP BY and HAVING to filter members with multiple policies
- Displays member details and policy counts
- Shows total premium amounts
- Lists all policy types per member
- Distinguishes between active and expired policies

**Multiple Query Variations**:
1. Basic query with policy count
2. Detailed query with policy breakdown
3. Query for members with multiple ACTIVE policies only

**Output Information**:
- Member ID and name
- Total number of policies
- Active vs expired policy counts
- Total annual premium
- Policy types and statuses

---

### Task 7: Create a View Showing Total Premiums Collected Per Month
**File**: `Queries/07_create_views.sql`

**Description**: Creates a view that aggregates premium collection by month and year.

**View Created**: `vw_MonthlyPremiumCollection`

**View Features**:
- Aggregates premiums by year and month
- Calculates total premiums collected
- Counts policies and unique members
- Calculates average, minimum, and maximum premiums
- Lists policy types per month
- Formatted output with RWF currency

**Additional Views**:
- `vw_MonthlyPremiumSummary` - Formatted summary with percentages
- `vw_YearlyPremiumComparison` - Year-over-year comparison

**Query the View**:
```sql
SELECT * FROM vw_MonthlyPremiumCollection;
```

---

### Task 8: Implement a Trigger That Automatically Closes Policy Upon End Date
**File**: `Queries/08_create_trigger.sql`

**Description**: Creates a trigger that automatically updates policy status to 'Expired' when the EndDate is reached or passed.

**Trigger Details**:
- **Trigger Name**: `trg_AutoExpirePolicy`
- **Trigger Type**: BEFORE INSERT OR UPDATE
- **Trigger Level**: ROW-level
- **Function**: `fn_AutoExpirePolicy()`

**Trigger Logic**:
```sql
IF NEW.EndDate <= CURRENT_DATE AND NEW.Status = 'Active' THEN
    NEW.Status := 'Expired';
END IF;
```

**Features**:
- Automatically expires policies on insert/update
- Logs expiration notices
- Includes stored procedure for batch expiration
- Handles both new and existing policies

**Additional Features**:
- Stored procedure `sp_ExpireOldPolicies()` for batch processing
- Can be scheduled to run daily via cron or pg_cron

---

## File Structure

```
CAT 1/
├── README.md                          (This file)
├── Queries/
│   ├── 01_02_create_tables.sql        (Tasks 1 & 2: Tables and CASCADE)
│   ├── 03_insert_data.sql             (Task 3: Data insertion)
│   ├── 04_query_active_policies.sql   (Task 4: Active policies query)
│   ├── 05_update_claim_status.sql     (Task 5: Update claim status)
│   ├── 06_multiple_policies.sql      (Task 6: Multiple policies query)
│   ├── 07_create_views.sql            (Task 7: Monthly premium view)
│   ├── 08_create_trigger.sql         (Task 8: Auto-expire trigger)
│   ├── 08_bonus_queries.sql          (Additional bonus queries)
│   ├── 09_verification.sql           (Verification queries)
│   └── TASK_VERIFICATION_SUMMARY.md   (Task verification summary)
└── Screenshoots/
    ├── 01_ERD_Shema.png
    ├── 02_Apply CASCADE DELETE.jpg
    ├── 03_Insert data_ record for all tables.jpg
    ├── 04_query_active_policies.jpg
    ├── 05_multiple_policies.png
    ├── 06_Views.png
    ├── 07_Trigger.png
    ├── STUDENT 31.docx
    └── STUDENT 31.pdf
```

---

## Setup Instructions

### 1. Create Database
```sql
CREATE DATABASE sacco;
\c sacco
```

### 2. Run Scripts in Order
```sql
-- Step 1: Create tables and constraints (Tasks 1 & 2)
\i Queries/01_02_create_tables.sql

-- Step 2: Insert sample data (Task 3)
\i Queries/03_insert_data.sql

-- Step 3: Create views (Task 7)
\i Queries/07_create_views.sql

-- Step 4: Create trigger (Task 8)
\i Queries/08_create_trigger.sql

-- Step 5: Run queries (Tasks 4, 5, 6)
\i Queries/04_query_active_policies.sql
\i Queries/05_update_claim_status.sql
\i Queries/06_multiple_policies.sql

-- Step 6: Verification
\i Queries/09_verification.sql
```

---

## Database Schema

### Entity-Relationship Overview

```
Member (1) ────< (N) LoanAccount
Member (1) ────< (N) InsurancePolicy
InsurancePolicy (1) ────< (N) Claim
Claim (1) ────< (1) Payment [CASCADE DELETE]
Officer (1) ────< (N) LoanAccount
```

### Table Details

#### Member Table
- Primary Key: `MemberID` (SERIAL)
- Unique: `Contact`
- Constraints: Gender check, contact format validation

#### Officer Table
- Primary Key: `OfficerID` (SERIAL)
- Unique: `Contact`
- Branch information for distributed operations

#### LoanAccount Table
- Primary Key: `LoanID` (SERIAL)
- Foreign Keys: `MemberID` → Member, `OfficerID` → Officer
- Constraints: Amount > 0, InterestRate 0-100, Status validation

#### InsurancePolicy Table
- Primary Key: `PolicyID` (SERIAL)
- Foreign Key: `MemberID` → Member
- Constraints: Premium > 0, EndDate > StartDate, Status validation
- Trigger: Auto-expires when EndDate reached

#### Claim Table
- Primary Key: `ClaimID` (SERIAL)
- Foreign Key: `PolicyID` → InsurancePolicy
- Constraints: AmountClaimed > 0, Status validation

#### Payment Table
- Primary Key: `PaymentID` (SERIAL)
- Foreign Key: `ClaimID` → Claim (UNIQUE, CASCADE DELETE)
- Constraints: Amount > 0, Method validation

---

## Testing and Verification

### Verify Table Creation
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

### Verify Data Insertion
```sql
SELECT 'Members' AS Table_Name, COUNT(*) AS Count FROM Member
UNION ALL
SELECT 'Policies', COUNT(*) FROM InsurancePolicy
UNION ALL
SELECT 'Claims', COUNT(*) FROM Claim
UNION ALL
SELECT 'Payments', COUNT(*) FROM Payment;
```

### Test CASCADE DELETE
```sql
-- Insert a claim with payment
INSERT INTO Claim (PolicyID, AmountClaimed, Status) VALUES (1, 100000.00, 'Settled');
INSERT INTO Payment (ClaimID, Amount, Method) VALUES (CURRVAL('claim_claimid_seq'), 100000.00, 'Bank Transfer');

-- Delete the claim
DELETE FROM Claim WHERE ClaimID = CURRVAL('claim_claimid_seq');

-- Verify payment was also deleted
SELECT COUNT(*) FROM Payment WHERE ClaimID = CURRVAL('claim_claimid_seq'); -- Should return 0
```

### Test Trigger
```sql
-- Insert a policy with past end date
INSERT INTO InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
VALUES (1, 'Health', 180000.00, '2022-01-01', '2023-01-01', 'Active');

-- Check if status was automatically changed to 'Expired'
SELECT PolicyID, Status, EndDate FROM InsurancePolicy WHERE EndDate < CURRENT_DATE;
```

---

## Common Issues and Solutions

### Issue 1: Query Returns No Active Policies
**Problem**: Query in `04_query_active_policies.sql` returns 0 rows.

**Cause**: Policies have EndDates in the past, and the trigger automatically expires them.

**Solution**: Ensure policy EndDates are in the future (2025-2026 or later):
```sql
UPDATE InsurancePolicy 
SET EndDate = '2026-12-31' 
WHERE EndDate < CURRENT_DATE;
```

### Issue 2: CASCADE DELETE Not Working
**Problem**: Payment records remain after deleting Claim.

**Solution**: Verify foreign key constraint:
```sql
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'payment'::regclass
AND contype = 'f';
```

### Issue 3: Trigger Not Firing
**Problem**: Policies with past EndDate remain Active.

**Solution**: Verify trigger exists and is enabled:
```sql
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_name = 'trg_autoexpirepolicy';
```

---

## Key Features Demonstrated

1. ✅ **Complete Database Design**: Six tables with proper relationships
2. ✅ **Data Integrity**: Constraints ensure data quality
3. ✅ **CASCADE DELETE**: Automatic cleanup of related records
4. ✅ **Complex Queries**: Joins, aggregations, and subqueries
5. ✅ **Views**: Pre-computed aggregations for reporting
6. ✅ **Triggers**: Automated business logic enforcement
7. ✅ **Data Validation**: CHECK constraints and format validation
8. ✅ **Referential Integrity**: Foreign key constraints

---

## Data Context: Rwanda

All data reflects realistic Rwandan context:
- **Names**: Rwandan names (e.g., Nshuti, Hirwa, Uwase, Mukamana)
- **Locations**: Kigali, Musanze, Huye, Rubavu, Nyagatare
- **Phone Numbers**: +250 7XX XXX XXX format
- **Currency**: Rwandan Francs (RWF)
- **Amounts**: Realistic SACCO loan and insurance amounts

---

## Academic Information

**Course**: Advanced Database Technology  
**Assignment**: CAT 1 - Relational Database Fundamentals  
**Student**: 216094186_NSHIMYUMUREMYI Claude  
**Context**: Rwanda SACCO Insurance and Member Extension System  
**Database**: PostgreSQL with pgAdmin 4

---

## References

- PostgreSQL Documentation: https://www.postgresql.org/docs/
- SQL Constraints: https://www.postgresql.org/docs/current/ddl-constraints.html
- Triggers: https://www.postgresql.org/docs/current/triggers.html
- Views: https://www.postgresql.org/docs/current/sql-createview.html

---

## License

This is an academic project for educational purposes.

---

**Last Updated**: 2025

