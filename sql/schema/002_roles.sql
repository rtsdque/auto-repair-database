-- =============================================================================
-- Auto Repair Shop Database
-- Phase 3D: Role-Based Access Control
-- File: sql/schema/002_roles.sql
--
-- Creates three roles with appropriate permissions:
--   1. shop_admin    - Full access to all tables and views
--   2. shop_mechanic - Can view all data, update service records
--   3. shop_analyst  - Read-only access to all tables and views
--
-- NOTE: This file creates roles and grants permissions only.
-- To create actual login users assigned to these roles, see examples at bottom.
-- =============================================================================


-- =============================================================================
-- DROP ROLES IF THEY EXIST (safe to re-run)
-- =============================================================================

DROP ROLE IF EXISTS shop_admin;
DROP ROLE IF EXISTS shop_mechanic;
DROP ROLE IF EXISTS shop_analyst;


-- =============================================================================
-- ROLE 1: shop_admin
-- Full access to everything in the database.
-- Represents a database administrator or shop owner.
-- =============================================================================

CREATE ROLE shop_admin;

-- Full access to all tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO shop_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO shop_admin;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA public TO shop_admin;

-- Ensure future tables are also covered
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO shop_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO shop_admin;


-- =============================================================================
-- ROLE 2: shop_mechanic
-- Can view all data and update service records.
-- Cannot delete records or modify financial columns (service_cost, service_price).
-- Represents a technician or service advisor.
-- =============================================================================

CREATE ROLE shop_mechanic;

-- Read access to all tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA public TO shop_mechanic;

-- Can insert new service records
GRANT INSERT ON services TO shop_mechanic;
GRANT USAGE, SELECT ON SEQUENCE services_service_id_seq TO shop_mechanic;

-- Can update service records — but NOT financial columns
GRANT UPDATE (
    urgency_level,
    service_description,
    service_duration_hours,
    follow_up_needed,
    technician_rating,
    mileage_at_service
) ON services TO shop_mechanic;

-- Can insert parts linked to their services
GRANT INSERT ON parts TO shop_mechanic;
GRANT USAGE, SELECT ON SEQUENCE parts_part_id_seq TO shop_mechanic;

-- Ensure future tables get SELECT by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO shop_mechanic;


-- =============================================================================
-- ROLE 3: shop_analyst
-- Read-only access to all tables and views.
-- Cannot insert, update, or delete anything.
-- Represents a reporting analyst or data team member.
-- =============================================================================

CREATE ROLE shop_analyst;

-- Read-only access to all tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA public TO shop_analyst;

-- Ensure future tables get SELECT by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO shop_analyst;


-- =============================================================================
-- EXAMPLE: Creating actual login users and assigning roles
-- Uncomment and modify these to create real users in your environment.
--
-- CREATE USER admin_user    WITH PASSWORD 'your_password' IN ROLE shop_admin;
-- CREATE USER mechanic_user WITH PASSWORD 'your_password' IN ROLE shop_mechanic;
-- CREATE USER analyst_user  WITH PASSWORD 'your_password' IN ROLE shop_analyst;
-- =============================================================================
