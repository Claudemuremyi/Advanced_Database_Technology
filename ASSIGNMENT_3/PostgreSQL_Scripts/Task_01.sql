-- TASK 1: DISTRIBUTED SCHEMA DESIGN AND FRAGMENTATION
-------------------------------------------------------
-- Desctiption: Split SACCO database into two logical nodes (branch_kigali and branch_musanze)
-- using horizontal fragmentation based on branch location
------------------------------------------------------------------------------------------------

-- STEP 1: Create separate schemas for each branch
---------------------------------------------------

-- Drop schemas if they exist (for clean setup)
DROP SCHEMA IF EXISTS branch_kigali CASCADE;
DROP SCHEMA IF EXISTS branch_musanze CASCADE;

-- Create branch schemas
CREATE SCHEMA branch_kigali;
CREATE SCHEMA branch_musanze;

COMMENT ON SCHEMA branch_kigali IS 'Kigali branch - distributed node 1';
COMMENT ON SCHEMA branch_musanze IS 'Musanze branch - distributed node 2';

-- STEP 2: Create fragmented tables in branch_kigali schema
------------------------------------------------------------

-- Members in Kigali branch
CREATE TABLE branch_kigali.Member (
    MemberID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')),
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Address TEXT,
    JoinDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Branch VARCHAR(50) NOT NULL DEFAULT 'Kigali',
    CONSTRAINT chk_kigali_branch CHECK (Branch = 'Kigali')
);

-- Officers in Kigali branch
CREATE TABLE branch_kigali.Officer (
    OfficerID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Branch VARCHAR(50) NOT NULL DEFAULT 'Kigali',
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Role VARCHAR(50) NOT NULL,
    CONSTRAINT chk_kigali_officer_branch CHECK (Branch = 'Kigali')
);

-- Loan Accounts in Kigali branch
CREATE TABLE branch_kigali.LoanAccount (
    LoanID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    OfficerID INT NOT NULL,
    Amount DECIMAL(12, 2) NOT NULL CHECK (Amount > 0),
    InterestRate DECIMAL(5, 2) NOT NULL CHECK (InterestRate >= 0 AND InterestRate <= 100),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_kigali_loan_member FOREIGN KEY (MemberID) 
        REFERENCES branch_kigali.Member(MemberID) ON DELETE CASCADE,
    CONSTRAINT fk_kigali_loan_officer FOREIGN KEY (OfficerID) 
        REFERENCES branch_kigali.Officer(OfficerID) ON DELETE RESTRICT
);

-- Insurance Policies in Kigali branch
CREATE TABLE branch_kigali.InsurancePolicy (
    PolicyID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Type VARCHAR(50) NOT NULL,
    Premium DECIMAL(10, 2) NOT NULL CHECK (Premium > 0),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    EndDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_kigali_policy_member FOREIGN KEY (MemberID) 
        REFERENCES branch_kigali.Member(MemberID) ON DELETE CASCADE
);

-- STEP 3: Create fragmented tables in branch_musanze schema
-------------------------------------------------------------

-- Members in Musanze branch
CREATE TABLE branch_musanze.Member (
    MemberID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')),
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Address TEXT,
    JoinDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Branch VARCHAR(50) NOT NULL DEFAULT 'Musanze',
    CONSTRAINT chk_musanze_branch CHECK (Branch = 'Musanze')
);

-- Officers in Musanze branch
CREATE TABLE branch_musanze.Officer (
    OfficerID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Branch VARCHAR(50) NOT NULL DEFAULT 'Musanze',
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Role VARCHAR(50) NOT NULL,
    CONSTRAINT chk_musanze_officer_branch CHECK (Branch = 'Musanze')
);

-- Loan Accounts in Musanze branch
CREATE TABLE branch_musanze.LoanAccount (
    LoanID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    OfficerID INT NOT NULL,
    Amount DECIMAL(12, 2) NOT NULL CHECK (Amount > 0),
    InterestRate DECIMAL(5, 2) NOT NULL CHECK (InterestRate >= 0 AND InterestRate <= 100),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_musanze_loan_member FOREIGN KEY (MemberID) 
        REFERENCES branch_musanze.Member(MemberID) ON DELETE CASCADE,
    CONSTRAINT fk_musanze_loan_officer FOREIGN KEY (OfficerID) 
        REFERENCES branch_musanze.Officer(OfficerID) ON DELETE RESTRICT
);

-- Insurance Policies in Musanze branch
CREATE TABLE branch_musanze.InsurancePolicy (
    PolicyID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Type VARCHAR(50) NOT NULL,
    Premium DECIMAL(10, 2) NOT NULL CHECK (Premium > 0),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    EndDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_musanze_policy_member FOREIGN KEY (MemberID) 
        REFERENCES branch_musanze.Member(MemberID) ON DELETE CASCADE
);

