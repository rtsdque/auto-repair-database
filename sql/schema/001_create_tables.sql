-- =============================================================================
-- Auto Repair Shop Database
-- Phase 2: Schema Migration & Redesign
-- File: sql/schema/001_create_tables.sql
--
-- Improvements over MS Access original:
--   - Proper primary keys (SERIAL) on all tables
--   - Explicit foreign key constraints enforced at DB level
--   - Enums replace free-text fields with known fixed values
--   - make and model split into separate columns
--   - follow_up_needed stored as BOOLEAN instead of "Yes"/"No"
--   - technician_rating constrained to 1-5
--   - Indexes on all foreign keys and common query columns
--   - Monetary values use NUMERIC(10,2) instead of Access Currency
-- =============================================================================


-- =============================================================================
-- ENUMS
-- Define controlled vocabularies for fields that had free-text in Access
-- =============================================================================

CREATE TYPE urgency_level     AS ENUM ('Scheduled', 'Standard', 'Emergency');
CREATE TYPE service_type      AS ENUM ('Oil Change', 'Battery Replacement', 'Tire Replacement', 'Brake Service', 'Engine Repair', 'Transmission Repair', 'Towing');
CREATE TYPE payment_method    AS ENUM ('Cash', 'Credit Card', 'Debit Card', 'Insurance', 'Company Invoice');
CREATE TYPE vehicle_type      AS ENUM ('Car', 'Truck', 'Van', 'SUV', 'Bus', 'Motorcycle');
CREATE TYPE towing_location   AS ENUM ('Residential', 'Commercial', 'Garage', 'Dealer', 'Highway', 'Parking Lot');


-- =============================================================================
-- CUSTOMERS
-- Original: Customer_ID (Integer), Customer_Name (Text), Phone_Number (Text)
-- Changes:  SERIAL PK, phone limited to 20 chars
-- =============================================================================

CREATE TABLE customers (
    customer_id     SERIAL          PRIMARY KEY,
    customer_name   VARCHAR(255),
    phone_number    VARCHAR(20)     NOT NULL
);


-- =============================================================================
-- MECHANICS
-- Original: Mechanic_ID (Text "MEC001"), Mechanic_Name (Text)
-- Changes:  SERIAL PK, original mechanic_code preserved as unique identifier
-- =============================================================================

CREATE TABLE mechanics (
    mechanic_id     SERIAL          PRIMARY KEY,
    mechanic_code   VARCHAR(10)     NOT NULL UNIQUE,  -- e.g. "MEC001"
    mechanic_name   VARCHAR(255)    NOT NULL
);


-- =============================================================================
-- VEHICLES
-- Original: Vehicle_ID (Long Int), Vehicle_Type (Text), Make_and_Model (Text), Customer_ID (Int)
-- Changes:  make and model split into separate columns, vehicle_type uses enum, FK to customers
-- =============================================================================

CREATE TABLE vehicles (
    vehicle_id      SERIAL          PRIMARY KEY,
    vehicle_type    vehicle_type    NOT NULL,
    make            VARCHAR(100)    NOT NULL,
    model           VARCHAR(100)    NOT NULL,
    customer_id     INTEGER         NOT NULL,

    CONSTRAINT fk_vehicles_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT
);


-- =============================================================================
-- SERVICES
-- Original: many Text fields, "Yes"/"No" for follow_up, no FK constraints
-- Changes:  enums for urgency/service_type/payment, BOOLEAN for follow_up,
--           CHECK on technician_rating (1-5), FK to vehicles and mechanics
-- =============================================================================

CREATE TABLE services (
    service_id              SERIAL              PRIMARY KEY,
    vehicle_id              INTEGER             NOT NULL,
    mechanic_id             INTEGER             NOT NULL,
    urgency_level           urgency_level       NOT NULL,
    service_type            service_type        NOT NULL,
    service_description     TEXT                NOT NULL,
    repair_date             DATE                NOT NULL,
    mileage_at_service      INTEGER,
    service_duration_hours  SMALLINT,
    follow_up_needed        BOOLEAN             NOT NULL DEFAULT FALSE,
    technician_rating       SMALLINT            CHECK (technician_rating BETWEEN 1 AND 5),
    payment_method          payment_method,
    service_cost            NUMERIC(10,2)       NOT NULL,  -- cost to the shop
    service_price           NUMERIC(10,2)       NOT NULL,  -- price charged to customer

    CONSTRAINT fk_services_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_services_mechanic
        FOREIGN KEY (mechanic_id) REFERENCES mechanics (mechanic_id)
        ON DELETE RESTRICT
);


-- =============================================================================
-- PARTS
-- Original: Part_ID (Text "B1"), Parts_Used (Text), Price (Currency), Service_ID (Long Int)
-- Changes:  SERIAL PK, original part_code preserved, FK to services
-- =============================================================================

CREATE TABLE parts (
    part_id         SERIAL          PRIMARY KEY,
    part_code       VARCHAR(20)     NOT NULL UNIQUE,  -- e.g. "B1", "B1000"
    part_name       VARCHAR(255)    NOT NULL,
    price           NUMERIC(10,2)   NOT NULL,
    service_id      INTEGER         NOT NULL,

    CONSTRAINT fk_parts_service
        FOREIGN KEY (service_id) REFERENCES services (service_id)
        ON DELETE RESTRICT
);


-- =============================================================================
-- TOWING
-- Original: Towing_ID (Text "TOW0001"), free-text locations, FK to services
-- Changes:  SERIAL PK, towing_code preserved, locations use enum, FK enforced
-- =============================================================================

CREATE TABLE towing (
    towing_id           SERIAL          PRIMARY KEY,
    towing_code         VARCHAR(20)     NOT NULL UNIQUE,  -- e.g. "TOW0001"
    towing_date         DATE            NOT NULL,
    pickup_location     towing_location NOT NULL,
    dropoff_location    towing_location NOT NULL,
    tow_distance_miles  INTEGER,
    service_id          INTEGER         NOT NULL,

    CONSTRAINT fk_towing_service
        FOREIGN KEY (service_id) REFERENCES services (service_id)
        ON DELETE RESTRICT
);


-- =============================================================================
-- INDEXES
-- Foreign keys and commonly queried columns
-- =============================================================================

-- vehicles
CREATE INDEX idx_vehicles_customer_id  ON vehicles (customer_id);

-- services
CREATE INDEX idx_services_vehicle_id   ON services (vehicle_id);
CREATE INDEX idx_services_mechanic_id  ON services (mechanic_id);
CREATE INDEX idx_services_repair_date  ON services (repair_date);
CREATE INDEX idx_services_service_type ON services (service_type);

-- parts
CREATE INDEX idx_parts_service_id      ON parts (service_id);

-- towing
CREATE INDEX idx_towing_service_id     ON towing (service_id);
CREATE INDEX idx_towing_date           ON towing (towing_date);