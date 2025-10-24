-- ============================================================================
-- TASK 8: THREE-TIER CLIENT-SERVER ARCHITECTURE DESIGN
-- ============================================================================
-- Desctiption: Design and document a three-tier architecture for SACCO system
-- (Presentation Layer, Application Layer, Database Layer)
-- ============================================================================

-- ============================================================================
-- ARCHITECTURE OVERVIEW
-- ============================================================================
/*
THREE-TIER ARCHITECTURE FOR SACCO INSURANCE AND MEMBER EXTENSION SYSTEM

┌─────────────────────────────────────────────────────────────────────┐
│                        TIER 1: PRESENTATION LAYER                    │
│                         (Client Interface)                           │
├─────────────────────────────────────────────────────────────────────┤
│  • Web Browser (React/Angular/Vue.js)                               │
│  • Mobile App (React Native/Flutter)                                │
│  • Desktop Application (Electron)                                   │
│  • Admin Dashboard                                                  │
│                                                                     │
│  Components:                                                        │
│  - Member Portal (view policies, loans, claims)                    │
│  - Officer Dashboard (manage members, approve loans)               │
│  - Admin Panel (system configuration, reports)                     │
│  - Mobile Banking Interface                                        │
└─────────────────────────────────────────────────────────────────────┘
                                    ↕ HTTPS/REST API
┌─────────────────────────────────────────────────────────────────────┐
│                      TIER 2: APPLICATION LAYER                       │
│                      (Business Logic Server)                         │
├─────────────────────────────────────────────────────────────────────┤
│  • API Gateway (Node.js/Express, Python/FastAPI, Java/Spring)      │
│  • Authentication Service (JWT, OAuth 2.0)                          │
│  • Business Logic Services:                                        │
│    - Member Management Service                                     │
│    - Loan Processing Service                                       │
│    - Insurance Policy Service                                      │
│    - Claims Processing Service                                     │
│    - Payment Processing Service                                    │
│    - Reporting Service                                             │
│  • Integration Layer (Database Links, FDW)                         │
│  • Caching Layer (Redis)                                           │
│  • Message Queue (RabbitMQ/Kafka)                                  │
└─────────────────────────────────────────────────────────────────────┘
                                    ↕ Database Connections
┌─────────────────────────────────────────────────────────────────────┐
│                       TIER 3: DATABASE LAYER                         │
│                    (Distributed Data Storage)                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐         ┌──────────────────────┐         │
│  │  Kigali Branch DB    │←───────→│  Musanze Branch DB   │         │
│  │  (PostgreSQL)        │  FDW    │  (PostgreSQL)        │         │
│  │                      │         │                      │         │
│  │  • Members           │         │  • Members           │         │
│  │  • Officers          │         │  • Officers          │         │
│  │  • Loan Accounts     │         │  • Loan Accounts     │         │
│  │  • Insurance Policies│         │  • Insurance Policies│         │
│  │  • Claims            │         │  • Claims            │         │
│  │  • Payments          │         │  • Payments          │         │
│  └──────────────────────┘         └──────────────────────┘         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐         │
│  │         Central Reporting Database                    │         │
│  │         (Aggregated Data, Analytics)                  │         │
│  └──────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────┘

DATA FLOW:
1. User → Presentation Layer (Login, Request)
2. Presentation → Application Layer (API Call)
3. Application Layer → Authenticate & Authorize
4. Application Layer → Database Layer (Query via FDW)
5. Database Layer → Return Data
6. Application Layer → Process & Format Data
7. Application Layer → Presentation Layer (JSON Response)
8. Presentation Layer → Display to User
*/

-- ============================================================================
-- STEP 1: Create API user roles and permissions
-- ============================================================================

-- Create application service accounts
CREATE ROLE api_service_user WITH LOGIN PASSWORD 'secure_api_password_2024';
CREATE ROLE readonly_service WITH LOGIN PASSWORD 'readonly_password_2024';
CREATE ROLE reporting_service WITH LOGIN PASSWORD 'reporting_password_2024';