-- STEP 4: Insert sample data into Kigali branch
-------------------------------------------------

INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, JoinDate, Branch) VALUES
('Nshuti Alice Uwase', 'F', '+250788123456', 'KG 15 Ave, Kigali City', '2020-03-15', 'Kigali'),
('Uwase Ange Marie Mukamana', 'F', '+250788345678', 'Nyarugenge, Kigali', '2021-05-10', 'Kigali'),
('Niyonzima Patrick Habimana', 'M', '+250788456789', 'Gasabo, Kigali', '2018-12-05', 'Kigali');

INSERT INTO branch_kigali.Officer (FullName, Branch, Contact, Role) VALUES
('Kamanzi Eric Nkurunziza', 'Kigali', '+250788678901', 'Loan Officer'),
('Nsengimana Robert Bizimana', 'Kigali', '+250788890123', 'Claims Officer');

INSERT INTO branch_kigali.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status) VALUES
(1, 1, 5000000.00, 12.50, '2023-02-10', 'Active'),
(2, 2, 3000000.00, 13.00, '2022-11-20', 'Closed'),
(3, 1, 10000000.00, 10.50, '2023-06-01', 'Active');

INSERT INTO branch_kigali.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status) VALUES
(1, 'Life', 150000.00, '2023-01-01', '2024-12-31', 'Active'),
(2, 'Property', 250000.00, '2022-07-15', '2023-07-15', 'Expired'),
(3, 'Accident', 120000.00, '2023-05-01', '2024-05-01', 'Active');

-- STEP 5: Insert sample data into Musanze branch
--------------------------------------------------

INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, JoinDate, Branch) VALUES
('Hirwa Jean Claude Mugabo', 'M', '+250788234567', 'Musanze District, Northern Province', '2019-08-20', 'Musanze'),
('Mutesi Grace Ingabire', 'F', '+250788567890', 'Musanze Town', '2022-01-28', 'Musanze');

INSERT INTO branch_musanze.Officer (FullName, Branch, Contact, Role) VALUES
('Mukamana Diane Uwera', 'Musanze', '+250788789012', 'Insurance Manager'),
('Uwimana Claudine Mukamazimpaka', 'Musanze', '+250788901234', 'Branch Manager');

INSERT INTO branch_musanze.LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status) VALUES
(1, 1, 7500000.00, 11.00, '2023-04-15', 'Active'),
(2, 2, 4500000.00, 12.00, '2023-09-10', 'Active');

INSERT INTO branch_musanze.InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status) VALUES
(1, 'Health', 200000.00, '2023-03-01', '2024-03-01', 'Active'),
(2, 'Loan Protection', 80000.00, '2023-02-10', '2025-02-10', 'Active');

-- STEP 6: Create indexes for performance
------------------------------------------

-- Kigali branch indexes
CREATE INDEX idx_kigali_loan_member ON branch_kigali.LoanAccount(MemberID);
CREATE INDEX idx_kigali_loan_officer ON branch_kigali.LoanAccount(OfficerID);
CREATE INDEX idx_kigali_policy_member ON branch_kigali.InsurancePolicy(MemberID);

-- Musanze branch indexes
CREATE INDEX idx_musanze_loan_member ON branch_musanze.LoanAccount(MemberID);
CREATE INDEX idx_musanze_loan_officer ON branch_musanze.LoanAccount(OfficerID);
CREATE INDEX idx_musanze_policy_member ON branch_musanze.InsurancePolicy(MemberID);

-- STEP 7: Test queries
--------------------------------

-- Verify Kigali branch data
SELECT 'KIGALI BRANCH DATA' AS Branch;
SELECT 'Members' AS Table_Name, COUNT(*) AS Record_Count FROM branch_kigali.Member
UNION ALL
SELECT 'Officers', COUNT(*) FROM branch_kigali.Officer
UNION ALL
SELECT 'LoanAccounts', COUNT(*) FROM branch_kigali.LoanAccount
UNION ALL
SELECT 'InsurancePolicies', COUNT(*) FROM branch_kigali.InsurancePolicy;

-- Verify Musanze branch data
SELECT 'MUSANZE BRANCH DATA' AS Branch;
SELECT 'Members' AS Table_Name, COUNT(*) AS Record_Count FROM branch_musanze.Member
UNION ALL
SELECT 'Officers', COUNT(*) FROM branch_musanze.Officer
UNION ALL
SELECT 'LoanAccounts', COUNT(*) FROM branch_musanze.LoanAccount
UNION ALL
SELECT 'InsurancePolicies', COUNT(*) FROM branch_musanze.InsurancePolicy;

