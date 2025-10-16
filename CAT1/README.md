# SACCO Insurance and Member Extension System

**CAT1 - Advanced Database Technology**

---

## 📋 Project Information

- **Full Name:** Claude Nshimyumuremyi
- **Institution:** [Your University/Institution Name]
- **Course:** Advanced Database Technology
- **Assessment:** CAT1
- **Database Systems:** PostgreSQL (pgAdmin 4)
- **Date:** 16th January 2025

---

## Project Objective

This project implements a comprehensive **SACCO Insurance and Member Extension System** for Rwandan financial cooperatives. The system tracks:

- Member profiles and registration
- Loan accounts and officer management
- Insurance policies (Life, Health, Property, Loan Protection, Accident)
- Claims processing and settlement
- Payment tracking with multiple methods

The database design demonstrates advanced SQL concepts including:
- Table's relationships (1:1, 1:N)
- CASCADE DELETE constraints
- Triggers for automatic policy expiration
- Views for premium collection analysis
- Data integrity through CHECK constraints

---

## 🗄️ Database Schema

1. Member(MemberID, FullName, Gender, Contact, Address, JoinDate)
2. Officer(OfficerID, FullName, Branch, Contact, Role)
3. LoanAccount(LoanID, MemberID, OfficerID, Amount, InterestRate,
StartDate, Status)
4. InsurancePolicy(PolicyID, MemberID, Type, Premium, StartDate, EndDate,
Status)
5. Claim(ClaimID, PolicyID, DateFiled, AmountClaimed, Status)
6. Payment(PaymentID, ClaimID, Amount, PaymentDate, Method)
   
### Tables Created

1. **Member** - Stores SACCO member profiles
2. **Officer** - Manages SACCO staff across branches
3. **LoanAccount** - Tracks member loans
4. **InsurancePolicy** - Records insurance coverage
5. **Claim** - Manages insurance claims
6. **Payment** - Processes claim settlements

### Key Relationships