-- Grant appropriate permissions
-- API service needs read/write access
GRANT CONNECT ON DATABASE postgres TO api_service_user;
GRANT USAGE ON SCHEMA branch_kigali, branch_musanze, public TO api_service_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA branch_kigali TO api_service_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA branch_musanze TO api_service_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_service_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA branch_kigali TO api_service_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA branch_musanze TO api_service_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_service_user;

-- Readonly service for reporting
GRANT CONNECT ON DATABASE postgres TO readonly_service;
GRANT USAGE ON SCHEMA branch_kigali, branch_musanze, public TO readonly_service;
GRANT SELECT ON ALL TABLES IN SCHEMA branch_kigali TO readonly_service;
GRANT SELECT ON ALL TABLES IN SCHEMA branch_musanze TO readonly_service;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_service;

-- ============================================================================
-- STEP 2: Create API views for data abstraction
-- ============================================================================

-- Unified member view across all branches
CREATE OR REPLACE VIEW public.api_all_members AS
SELECT 
    'Kigali' AS source_branch,
    MemberID,
    FullName,
    Gender,
    Contact,
    Address,
    JoinDate,
    Branch
FROM branch_kigali.Member
UNION ALL
SELECT 
    'Musanze' AS source_branch,
    MemberID,
    FullName,
    Gender,
    Contact,
    Address,
    JoinDate,
    Branch
FROM branch_musanze.Member;

-- Unified loan accounts view
CREATE OR REPLACE VIEW public.api_all_loans AS
SELECT 
    'Kigali' AS source_branch,
    l.LoanID,
    l.MemberID,
    m.FullName AS MemberName,
    l.OfficerID,
    o.FullName AS OfficerName,
    l.Amount,
    l.InterestRate,
    l.StartDate,
    l.Status
FROM branch_kigali.LoanAccount l
JOIN branch_kigali.Member m ON l.MemberID = m.MemberID
JOIN branch_kigali.Officer o ON l.OfficerID = o.OfficerID
UNION ALL
SELECT 
    'Musanze' AS source_branch,
    l.LoanID,
    l.MemberID,
    m.FullName AS MemberName,
    l.OfficerID,
    o.FullName AS OfficerName,
    l.Amount,
    l.InterestRate,
    l.StartDate,
    l.Status
FROM branch_musanze.LoanAccount l
JOIN branch_musanze.Member m ON l.MemberID = m.MemberID
JOIN branch_musanze.Officer o ON l.OfficerID = o.OfficerID;

-- Unified insurance policies view
CREATE OR REPLACE VIEW public.api_all_policies AS
SELECT 
    'Kigali' AS source_branch,
    p.PolicyID,
    p.MemberID,
    m.FullName AS MemberName,
    p.Type,
    p.Premium,
    p.StartDate,
    p.EndDate,
    p.Status
FROM branch_kigali.InsurancePolicy p
JOIN branch_kigali.Member m ON p.MemberID = m.MemberID
UNION ALL
SELECT 
    'Musanze' AS source_branch,
    p.PolicyID,
    p.MemberID,
    m.FullName AS MemberName,
    p.Type,
    p.Premium,
    p.StartDate,
    p.EndDate,
    p.Status
FROM branch_musanze.InsurancePolicy p
JOIN branch_musanze.Member m ON p.MemberID = m.MemberID;

-- Grant access to API views
GRANT SELECT ON public.api_all_members TO api_service_user, readonly_service;
GRANT SELECT ON public.api_all_loans TO api_service_user, readonly_service;
GRANT SELECT ON public.api_all_policies TO api_service_user, readonly_service;

-- ============================================================================
-- STEP 3: Create stored procedures for business logic
-- ============================================================================

