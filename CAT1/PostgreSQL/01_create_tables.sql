-- STUDENT 31 – SACCO INSURANCE AND MEMBER EXTENSION SYSTEM
-- Database: sacco
-- ==================================================================
-- Connect to the sacco database before running the following scripts

DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Claim CASCADE;
DROP TABLE IF EXISTS InsurancePolicy CASCADE;
DROP TABLE IF EXISTS LoanAccount CASCADE;
DROP TABLE IF EXISTS Officer CASCADE;
DROP TABLE IF EXISTS Member CASCADE;

-- TABLE 1: Member
-- Stores member profile information for Rwandan SACCO members
-- ===========================================================
CREATE TABLE Member (
    MemberID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')),
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Address TEXT,
    JoinDate DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT chk_contact_format CHECK (Contact ~ '^[0-9+\-() ]+$')
);

-- TABLE 2: Officer
-- Stores SACCO officer information across Rwandan branches
-- ========================================================
CREATE TABLE Officer (
    OfficerID SERIAL PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Branch VARCHAR(50) NOT NULL,
    Contact VARCHAR(15) NOT NULL UNIQUE,
    Role VARCHAR(50) NOT NULL,
    CONSTRAINT chk_officer_contact CHECK (Contact ~ '^[0-9+\-() ]+$')
);

-- TABLE 3: LoanAccount
-- Tracks loan accounts linked to members and officers
-- ===================================================
CREATE TABLE LoanAccount (
    LoanID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    OfficerID INT NOT NULL,
    Amount DECIMAL(12, 2) NOT NULL CHECK (Amount > 0),
    InterestRate DECIMAL(5, 2) NOT NULL CHECK (InterestRate >= 0 AND InterestRate <= 100),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (Status IN ('Active', 'Closed', 'Defaulted', 'Pending')),
    CONSTRAINT fk_loan_member FOREIGN KEY (MemberID) 
        REFERENCES Member(MemberID) ON DELETE CASCADE,
    CONSTRAINT fk_loan_officer FOREIGN KEY (OfficerID) 
        REFERENCES Officer(OfficerID) ON DELETE RESTRICT
);

-- TABLE 4: InsurancePolicy
-- Stores insurance policy details for Rwandan SACCO members
-- =========================================================
CREATE TABLE InsurancePolicy (
    PolicyID SERIAL PRIMARY KEY,
    MemberID INT NOT NULL,
    Type VARCHAR(50) NOT NULL 
        CHECK (Type IN ('Life', 'Health', 'Property', 'Loan Protection', 'Accident')),
    Premium DECIMAL(10, 2) NOT NULL CHECK (Premium > 0),
    StartDate DATE NOT NULL DEFAULT CURRENT_DATE,
    EndDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (Status IN ('Active', 'Expired', 'Cancelled', 'Suspended')),
    CONSTRAINT fk_policy_member FOREIGN KEY (MemberID) 
        REFERENCES Member(MemberID) ON DELETE CASCADE,
    CONSTRAINT chk_policy_dates CHECK (EndDate > StartDate)
);

-- TABLE 5: Claim
-- Tracks insurance claims filed by Rwandan SACCO members
-- ======================================================
CREATE TABLE Claim (
    ClaimID SERIAL PRIMARY KEY,
    PolicyID INT NOT NULL,
    DateFiled DATE NOT NULL DEFAULT CURRENT_DATE,
    AmountClaimed DECIMAL(12, 2) NOT NULL CHECK (AmountClaimed > 0),
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (Status IN ('Pending', 'Approved', 'Rejected', 'Settled')),
    CONSTRAINT fk_claim_policy FOREIGN KEY (PolicyID) 
        REFERENCES InsurancePolicy(PolicyID) ON DELETE CASCADE
);

-- TABLE 6: Payment
-- Records payments made for settled claims
-- Records payments for settled claims in RWF
-- ON DELETE CASCADE: When a claim is deleted, its payment is also deleted
-- ========================================================================
CREATE TABLE Payment (
    PaymentID SERIAL PRIMARY KEY,
    ClaimID INT NOT NULL UNIQUE,
    Amount DECIMAL(12, 2) NOT NULL CHECK (Amount > 0),
    PaymentDate DATE NOT NULL DEFAULT CURRENT_DATE,
    Method VARCHAR(30) NOT NULL 
        CHECK (Method IN ('Bank Transfer', 'Cheque', 'Cash', 'Mobile Money', 'Direct Deposit')),
    CONSTRAINT fk_payment_claim FOREIGN KEY (ClaimID) 
        REFERENCES Claim(ClaimID) ON DELETE CASCADE
);
