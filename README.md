# SACCO Insurance and Member Extension System

## Overview
This is a complete PostgreSQL database system for a SACCO (Savings and Credit Cooperative) operating in Rwanda. The system manages member profiles, loan accounts, insurance policies, claims, and payments across multiple branches in Rwanda.

### Database Structure
- 6 tables with proper relationships
- Primary and foreign key constraints
- ON DELETE CASCADE between Claim → Payment
- Check constraints for data validation
- Indexes for performance

## Files Structure

\`\`\`
scripts/
├── 00_master_setup.sql            # ⭐ RECOMMENDED: Complete setup in one script
├── 01_create_tables.sql           # Table creation with constraints
├── 02_insert_data.sql             # Sample data with Rwandan context
├── 03_query_active_policies.sql   # Task 3: Active policies query
├── 04_update_claim_status.sql     # Task 4: Update claim status
├── 05_multiple_policies.sql       # Task 5: Members with multiple policies
├── 06_create_views.sql            # Task 6: Monthly premium views
├── 07_create_trigger.sql          # Task 7: Auto-expire policy trigger
├── 08_bonus_queries.sql           # Additional analysis queries
└── 09_verification.sql            # Verification and testing
\`\`\`


1. **Create Database**
   \`\`\`sql
   CREATE DATABASE sacco;
   \`\`\`

2. **Connect to Database**
   - Open pgAdmin 4
   - Select the `sacco` database

3. **Run Scripts in Order** 
   - `01_create_tables.sql` - Creates all tables
   - `02_insert_data.sql` - Inserts sample Rwandan data
   - `03_query_active_policies.sql` - Query active policies
   - `04_update_claim_status.sql` - Update claim statuses
   - `05_multiple_policies.sql` - Find members with multiple policies
   - `06_create_views.sql` - Create premium collection views
   - `07_create_trigger.sql` - Create auto-expire trigger

## Tasks Completed

### Task 1: Table Creation ✓
- 6 tables with proper constraints
- Foreign keys with CASCADE/RESTRICT rules
- Check constraints for validation

### Task 2: Sample Data ✓
- 5 Members with Rwandan names and addresses
- 5 Officers across Rwandan branches
- 5 Loan Accounts in RWF
- 5 Insurance Policies
- 5 Claims
- 5 Payments

### Task 3: Active Policies Query ✓
Retrieves all active insurance policies with member details and RWF formatting

### Task 4: Update Claim Status ✓
Updates claim status to 'Settled' after payment processing

### Task 5: Multiple Policies ✓
Identifies members with more than one insurance policy

### Task 6: Premium Collection Views ✓
Three views created:
- `vw_MonthlyPremiumCollection` - Monthly aggregation
- `vw_MonthlyPremiumSummary` - Formatted summary with RWF
- `vw_YearlyPremiumComparison` - Year-over-year comparison

### Task 7: Auto-Expire Trigger ✓
Automatically updates policy status to 'Expired' when EndDate is reached
