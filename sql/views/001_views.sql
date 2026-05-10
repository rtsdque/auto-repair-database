-- =============================================================================
-- Auto Repair Shop Database
-- Phase 3A: Analytical Views
-- File: sql/views/001_views.sql
--
-- Views recreated and improved from original MS Access queries.
-- All views are read-only and can be queried like tables in pgAdmin.
--
-- Views in this file:
--   1. vw_service_totals_by_brand    (Query 1  - Service Totals by Brand)
--   2. vw_parts_cost_summary         (Query 2  - Average & Total Cost of Parts)
--   3. vw_profit_by_service_type     (Query 3  - Average & Total Profit by Service)
--   4. vw_mechanic_ratings           (Query 4  - Average Mechanic Ratings)
--   5. vw_customer_spending          (Query 5  - Customer Visit & Spending Totals)
--   6. vw_monthly_financials         (Query 8  - Monthly Profit, Revenue & Expenses)
--   7. vw_towing_summary             (Query 9  - Towing Mileage Information)
--   8. vw_repeat_service_vehicles    (Query 10 - Vehicles Serviced More Than Once)
-- =============================================================================


-- =============================================================================
-- VIEW 1: vw_service_totals_by_brand
-- Original Query 1 - Service Totals by Brand
--
-- Access used TRANSFORM/PIVOT (Access-only syntax).
-- PostgreSQL uses COUNT with FILTER for a cleaner, more readable cross-tab.
-- Shows how many times each service type was performed per vehicle brand.
-- =============================================================================

CREATE OR REPLACE VIEW vw_service_totals_by_brand AS
SELECT
    v.make                                                                          AS brand,
    COUNT(DISTINCT v.vehicle_id)                                                    AS number_of_vehicles,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Battery Replacement')      AS battery_replacement,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Brake Service')            AS brake_service,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Engine Repair')            AS engine_repair,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Oil Change')               AS oil_change,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Tire Replacement')         AS tire_replacement,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Towing')                   AS towing,
    COUNT(s.service_id) FILTER (WHERE s.service_type = 'Transmission Repair')      AS transmission_repair,
    COUNT(s.service_id)                                                             AS total_services
FROM vehicles v
INNER JOIN services s ON v.vehicle_id = s.vehicle_id
GROUP BY v.make
ORDER BY v.make;


-- =============================================================================
-- VIEW 2: vw_parts_cost_summary
-- Original Query 2 - Average & Total Cost of Parts
--
-- Identical logic to Access original, improved column naming.
-- Shows usage frequency, average cost, and total cost per part type.
-- =============================================================================

CREATE OR REPLACE VIEW vw_parts_cost_summary AS
SELECT
    part_name                           AS part,
    COUNT(part_name)                    AS total_used,
    ROUND(AVG(price)::NUMERIC, 2)       AS average_cost,
    SUM(price)                          AS total_cost
FROM parts
GROUP BY part_name
ORDER BY SUM(price) DESC;


-- =============================================================================
-- VIEW 3: vw_profit_by_service_type
-- Original Query 3 - Average & Total Profit by Service
--
-- Identical logic to Access original.
-- Shows count, average profit, and total profit per service type.
-- =============================================================================

CREATE OR REPLACE VIEW vw_profit_by_service_type AS
SELECT
    service_type                                        AS service_type,
    COUNT(*)                                            AS total_performed,
    ROUND(AVG(service_price - service_cost), 2)         AS average_profit,
    SUM(service_price) - SUM(service_cost)              AS total_profit,
    SUM(service_price)                                  AS total_revenue,
    SUM(service_cost)                                   AS total_expenses
FROM services
GROUP BY service_type
ORDER BY AVG(service_price - service_cost) DESC;


-- =============================================================================
-- VIEW 4: vw_mechanic_ratings
-- Original Query 4 - Average Mechanic Ratings
--
-- Improved: uses mechanic_code (original MEC001 style ID) for reference,
-- adds total services count and total revenue per mechanic.
-- =============================================================================