-- Procedure: Create new member (routes to correct branch)
CREATE OR REPLACE FUNCTION public.api_create_member(
    p_full_name VARCHAR(100),
    p_gender CHAR(1),
    p_contact VARCHAR(15),
    p_address TEXT,
    p_branch VARCHAR(50)
) RETURNS TABLE(member_id INT, success BOOLEAN, message TEXT) AS $$
BEGIN
    IF p_branch = 'Kigali' THEN
        INSERT INTO branch_kigali.Member (FullName, Gender, Contact, Address, Branch)
        VALUES (p_full_name, p_gender, p_contact, p_address, p_branch)
        RETURNING MemberID INTO member_id;
        
        success := TRUE;
        message := 'Member created successfully in Kigali branch';
        RETURN NEXT;
        
    ELSIF p_branch = 'Musanze' THEN
        INSERT INTO branch_musanze.Member (FullName, Gender, Contact, Address, Branch)
        VALUES (p_full_name, p_gender, p_contact, p_address, p_branch)
        RETURNING MemberID INTO member_id;
        
        success := TRUE;
        message := 'Member created successfully in Musanze branch';
        RETURN NEXT;
        
    ELSE
        member_id := NULL;
        success := FALSE;
        message := 'Invalid branch specified';
        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Apply for loan
CREATE OR REPLACE FUNCTION public.api_apply_loan(
    p_member_id INT,
    p_branch VARCHAR(50),
    p_amount DECIMAL(12, 2),
    p_interest_rate DECIMAL(5, 2),
    p_officer_id INT
) RETURNS TABLE(loan_id INT, success BOOLEAN, message TEXT) AS $$
BEGIN
    IF p_branch = 'Kigali' THEN
        INSERT INTO branch_kigali.LoanAccount (MemberID, OfficerID, Amount, InterestRate, Status)
        VALUES (p_member_id, p_officer_id, p_amount, p_interest_rate, 'Pending')
        RETURNING LoanID INTO loan_id;
        
        success := TRUE;
        message := 'Loan application submitted successfully';
        RETURN NEXT;
        
    ELSIF p_branch = 'Musanze' THEN
        INSERT INTO branch_musanze.LoanAccount (MemberID, OfficerID, Amount, InterestRate, Status)
        VALUES (p_member_id, p_officer_id, p_amount, p_interest_rate, 'Pending')
        RETURNING LoanID INTO loan_id;
        
        success := TRUE;
        message := 'Loan application submitted successfully';
        RETURN NEXT;
        
    ELSE
        loan_id := NULL;
        success := FALSE;
        message := 'Invalid branch specified';
        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Get member dashboard data
