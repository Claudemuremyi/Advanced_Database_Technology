-- TASK 2: DATABASE LINKS SIMULATION USING POSTGRES_FDW
-------------------------------------------------------
-- Desctiption: Simulate distributed database access using Foreign Data Wrappers (FDW)
--------------------------------------------------------------------------------------

-- STEP 1: Enable postgres_fdw extension
-----------------------------------------
-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Verify extension is installed
SELECT * FROM pg_extension WHERE extname = 'postgres_fdw';

-- STEP 2: Create foreign server connections
---------------------------------------------

-- Drop existing servers if they exist
DROP SERVER IF EXISTS musanze_server CASCADE;
DROP SERVER IF EXISTS kigali_server CASCADE;

-- Create foreign server for Musanze branch (simulating remote connection)
CREATE SERVER musanze_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'sacco');

-- Create foreign server for Kigali branch
CREATE SERVER kigali_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'sacco');


-- STEP 3: Create user mappings for authentication
---------------------------------------------------

-- Map current user to foreign servers
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER musanze_server
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER kigali_server
    OPTIONS (user 'postgres', password 'postgres');

-- STEP 4: Create foreign tables in Kigali schema (accessing Musanze data)
--------------------------------------------------------------------------

-- Create foreign table to access Musanze members from Kigali
CREATE FOREIGN TABLE branch_kigali.remote_musanze_members (
    MemberID INT,
    FullName VARCHAR(100),
    Gender CHAR(1),
    Contact VARCHAR(15),
    Address TEXT,
    JoinDate DATE,
    Branch VARCHAR(50)
)
SERVER musanze_server
OPTIONS (schema_name 'branch_musanze', table_name 'member');

-- Create foreign table to access Musanze loans from Kigali
CREATE FOREIGN TABLE branch_kigali.remote_musanze_loans (
    LoanID INT,
    MemberID INT,
    OfficerID INT,
    Amount DECIMAL(12, 2),
    InterestRate DECIMAL(5, 2),
    StartDate DATE,
    Status VARCHAR(20)
)
SERVER musanze_server
OPTIONS (schema_name 'branch_musanze', table_name 'loanaccount');

-- STEP 5: Create foreign tables in Musanze schema (accessing Kigali data)
--------------------------------------------------------------------------

-- Create foreign table to access Kigali members from Musanze
CREATE FOREIGN TABLE branch_musanze.remote_kigali_members (
    MemberID INT,
    FullName VARCHAR(100),
    Gender CHAR(1),
    Contact VARCHAR(15),
    Address TEXT,
    JoinDate DATE,
    Branch VARCHAR(50)
)
SERVER kigali_server
OPTIONS (schema_name 'branch_kigali', table_name 'member');

-- Create foreign table to access Kigali loans from Musanze
CREATE FOREIGN TABLE branch_musanze.remote_kigali_loans (
    LoanID INT,
    MemberID INT,
    OfficerID INT,
    Amount DECIMAL(12, 2),
    InterestRate DECIMAL(5, 2),
    StartDate DATE,
    Status VARCHAR(20)
)
SERVER kigali_server
OPTIONS (schema_name 'branch_kigali', table_name 'loanaccount');

-- STEP 6: REMOTE SELECT QUERIES
---------------------------------

-- Query 1: From Kigali, access Musanze members (remote SELECT)
SELECT 
    'Remote Query from Kigali to Musanze' AS Query_Type,
    MemberID,
    FullName,
    Branch,
    Contact
FROM branch_kigali.remote_musanze_members
ORDER BY MemberID;

-- Query 2: From Musanze, access Kigali members (remote SELECT)
SELECT 
    'Remote Query from Musanze to Kigali' AS Query_Type,
    MemberID,
    FullName,
    Branch,
    Contact
FROM branch_musanze.remote_kigali_members
ORDER BY MemberID;

-- STEP 7: DISTRIBUTED JOIN QUERIES
------------------------------------

-- Distributed Join: Cross-branch member and loan analysis
SELECT 
    m.Branch,
    m.FullName,
    m.Contact,
    l.Amount AS Loan_Amount,
    l.InterestRate,
    l.Status AS Loan_Status
FROM (
    -- Combine members from both branches
    SELECT MemberID, FullName, Branch, Contact FROM branch_kigali.Member
    UNION ALL
    SELECT MemberID, FullName, Branch, Contact FROM branch_kigali.remote_musanze_members
) AS m
LEFT JOIN (
    -- Combine loans from both branches
    SELECT MemberID, Amount, InterestRate, Status FROM branch_kigali.LoanAccount
    UNION ALL
    SELECT MemberID, Amount, InterestRate, Status FROM branch_kigali.remote_musanze_loans
) AS l ON m.MemberID = l.MemberID
ORDER BY m.Branch, m.FullName;
