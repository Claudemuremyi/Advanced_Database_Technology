-- Task 2: INSERT SAMPLE DATA
-- ===========================
-- Insert 5 Members
INSERT INTO Member (FullName, Gender, Contact, Address, JoinDate) VALUES
('Nshuti Alice Uwase', 'F', '+250788123456', 'KG 15 Ave, Kigali City', '2020-03-15'),
('Hirwa Jean Claude Mugabo', 'M', '+250788234567', 'Musanze District, Northern Province', '2019-08-20'),
('Uwase Ange Marie Mukamana', 'F', '+250788345678', 'Huye District, Southern Province', '2021-05-10'),
('Niyonzima Patrick Habimana', 'M', '+250788456789', 'Rubavu District, Western Province', '2018-12-05'),
('Mutesi Grace Ingabire', 'F', '+250788567890', 'Nyagatare District, Eastern Province', '2022-01-28');

-- Insert 5 Officers
INSERT INTO Officer (FullName, Branch, Contact, Role) VALUES
('Kamanzi Eric Nkurunziza', 'Kigali', '+250788678901', 'Loan Officer'),
('Mukamana Diane Uwera', 'Musanze', '+250788789012', 'Insurance Manager'),
('Nsengimana Robert Bizimana', 'Huye', '+250788890123', 'Claims Officer'),
('Uwimana Claudine Mukamazimpaka', 'Rubavu', '+250788901234', 'Branch Manager'),
('Habimana Samuel Niyitegeka', 'Nyagatare', '+250788012345', 'Customer Service Officer');

-- Insert 5 Loan Accounts
INSERT INTO LoanAccount (MemberID, OfficerID, Amount, InterestRate, StartDate, Status) VALUES
(1, 1, 5000000.00, 12.50, '2023-02-10', 'Active'),
(2, 1, 7500000.00, 11.00, '2023-04-15', 'Active'),
(3, 3, 3000000.00, 13.00, '2022-11-20', 'Closed'),
(4, 4, 10000000.00, 10.50, '2023-06-01', 'Active'),
(5, 5, 4500000.00, 12.00, '2023-09-10', 'Active');

-- Insert 5 Insurance Policies
INSERT INTO InsurancePolicy (MemberID, Type, Premium, StartDate, EndDate, Status) VALUES
(1, 'Life', 150000.00, '2023-01-01', '2024-12-31', 'Active'),
(1, 'Loan Protection', 80000.00, '2023-02-10', '2025-02-10', 'Active'),
(2, 'Health', 200000.00, '2023-03-01', '2024-03-01', 'Active'),
(3, 'Property', 250000.00, '2022-07-15', '2023-07-15', 'Expired'),
(4, 'Accident', 120000.00, '2023-05-01', '2024-05-01', 'Active');

-- Insert 5 Claims
INSERT INTO Claim (PolicyID, DateFiled, AmountClaimed, Status) VALUES
(1, '2023-09-15', 1000000.00, 'Approved'),
(2, '2023-10-20', 500000.00, 'Settled'),
(3, '2023-08-10', 750000.00, 'Pending'),
(4, '2023-07-05', 1500000.00, 'Rejected'),
(5, '2023-11-01', 800000.00, 'Settled');

-- Insert 5 Payments (each references unique ClaimID for 1:1 relationship)
INSERT INTO Payment (ClaimID, Amount, PaymentDate, Method) VALUES
(1, 1000000.00, '2023-12-01', 'Bank Transfer'),
(2, 500000.00, '2023-11-05', 'Mobile Money'),
(3, 750000.00, '2023-12-10', 'Direct Deposit'),
(4, 1500000.00, '2023-12-15', 'Bank Transfer'),
(5, 800000.00, '2023-11-15', 'Mobile Money');