CREATE OR REPLACE FUNCTION public.api_get_member_dashboard(p_member_id INT, p_branch VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    IF p_branch = 'Kigali' THEN
        SELECT json_build_object(
            'member', (SELECT row_to_json(m) FROM branch_kigali.Member m WHERE MemberID = p_member_id),
            'loans', (SELECT json_agg(l) FROM branch_kigali.LoanAccount l WHERE MemberID = p_member_id),
            'policies', (SELECT json_agg(p) FROM branch_kigali.InsurancePolicy p WHERE MemberID = p_member_id)
        ) INTO v_result;
    ELSIF p_branch = 'Musanze' THEN
        SELECT json_build_object(
            'member', (SELECT row_to_json(m) FROM branch_musanze.Member m WHERE MemberID = p_member_id),
            'loans', (SELECT json_agg(l) FROM branch_musanze.LoanAccount l WHERE MemberID = p_member_id),
            'policies', (SELECT json_agg(p) FROM branch_musanze.InsurancePolicy p WHERE MemberID = p_member_id)
        ) INTO v_result;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.api_create_member TO api_service_user;
GRANT EXECUTE ON FUNCTION public.api_apply_loan TO api_service_user;
GRANT EXECUTE ON FUNCTION public.api_get_member_dashboard TO api_service_user;

-- ============================================================================
-- STEP 4: Create audit logging for API calls
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.api_audit_log (
    LogID SERIAL PRIMARY KEY,
    APIEndpoint VARCHAR(200) NOT NULL,
    HTTPMethod VARCHAR(10) NOT NULL,
    UserID VARCHAR(100),
    RequestPayload TEXT,
    ResponseStatus INT,
    ExecutionTime_MS INT,
    IPAddress VARCHAR(50),
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Function to log API calls
CREATE OR REPLACE FUNCTION public.log_api_call(
    p_endpoint VARCHAR(200),
    p_method VARCHAR(10),
    p_user_id VARCHAR(100),
    p_payload TEXT,
    p_status INT,
    p_exec_time INT,
    p_ip VARCHAR(50)
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.api_audit_log (APIEndpoint, HTTPMethod, UserID, RequestPayload, ResponseStatus, ExecutionTime_MS, IPAddress)
    VALUES (p_endpoint, p_method, p_user_id, p_payload, p_status, p_exec_time, p_ip);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 5: Test API functions
-- ============================================================================

-- Test: Create member via API
SELECT * FROM public.api_create_member(
    'Test User API', 'M', '+250788999888', 'Kigali Test Address', 'Kigali'
);

-- Test: Get member dashboard
SELECT public.api_get_member_dashboard(1, 'Kigali');

-- Test: View all members via API
SELECT * FROM public.api_all_members LIMIT 5;

-- Test: View all loans via API
SELECT * FROM public.api_all_loans LIMIT 5;

-- ============================================================================
-- ARCHITECTURE DOCUMENTATION
-- ============================================================================
/*
TIER 1: PRESENTATION LAYER
--------------------------
Technologies: React.js, HTML5, CSS3, JavaScript
Responsibilities:
- User interface rendering
- Form validation
- Session management
- API consumption
- Real-time updates (WebSocket)

Key Components:
1. Member Portal
   - Login/Registration
   - View account details
   - Apply for loans
   - View insurance policies
   - Submit claims

2. Officer Dashboard
   - Member management
   - Loan approval workflow
   - Claims processing
   - Report generation

3. Admin Panel
   - System configuration
   - User management
   - Branch management
   - Analytics dashboard

TIER 2: APPLICATION LAYER
--------------------------
Technologies: Node.js/Express, Python/FastAPI
Responsibilities:
- Business logic execution
- Authentication & authorization
- Data validation
- Transaction management
- Integration with database layer
- Caching strategy
- API rate limiting

Key Services:
1. Authentication Service
   - JWT token generation
   - OAuth 2.0 integration
   - Role-based access control

2. Member Service
   - CRUD operations for members
   - Member search and filtering
   - Member verification

3. Loan Service
   - Loan application processing
   - Loan approval workflow
   - Interest calculation
   - Payment scheduling

4. Insurance Service
   - Policy management
   - Premium calculation
   - Claims processing

5. Reporting Service
   - Aggregated reports
   - Data analytics
   - Export functionality

TIER 3: DATABASE LAYER
-----------------------
Technologies: PostgreSQL with postgres_fdw
Responsibilities:
- Data persistence
- Data integrity
- Transaction management
- Distributed query execution
- Backup and recovery

Architecture:
1. Distributed Databases
   - Kigali Branch DB (branch_kigali schema)
   - Musanze Branch DB (branch_musanze schema)
   - Central Reporting DB (public schema)

2. Database Links (FDW)
   - Cross-branch queries
   - Distributed transactions
   - Data synchronization

3. Replication
   - Master-slave replication
   - Automatic failover
   - Load balancing

COMMUNICATION PROTOCOLS
-----------------------
1. Presentation ↔ Application: HTTPS/REST API
   - JSON data format
   - JWT authentication
   - Rate limiting

2. Application ↔ Database: PostgreSQL Protocol
   - Connection pooling
   - Prepared statements
   - Transaction management

SECURITY MEASURES
-----------------
1. Authentication: JWT tokens, OAuth 2.0
2. Authorization: Role-based access control (RBAC)
3. Encryption: TLS/SSL for data in transit
4. Database: Row-level security, encrypted connections
5. API: Rate limiting, input validation, SQL injection prevention

SCALABILITY FEATURES
--------------------
1. Horizontal scaling: Load balancers, multiple app servers
2. Vertical scaling: Database optimization, indexing
3. Caching: Redis for session and query caching
4. CDN: Static asset delivery
5. Database: Read replicas, partitioning

MONITORING & LOGGING
--------------------
1. Application logs: Winston, Morgan
2. Database logs: PostgreSQL logs, slow query log
3. Performance monitoring: New Relic, DataDog
4. Error tracking: Sentry
5. Audit trails: API audit log table
*/

-- ============================================================================
-- END OF THREE-TIER ARCHITECTURE DESIGN
-- ============================================================================
