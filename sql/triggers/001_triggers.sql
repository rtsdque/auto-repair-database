-- =============================================================================
-- Auto Repair Shop Database
-- Phase 3C: Triggers
-- File: sql/triggers/001_triggers.sql
--
-- Triggers in this file:
--   1. trg_services_audit       - Logs all updates to service records
--   2. trg_prevent_service_delete - Blocks deletion of services with linked records
-- =============================================================================


-- =============================================================================
-- AUDIT TABLE
-- Stores a log of every change made to the services table.
-- Created before the trigger that writes to it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS services_audit (
    audit_id            SERIAL          PRIMARY KEY,
    service_id          INTEGER         NOT NULL,
    changed_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    changed_by          TEXT            NOT NULL DEFAULT CURRENT_USER,
    field_changed       TEXT            NOT NULL,
    old_value           TEXT,
    new_value           TEXT
);

CREATE INDEX IF NOT EXISTS idx_audit_service_id ON services_audit (service_id);
CREATE INDEX IF NOT EXISTS idx_audit_changed_at ON services_audit (changed_at);


-- =============================================================================
-- TRIGGER 1: trg_services_audit
-- Fires AFTER any UPDATE on the services table.
-- Logs each changed field as a separate row in services_audit,
-- recording the old value, new value, timestamp, and database user.
--
-- To view the audit log:
--   SELECT * FROM services_audit ORDER BY changed_at DESC;
--
-- To view changes for a specific service:
--   SELECT * FROM services_audit WHERE service_id = 100001;
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_services_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Log each field individually if it changed

    IF OLD.urgency_level IS DISTINCT FROM NEW.urgency_level THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'urgency_level', OLD.urgency_level::TEXT, NEW.urgency_level::TEXT);
    END IF;

    IF OLD.service_type IS DISTINCT FROM NEW.service_type THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'service_type', OLD.service_type::TEXT, NEW.service_type::TEXT);
    END IF;

    IF OLD.service_description IS DISTINCT FROM NEW.service_description THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'service_description', OLD.service_description, NEW.service_description);
    END IF;

    IF OLD.repair_date IS DISTINCT FROM NEW.repair_date THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'repair_date', OLD.repair_date::TEXT, NEW.repair_date::TEXT);
    END IF;

    IF OLD.mileage_at_service IS DISTINCT FROM NEW.mileage_at_service THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'mileage_at_service', OLD.mileage_at_service::TEXT, NEW.mileage_at_service::TEXT);
    END IF;

    IF OLD.service_duration_hours IS DISTINCT FROM NEW.service_duration_hours THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'service_duration_hours', OLD.service_duration_hours::TEXT, NEW.service_duration_hours::TEXT);
    END IF;

    IF OLD.follow_up_needed IS DISTINCT FROM NEW.follow_up_needed THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'follow_up_needed', OLD.follow_up_needed::TEXT, NEW.follow_up_needed::TEXT);
    END IF;

    IF OLD.technician_rating IS DISTINCT FROM NEW.technician_rating THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'technician_rating', OLD.technician_rating::TEXT, NEW.technician_rating::TEXT);
    END IF;

    IF OLD.payment_method IS DISTINCT FROM NEW.payment_method THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'payment_method', OLD.payment_method::TEXT, NEW.payment_method::TEXT);
    END IF;

    IF OLD.service_cost IS DISTINCT FROM NEW.service_cost THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'service_cost', OLD.service_cost::TEXT, NEW.service_cost::TEXT);
    END IF;

    IF OLD.service_price IS DISTINCT FROM NEW.service_price THEN
        INSERT INTO services_audit (service_id, field_changed, old_value, new_value)
        VALUES (OLD.service_id, 'service_price', OLD.service_price::TEXT, NEW.service_price::TEXT);
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_services_audit
    AFTER UPDATE ON services
    FOR EACH ROW
    EXECUTE FUNCTION fn_services_audit();


-- =============================================================================
-- TRIGGER 2: trg_prevent_service_delete
-- Fires BEFORE any DELETE on the services table.
-- Blocks deletion if the service has linked parts or towing records.
-- Raises a clear error message explaining why the delete was blocked.
--
-- To properly delete a service you must first delete its parts and towing:
--   DELETE FROM parts   WHERE service_id = 100001;
--   DELETE FROM towing  WHERE service_id = 100001;
--   DELETE FROM services WHERE service_id = 100001;
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_service_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_parts_count   INTEGER;
    v_towing_count  INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_parts_count  FROM parts  WHERE service_id = OLD.service_id;
    SELECT COUNT(*) INTO v_towing_count FROM towing WHERE service_id = OLD.service_id;

    IF v_parts_count > 0 THEN
        RAISE EXCEPTION
            'Cannot delete service % — it has % linked parts record(s). Delete parts first.',
            OLD.service_id, v_parts_count;
    END IF;

    IF v_towing_count > 0 THEN
        RAISE EXCEPTION
            'Cannot delete service % — it has % linked towing record(s). Delete towing first.',
            OLD.service_id, v_towing_count;
    END IF;

    RETURN OLD;
END;
$$;

CREATE OR REPLACE TRIGGER trg_prevent_service_delete
    BEFORE DELETE ON services
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_service_delete();
