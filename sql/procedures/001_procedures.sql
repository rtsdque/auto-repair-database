-- =============================================================================
-- Auto Repair Shop Database
-- Phase 3B: Stored Procedures
-- File: sql/procedures/001_procedures.sql
--
-- Procedures in this file:
--   1. add_service        - Logs a new service record for a vehicle
--   2. add_towing         - Logs a new towing job linked to a service
--   3. get_vehicle_history - Returns full service history for a vehicle
-- =============================================================================


-- =============================================================================
-- PROCEDURE 1: add_service
-- Inserts a new service record into the services table.
-- Validates that the vehicle and mechanic exist before inserting.
-- Returns the new service_id so it can be used immediately (e.g. for add_towing).
--
-- Example call:
--   CALL add_service(200001, 'MEC001', 'Standard', 'Oil Change',
--                   'Diagnosed and repaired Oil Filter', '2024-06-01',
--                   45000, 2, false, 4, 'Cash', 35.00, 65.00);
-- =============================================================================

CREATE OR REPLACE PROCEDURE add_service(
    p_vehicle_id            INTEGER,
    p_mechanic_code         VARCHAR(10),
    p_urgency_level         urgency_level,
    p_service_type          service_type,
    p_service_description   TEXT,
    p_repair_date           DATE,
    p_mileage               INTEGER,
    p_duration_hours        SMALLINT,
    p_follow_up_needed      BOOLEAN,
    p_technician_rating     SMALLINT,
    p_payment_method        payment_method,
    p_service_cost          NUMERIC(10,2),
    p_service_price         NUMERIC(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mechanic_id   INTEGER;
    v_new_id        INTEGER;
BEGIN
    -- Validate vehicle exists
    IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle ID % does not exist.', p_vehicle_id;
    END IF;

    -- Validate mechanic exists and get their integer ID
    SELECT mechanic_id INTO v_mechanic_id
    FROM mechanics
    WHERE mechanic_code = p_mechanic_code;

    IF v_mechanic_id IS NULL THEN
        RAISE EXCEPTION 'Mechanic code % does not exist.', p_mechanic_code;
    END IF;

    -- Validate rating range
    IF p_technician_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Technician rating must be between 1 and 5. Got: %', p_technician_rating;
    END IF;

    -- Insert the service record
    INSERT INTO services (
        vehicle_id, mechanic_id, urgency_level, service_type,
        service_description, repair_date, mileage_at_service,
        service_duration_hours, follow_up_needed, technician_rating,
        payment_method, service_cost, service_price
    )
    VALUES (
        p_vehicle_id, v_mechanic_id, p_urgency_level, p_service_type,
        p_service_description, p_repair_date, p_mileage,
        p_duration_hours, p_follow_up_needed, p_technician_rating,
        p_payment_method, p_service_cost, p_service_price
    )
    RETURNING service_id INTO v_new_id;

    RAISE NOTICE 'Service record created successfully. New Service ID: %', v_new_id;
END;
$$;


-- =============================================================================
-- PROCEDURE 2: add_towing
-- Logs a new towing job linked to an existing service record.
-- Validates that the service exists before inserting.
-- Generates the next towing_code automatically (e.g. TOW2195).
--
-- Example call:
--   CALL add_towing(114999, '2024-06-01', 'Residential', 'Garage', 18);
-- =============================================================================

CREATE OR REPLACE PROCEDURE add_towing(
    p_service_id        INTEGER,
    p_towing_date       DATE,
    p_pickup_location   towing_location,
    p_dropoff_location  towing_location,
    p_distance_miles    INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_code      VARCHAR(20);
    v_next_num      INTEGER;
BEGIN
    -- Validate service exists
    IF NOT EXISTS (SELECT 1 FROM services WHERE service_id = p_service_id) THEN
        RAISE EXCEPTION 'Service ID % does not exist.', p_service_id;
    END IF;

    -- Validate service is not already linked to a towing record
    IF EXISTS (SELECT 1 FROM towing WHERE service_id = p_service_id) THEN
        RAISE EXCEPTION 'Service ID % already has a towing record.', p_service_id;
    END IF;

    -- Auto-generate next towing_code based on current max
    SELECT COUNT(*) + 1 INTO v_next_num FROM towing;
    v_new_code := 'TOW' || LPAD(v_next_num::TEXT, 4, '0');

    -- Insert towing record
    INSERT INTO towing (
        towing_code, towing_date, pickup_location,
        dropoff_location, tow_distance_miles, service_id
    )
    VALUES (
        v_new_code, p_towing_date, p_pickup_location,
        p_dropoff_location, p_distance_miles, p_service_id
    );

    RAISE NOTICE 'Towing record created. Towing Code: %', v_new_code;
END;
$$;


-- =============================================================================
-- PROCEDURE 3: get_vehicle_history
-- Returns the full service history for a given vehicle ID.
-- Prints a summary of each service: date, type, mechanic, cost, price, rating.
-- Useful for a service advisor looking up a vehicle at the front desk.
--
-- Example call:
--   CALL get_vehicle_history(200001);
-- =============================================================================

CREATE OR REPLACE PROCEDURE get_vehicle_history(
    p_vehicle_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record        RECORD;
    v_vehicle_info  TEXT;
    v_owner         TEXT;
    v_count         INTEGER := 0;
    v_total_spent   NUMERIC(10,2) := 0;
BEGIN
    -- Validate vehicle exists
    IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle ID % does not exist.', p_vehicle_id;
    END IF;

    -- Get vehicle and owner info
    SELECT
        v.make || ' ' || v.model,
        c.customer_name
    INTO v_vehicle_info, v_owner
    FROM vehicles v
    INNER JOIN customers c ON v.customer_id = c.customer_id
    WHERE v.vehicle_id = p_vehicle_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Vehicle ID:  %', p_vehicle_id;
    RAISE NOTICE 'Vehicle:     %', v_vehicle_info;
    RAISE NOTICE 'Owner:       %', v_owner;
    RAISE NOTICE '========================================';

    -- Loop through all service records for this vehicle
    FOR v_record IN
        SELECT
            s.service_id,
            s.repair_date,
            s.service_type,
            s.urgency_level,
            m.mechanic_name,
            s.technician_rating,
            s.service_cost,
            s.service_price,
            s.follow_up_needed
        FROM services s
        INNER JOIN mechanics m ON s.mechanic_id = m.mechanic_id
        WHERE s.vehicle_id = p_vehicle_id
        ORDER BY s.repair_date DESC
    LOOP
        v_count := v_count + 1;
        v_total_spent := v_total_spent + v_record.service_price;

        RAISE NOTICE 'Service #%: [%] % | % | Mechanic: % | Rating: %/5 | Cost: $% | Price: $% | Follow-up: %',
            v_record.service_id,
            v_record.repair_date,
            v_record.service_type,
            v_record.urgency_level,
            v_record.mechanic_name,
            v_record.technician_rating,
            v_record.service_cost,
            v_record.service_price,
            v_record.follow_up_needed;
    END LOOP;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total Services: %  |  Total Spent: $%', v_count, v_total_spent;
    RAISE NOTICE '========================================';
END;
$$;