\`\`\`
Member (1) ──→ (N) LoanAccount
Member (1) ──→ (N) InsurancePolicy
Officer (1) ──→ (N) LoanAccount
InsurancePolicy (1) ──→ (N) Claim
Claim (1) ──→ (1) Payment [CASCADE DELETE]
\`\`\`

---

## ✨ Key Features Implemented

### Task 1: Database Design
- ✅ Six normalized tables with proper constraints
- ✅ Primary keys (SERIAL auto-increment)
- ✅ Foreign keys with CASCADE/RESTRICT rules
- ✅ CHECK constraints for data validation

### Task 2: Sample Data
- ✅ 5 Rwandan members with realistic data
- ✅ 5 officers across Rwandan branches (Kigali, Musanze, Huye, Rubavu, Nyagatare)
- ✅ 5 loan accounts with varying amounts
- ✅ 5 insurance policies (multiple types)
- ✅ 5 claims with different statuses
- ✅ 5 payments using various methods

### Task 3: Active Policies Query
- ✅ Retrieves all active insurance policies
- ✅ Displays member information and policy details
- ✅ Calculates policy duration in months

### Task 4: Claim Status Updates
- ✅ Updates claims to 'Settled' after payment
- ✅ Validates payment existence before update

### Task 5: Multiple Policies Analysis
- ✅ Identifies members with multiple insurance policies
- ✅ Aggregates total premium amounts
- ✅ Lists all policy types per member

### Task 6: Premium Collection Views
- ✅ Monthly premium aggregation view
- ✅ Yearly comparison view
- ✅ Formatted currency display (RWF)

### Task 7: Auto-Expiration Trigger
- ✅ Automatically expires policies when EndDate is reached
- ✅ Trigger fires on INSERT and UPDATE
- ✅ Stored procedure for batch expiration

---
## 📂 Project Structure

\`\`\`
CAT1/
├── README.md                          # This file
├── Oracle_Postgres_Code/
│   ├── PostgreSQL/
│   │   ├── 00_master_setup.sql       # Complete setup in one file
│   │   ├── 01_create_tables.sql      # Table definitions
│   │   ├── 02_insert_data.sql        # Sample data insertion
│   │   ├── 03_query_active_policies.sql
│   │   ├── 04_update_claim_status.sql
│   │   ├── 05_multiple_policies.sql
│   │   ├── 06_create_views.sql
│   │   ├── 07_create_trigger.sql
│   │   ├── 08_bonus_queries.sql
│   │   ├── 09_verification.sql
│   │   └── test_cascade_simple.sql   # CASCADE DELETE demo
│   └── Oracle/
│       └── [Oracle-compatible versions]
└── Screenshots/
    ├── 01_table_structure.png
    ├── 02_sample_data.png
    ├── 03_active_policies_query.png
    ├── 04_multiple_policies.png
    ├── 05_views_output.png
    ├── 06_trigger_test.png
    └── 07_cascade_delete_demo.png
\`\`\`

---

## 📊 Sample Queries

### View All Members
\`\`\`sql
SELECT * FROM Member ORDER BY JoinDate DESC;
\`\`\`

### Check Active Policies
\`\`\`sql
SELECT * FROM vw_MonthlyPremiumCollection;
\`\`\`

### Test Trigger
\`\`\`sql
-- Insert expired policy (should auto-expire)
INSERT INTO InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status)
VALUES (1, 'Health', 180000.00, '2022-01-01', '2023-01-01', 'Active');
\`\`\`

### Test CASCADE DELETE
\`\`\`sql
-- Delete a claim (payment should be deleted automatically)
DELETE FROM Claim WHERE ClaimID = 2;
\`\`\`

---

## 🔍 Key SQL Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| **Normalization** | 3NF database design |
| **Constraints** | PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE |
| **Relationships** | 1:1, 1:N with proper CASCADE rules |
| **Triggers** | Auto-expire policies on date |
| **Views** | Aggregated premium reports |
| **Joins** | INNER JOIN for related data |
| **Aggregation** | COUNT, SUM, AVG, STRING_AGG |
| **Subqueries** | Nested SELECT for updates |
| **Transactions** | COMMIT/ROLLBACK for data integrity |

---

## 🧪 Testing & Verification

Run the verification script to ensure everything is set up correctly:

\`\`\`sql
\i '09_verification.sql'
\`\`\`

Expected output:
- ✅ 6 tables created
- ✅ All foreign keys properly configured
- ✅ CASCADE DELETE verified on Payment → Claim
- ✅ 3 views created
- ✅ 1 trigger active
- ✅ Sample data inserted (5+ records per table)

---

## 📸 Screenshots

All query results and database structure screenshots are available in the `Screenshots/` folder:

1. **Table Structure** - Shows all 6 tables with columns and data types
2. **Sample Data** - Displays inserted Rwandan member and policy data
3. **Active Policies Query** - Results from Task 3
4. **Multiple Policies Analysis** - Results from Task 5
5. **Views Output** - Monthly and yearly premium reports
6. **Trigger Testing** - Auto-expiration demonstration
7. **CASCADE DELETE Demo** - Before/after deletion states

---

## 🛠️ Technologies Used

- **Database:** PostgreSQL 16
- **Client Tool:** pgAdmin 4
- **SQL Standard:** SQL:2016
- **Version Control:** Git & GitHub
- **Documentation:** Markdown

---

## 📝 Notes

- All monetary values are in **Rwandan Francs (RWF)**
- Phone numbers follow Rwanda format: `+2507XXXXXXXX`
- Branches represent actual Rwandan districts
- Sample data uses authentic Rwandan names
- The system is designed for educational purposes

---

## 🤝 Contributing

This is an academic project for CAT1 assessment. For questions or suggestions:

- **GitHub:** [@Claudemuremyi](https://github.com/Claudemuremyi)
- **Repository:** [Advanced_Database_Technology](https://github.com/Claudemuremyi/Advanced_Database_Technology)

---

## 📄 License

This project is created for educational purposes as part of the Advanced Database Technology course.

---

## 🎓 Learning Outcomes

By completing this project, I demonstrated proficiency in:

✅ Database design and normalization  
✅ Complex SQL query writing  
✅ Constraint implementation and enforcement  
✅ Trigger creation and testing  
✅ View design for reporting  
✅ CASCADE DELETE relationships  
✅ Data integrity and validation  
✅ PostgreSQL-specific features  

---

**Last Updated:** January 2025  
**Status:** ✅ Completed and Tested