CREATE OR REPLACE VIEW vw_mechanic_ratings AS
SELECT
    m.mechanic_code                                     AS mechanic_id,
    m.mechanic_name,
    COUNT(s.service_id)                                 AS total_services,
    ROUND(AVG(s.technician_rating)::NUMERIC, 1)         AS average_rating,
    SUM(s.service_price)                                AS total_revenue,
    SUM(s.service_price) - SUM(s.service_cost)          AS total_profit
FROM mechanics m
INNER JOIN services s ON m.mechanic_id = s.mechanic_id
GROUP BY m.mechanic_id, m.mechanic_code, m.mechanic_name
ORDER BY AVG(s.technician_rating) DESC;


-- =============================================================================
-- VIEW 5: vw_customer_spending
-- Original Query 5 - Customer Visit & Spending Totals
--
-- Identical logic to Access original.
-- Shows total visits and total amount spent per customer.
-- =============================================================================

CREATE OR REPLACE VIEW vw_customer_spending AS
SELECT
    c.customer_name                     AS name,
    c.phone_number,
    COUNT(s.service_id)                 AS total_visits,
    SUM(s.service_price)                AS total_spent
FROM customers c
INNER JOIN vehicles v   ON c.customer_id = v.customer_id
INNER JOIN services s   ON v.vehicle_id  = s.vehicle_id
GROUP BY c.customer_id, c.customer_name, c.phone_number
ORDER BY COUNT(s.service_id) DESC, SUM(s.service_price) DESC;


-- =============================================================================
-- VIEW 6: vw_monthly_financials
-- Original Query 8 - Monthly Profit, Revenue & Expenses by Year
--
-- Access required entering a year via a dialog box each time.
-- This view includes ALL years and adds a year column so you can
-- filter by year directly: SELECT * FROM vw_monthly_financials WHERE year = 2024;
-- =============================================================================

CREATE OR REPLACE VIEW vw_monthly_financials AS
SELECT
    EXTRACT(YEAR  FROM repair_date)::INTEGER            AS year,
    EXTRACT(MONTH FROM repair_date)::INTEGER            AS month_number,
    TO_CHAR(repair_date, 'Month')                       AS month_name,
    COUNT(service_id)                                   AS total_services,
    SUM(service_cost)                                   AS total_expenses,
    SUM(service_price)                                  AS total_revenue,
    SUM(service_price) - SUM(service_cost)              AS total_profit
FROM services
GROUP BY
    EXTRACT(YEAR  FROM repair_date),
    EXTRACT(MONTH FROM repair_date),
    TO_CHAR(repair_date, 'Month')
ORDER BY year, month_number;


-- =============================================================================
-- VIEW 7: vw_towing_summary
-- Original Query 9 - Towing Mileage Information
--
-- Identical logic to Access original.
-- Single-row summary of towing operations across all records.
-- =============================================================================

CREATE OR REPLACE VIEW vw_towing_summary AS
SELECT
    ROUND(AVG(t.tow_distance_miles)::NUMERIC, 1)            AS avg_towing_distance,
    MIN(t.tow_distance_miles)                               AS min_towing_distance,
    MAX(t.tow_distance_miles)                               AS max_towing_distance,
    ROUND(
        (SUM(s.service_cost) / NULLIF(SUM(t.tow_distance_miles), 0))::NUMERIC,
        2
    )                                                       AS avg_cost_per_mile
FROM towing t
INNER JOIN services s ON t.service_id = s.service_id;


-- =============================================================================
-- VIEW 8: vw_repeat_service_vehicles
-- Original Query 10 - Vehicles Serviced More Than Once
--
-- Improved: uses split make/model columns instead of Make_and_Model text.
-- Shows vehicles with more than one service record.
-- =============================================================================

CREATE OR REPLACE VIEW vw_repeat_service_vehicles AS
SELECT
    v.vehicle_id,
    v.make || ' ' || v.model              AS vehicle,
    c.customer_name                       AS owner,
    c.phone_number,
    COUNT(s.service_id)                   AS total_services
FROM customers c
INNER JOIN vehicles v   ON c.customer_id = v.customer_id
INNER JOIN services s   ON v.vehicle_id  = s.vehicle_id
GROUP BY v.vehicle_id, v.make, v.model, c.customer_name, c.phone_number
HAVING COUNT(s.service_id) > 1
ORDER BY COUNT(s.service_id) DESC, c.customer_name;