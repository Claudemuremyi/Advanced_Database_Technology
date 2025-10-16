# SACCO Insurance and Member Extension System

## Description
This is a complete PostgreSQL database system for a SACCO (Savings and Credit Cooperative) operating in Rwanda. The system manages member profiles, loan accounts, insurance policies, claims, and payments across multiple branches in Rwanda.

### Database Structure
- 6 tables with proper relationships
- Primary and foreign key constraints
- ON DELETE CASCADE between Claim → Payment
- Check constraints for data validation
- Indexes for performance

## Tasks Completed

### Task 1: Table Creation 
- 6 tables with proper constraints
- Foreign keys with CASCADE/RESTRICT rules
- Check constraints for validation

### Task 2: Sample Data 
- 5 Members with Rwandan names and addresses
- 5 Officers across Rwandan branches
- 5 Loan Accounts in RWF
- 5 Insurance Policies
- 5 Claims
- 5 Payments

### Task 3: Active Policies Query 
Retrieves all active insurance policies with member details and RWF formatting

### Task 4: Update Claim Status 
Updates claim status to 'Settled' after payment processing

### Task 5: Multiple Policies 
Identifies members with more than one insurance policy

### Task 6: Premium Collection Views 
Three views created:
- `vw_MonthlyPremiumCollection` - Monthly aggregation
- `vw_MonthlyPremiumSummary` - Formatted summary with RWF
- `vw_YearlyPremiumComparison` - Year-over-year comparison

### Task 7: Auto-Expire Trigger 
Automatically updates policy status to 'Expired' when EndDate is reached
