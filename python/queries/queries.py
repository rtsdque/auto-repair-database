"""
queries.py
Parameterized query layer for the Auto Repair Shop Database.
Recreates the interactive Access queries as clean Python functions.

Queries in this file:
    1. customer_search       - Search service history by customer name
    2. parts_by_service      - Look up parts used for a specific service ID
    3. follow_ups_needed     - List all services requiring follow-up
    4. insurance_claims      - List all services paid by insurance

Usage:
    Run directly:  python python/queries/queries.py
    Or import:     from python.queries.queries import customer_search
"""

import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

# ---------------------------------------------------------------------------
# Database connection
# ---------------------------------------------------------------------------

def get_connection():
    return psycopg2.connect(
        host     = os.getenv("DB_HOST", "localhost"),
        port     = os.getenv("DB_PORT", 5432),
        dbname   = os.getenv("DB_NAME", "auto_repair_shop"),
        user     = os.getenv("DB_USER", "postgres"),
        password = os.getenv("DB_PASSWORD"),
    )


# ---------------------------------------------------------------------------
# Query 1: Customer Search
# Original Access Query 11 - Customer Records Search
#
# Searches for a customer by name (partial match supported).
# Returns all vehicles, services, repair dates, and prices.
# Prints a total spent summary at the end.
# ---------------------------------------------------------------------------

def customer_search(name: str):
    sql = """
        SELECT
            c.customer_name                     AS name,
            v.vehicle_id,
            v.make || ' ' || v.model            AS vehicle,
            s.service_type::TEXT                AS service,
            s.repair_date,
            s.service_price                     AS price
        FROM customers c
        INNER JOIN vehicles v ON c.customer_id = v.customer_id
        INNER JOIN services s ON v.vehicle_id  = s.vehicle_id
        WHERE c.customer_name ILIKE %s
        ORDER BY s.repair_date DESC
    """

    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(sql, (f"%{name}%",))
            rows = cur.fetchall()

        if not rows:
            print(f"\nNo records found for customer: '{name}'")
            return

        print(f"\n{'='*65}")
        print(f"  Customer Search Results: '{name}'")
        print(f"{'='*65}")
        print(f"{'Name':<20} {'Vehicle ID':<12} {'Vehicle':<25} {'Service':<22} {'Date':<12} {'Price':>8}")
        print(f"{'-'*65}")

        total = 0
        for row in rows:
            print(f"{str(row['name']):<20} {str(row['vehicle_id']):<12} {str(row['vehicle']):<25} {str(row['service']):<22} {str(row['repair_date']):<12} ${row['price']:>7.2f}")
            total += row['price']

        print(f"{'-'*65}")
        print(f"{'':>20} {'':>12} {'':>25} {'':>22} {'Total Spent':<12} ${total:>7.2f}")
        print(f"{'='*65}\n")

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Query 2: Parts by Service
# Original Access Query 12 - Parts Used For Each Service
#
# Looks up all parts used in a specific service by Service ID.
# Returns service type, repair date, parts used, and total cost.
# ---------------------------------------------------------------------------

def parts_by_service(service_id: int):
    sql = """
        SELECT
            s.service_id,
            s.service_type::TEXT    AS service,
            s.repair_date,
            p.part_name             AS part,
            p.price
        FROM services s
        INNER JOIN parts p ON s.service_id = p.service_id
        WHERE s.service_id = %s
        ORDER BY p.price DESC
    """

    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(sql, (service_id,))
            rows = cur.fetchall()

        if not rows:
            print(f"\nNo parts found for Service ID: {service_id}")
            return

        print(f"\n{'='*60}")
        print(f"  Parts for Service ID: {service_id}")
        print(f"  Service: {rows[0]['service']}  |  Date: {rows[0]['repair_date']}")
        print(f"{'='*60}")
        print(f"{'Part':<35} {'Price':>10}")
        print(f"{'-'*60}")

        total = 0
        for row in rows:
            print(f"{str(row['part']):<35} ${row['price']:>9.2f}")
            total += row['price']

        print(f"{'-'*60}")
        print(f"{'Total Cost':<35} ${total:>9.2f}")
        print(f"{'='*60}\n")

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Query 3: Follow-Ups Needed
# Original Access Query 6 - Follow-Ups Needed
#
# Returns all service records where follow_up_needed is TRUE.
# Sorted by repair date descending (most recent first).
# ---------------------------------------------------------------------------

