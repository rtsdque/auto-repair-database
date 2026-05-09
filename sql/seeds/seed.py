"""
seed.py
Loads exported Access CSVs into PostgreSQL.
Run from the project root with the virtual environment active:
    python sql/seeds/seed.py
"""

import os
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     os.getenv("DB_PORT", 5432),
    "dbname":   os.getenv("DB_NAME", "auto_repair_shop"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
}

EXPORTS = Path("data/exports")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def connect():
    print("Connecting to PostgreSQL...")
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    print("Connected.\n")
    return conn


def split_make_model(make_and_model: str):
    """Split 'BMW Corolla' → ('BMW', 'Corolla')"""
    parts = str(make_and_model).strip().split(" ", 1)
    make  = parts[0] if len(parts) > 0 else "Unknown"
    model = parts[1] if len(parts) > 1 else "Unknown"
    return make, model


def parse_bool(value):
    """Convert 'Yes'/'No' to True/False."""
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() == "yes"


def parse_date(value):
    """Parse date values exported by pyodbc."""
    if pd.isna(value):
        return None
    return pd.to_datetime(value).date()

# ---------------------------------------------------------------------------
# Seed functions (order matters — respect FK dependencies)
# ---------------------------------------------------------------------------

def seed_customers(conn):
    print("Seeding customers...")
    df = pd.read_csv(EXPORTS / "customers.csv")

    rows = [
        (
            int(row["Customer_ID"]),
            str(row["Customer_Name"]).strip() if pd.notna(row["Customer_Name"]) else None,
            str(row["Phone_Number"]).strip(),
        )
        for _, row in df.iterrows()
    ]

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO customers (customer_id, customer_name, phone_number)
            VALUES %s
            ON CONFLICT (customer_id) DO NOTHING
        """, rows)

        # Sync the SERIAL sequence so future inserts don't conflict
        cur.execute("SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers))")

    print(f"  {len(rows):,} customers inserted.")


def seed_mechanics(conn):
    print("Seeding mechanics...")
    df = pd.read_csv(EXPORTS / "mechanics.csv")

    rows = [
        (
            str(row["Mechanic_ID"]).strip(),   # mechanic_code e.g. "MEC001"
            str(row["Mechanic_Name"]).strip(),
        )
        for _, row in df.iterrows()
    ]

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO mechanics (mechanic_code, mechanic_name)
            VALUES %s
            ON CONFLICT (mechanic_code) DO NOTHING
        """, rows)

    print(f"  {len(rows):,} mechanics inserted.")


def seed_vehicles(conn):
    print("Seeding vehicles...")
    df = pd.read_csv(EXPORTS / "vehicles.csv")

    rows = [
        (
            int(row["Vehicle_ID"]),
            str(row["Vehicle_Type"]).strip(),
            *split_make_model(row["Make_and_Model"]),
            int(row["Customer_ID"]),
        )
        for _, row in df.iterrows()
    ]

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO vehicles (vehicle_id, vehicle_type, make, model, customer_id)
            VALUES %s
            ON CONFLICT (vehicle_id) DO NOTHING
        """, rows)

        cur.execute("SELECT setval('vehicles_vehicle_id_seq', (SELECT MAX(vehicle_id) FROM vehicles))")

    print(f"  {len(rows):,} vehicles inserted.")


def seed_services(conn):
    print("Seeding services...")
    df = pd.read_csv(EXPORTS / "services.csv")

    # Build mechanic_code → mechanic_id lookup
    with conn.cursor() as cur:
        cur.execute("SELECT mechanic_id, mechanic_code FROM mechanics")
        mechanic_map = {code: mid for mid, code in cur.fetchall()}

    rows = []
    skipped = 0
    for _, row in df.iterrows():
        mechanic_code = str(row["Mechanic_ID"]).strip()
        mechanic_id   = mechanic_map.get(mechanic_code)

        if mechanic_id is None:
            skipped += 1
            continue

        duration = int(row["Service_Duration_Hours"]) if pd.notna(row["Service_Duration_Hours"]) else None
        rating   = int(row["Technician_Rating"])       if pd.notna(row["Technician_Rating"])       else None

        rows.append((
            int(row["Service_ID"]),
            int(row["Vehicle_ID"]),
            mechanic_id,
            str(row["Urgency_Level"]).strip(),
            str(row["Service_Type"]).strip(),
            str(row["Service_Description"]).strip(),
            parse_date(row["Repair_Date"]),
            int(row["Mileage_at_Service"]) if pd.notna(row["Mileage_at_Service"]) else None,
            duration,
            parse_bool(row["FollowUp_Needed"]),
            rating,
            str(row["Payment_Method"]).strip() if pd.notna(row["Payment_Method"]) else None,
            float(row["Service_Cost"]),
            float(row["Service_Price"]),
        ))

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO services (
                service_id, vehicle_id, mechanic_id,
                urgency_level, service_type, service_description,
                repair_date, mileage_at_service, service_duration_hours,
                follow_up_needed, technician_rating, payment_method,
                service_cost, service_price
            )
            VALUES %s
            ON CONFLICT (service_id) DO NOTHING
        """, rows)

        cur.execute("SELECT setval('services_service_id_seq', (SELECT MAX(service_id) FROM services))")

    print(f"  {len(rows):,} services inserted. {skipped} skipped (mechanic not found).")


def seed_parts(conn):
    print("Seeding parts...")
    df = pd.read_csv(EXPORTS / "parts.csv")

    rows = [
        (
            str(row["Part_ID"]).strip(),
            str(row["Parts_Used"]).strip(),
            float(row["Price"]),
            int(row["Service_ID"]),
        )
        for _, row in df.iterrows()
    ]

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO parts (part_code, part_name, price, service_id)
            VALUES %s
            ON CONFLICT (part_code) DO NOTHING
        """, rows)

    print(f"  {len(rows):,} parts inserted.")


def seed_towing(conn):
    print("Seeding towing...")
    df = pd.read_csv(EXPORTS / "towing.csv")

    rows = [
        (
            str(row["Towing_ID"]).strip(),
            parse_date(row["Towing_Date"]),
            str(row["PickUP_Location"]).strip(),
            str(row["DropOff_Location"]).strip(),
            int(row["Tow_Distance_Miles"]) if pd.notna(row["Tow_Distance_Miles"]) else None,
            int(row["Service_ID"]),
        )
        for _, row in df.iterrows()
    ]

    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO towing (towing_code, towing_date, pickup_location, dropoff_location, tow_distance_miles, service_id)
            VALUES %s
            ON CONFLICT (towing_code) DO NOTHING
        """, rows)

    print(f"  {len(rows):,} towing records inserted.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    conn = connect()
    try:
        seed_customers(conn)
        seed_mechanics(conn)
        seed_vehicles(conn)
        seed_services(conn)
        seed_parts(conn)
        seed_towing(conn)

        conn.commit()
        print("\nAll data committed successfully.")

        # Row count verification
        print("\n--- Verification ---")
        with conn.cursor() as cur:
            for table in ["customers", "mechanics", "vehicles", "services", "parts", "towing"]:
                cur.execute(f"SELECT COUNT(*) FROM {table}")
                count = cur.fetchone()[0]
                print(f"  {table}: {count:,} rows")

    except Exception as e:
        conn.rollback()
        print(f"\nERROR: {e}")
        print("Transaction rolled back — no data was written.")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