def follow_ups_needed():
    sql = """
        SELECT
            s.service_id,
            s.repair_date,
            s.service_type::TEXT        AS service,
            s.urgency_level::TEXT       AS urgency,
            m.mechanic_name,
            c.customer_name,
            c.phone_number
        FROM services s
        INNER JOIN vehicles  v ON s.vehicle_id  = v.vehicle_id
        INNER JOIN customers c ON v.customer_id = c.customer_id
        INNER JOIN mechanics m ON s.mechanic_id = m.mechanic_id
        WHERE s.follow_up_needed = TRUE
        ORDER BY s.repair_date DESC
    """

    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()

        print(f"\n{'='*85}")
        print(f"  Follow-Ups Needed — {len(rows):,} records")
        print(f"{'='*85}")
        print(f"{'Service ID':<12} {'Date':<12} {'Service':<22} {'Urgency':<12} {'Mechanic':<18} {'Customer':<18} {'Phone'}")
        print(f"{'-'*85}")

        for row in rows:
            print(f"{str(row['service_id']):<12} {str(row['repair_date']):<12} {str(row['service']):<22} {str(row['urgency']):<12} {str(row['mechanic_name']):<18} {str(row['customer_name']):<18} {row['phone_number']}")

        print(f"{'='*85}\n")

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Query 4: Insurance Claims
# Original Access Query 7 - Insurance Claims
#
# Returns all service records where payment_method is 'Insurance'.
# Includes customer info, mechanic, cost, and price.
# ---------------------------------------------------------------------------

def insurance_claims():
    sql = """
        SELECT
            s.service_id,
            s.repair_date,
            s.service_type::TEXT        AS service,
            m.mechanic_name,
            c.customer_name,
            s.service_cost,
            s.service_price,
            s.service_price - s.service_cost AS profit
        FROM services s
        INNER JOIN vehicles  v ON s.vehicle_id  = v.vehicle_id
        INNER JOIN customers c ON v.customer_id = c.customer_id
        INNER JOIN mechanics m ON s.mechanic_id = m.mechanic_id
        WHERE s.payment_method = 'Insurance'
        ORDER BY s.repair_date DESC
    """

    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()

        total_revenue = sum(r['service_price'] for r in rows)
        total_cost    = sum(r['service_cost']  for r in rows)
        total_profit  = total_revenue - total_cost

        print(f"\n{'='*90}")
        print(f"  Insurance Claims — {len(rows):,} records")
        print(f"{'='*90}")
        print(f"{'Service ID':<12} {'Date':<12} {'Service':<22} {'Mechanic':<18} {'Customer':<18} {'Cost':>8} {'Price':>8} {'Profit':>8}")
        print(f"{'-'*90}")

        for row in rows:
            print(f"{str(row['service_id']):<12} {str(row['repair_date']):<12} {str(row['service']):<22} {str(row['mechanic_name']):<18} {str(row['customer_name']):<18} ${row['service_cost']:>7.2f} ${row['service_price']:>7.2f} ${row['profit']:>7.2f}")

        print(f"{'-'*90}")
        print(f"{'TOTALS':<84} ${total_cost:>7.2f} ${total_revenue:>7.2f} ${total_profit:>7.2f}")
        print(f"{'='*90}\n")

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Interactive menu — runs when script is executed directly
# ---------------------------------------------------------------------------

def main():
    print("\n" + "="*40)
    print("  Auto Repair Shop — Query Tool")
    print("="*40)
    print("1. Customer Records Search")
    print("2. Parts Used For Each Service")
    print("3. Follow-Ups Needed")
    print("4. Insurance Claims")
    print("0. Exit")
    print("="*40)

    while True:
        choice = input("\nEnter query number: ").strip()

        if choice == "1":
            name = input("Enter customer name: ").strip()
            customer_search(name)

        elif choice == "2":
            try:
                sid = int(input("Enter Service ID: ").strip())
                parts_by_service(sid)
            except ValueError:
                print("Please enter a valid numeric Service ID.")

        elif choice == "3":
            follow_ups_needed()

        elif choice == "4":
            insurance_claims()

        elif choice == "0":
            print("Goodbye.")
            break

        else:
            print("Invalid choice. Please enter 1, 2, 3, 4, or 0.")


if __name__ == "__main__":
    main()