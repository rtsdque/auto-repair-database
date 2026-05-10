# Auto Repair Shop Database

A full-scale database migration and redesign project — taking a real-world Microsoft Access vehicle repair database and rebuilding it in PostgreSQL with proper schema design, Python analytics, and production-grade features.

---

## Background

This project originated as a group database assignment built in Microsoft Access. While the original database was functional, Access has significant limitations as a production database system — no enforced foreign keys, no role-based access control, limited data type support, and no programmatic query layer.

This PostgreSQL version is a complete redesign and upgrade of that original work, addressing every one of those limitations while preserving all of the original data and query logic.

---

## What Was Improved

| Area | Microsoft Access Original | PostgreSQL Version |
|---|---|---|
| Foreign keys | Not enforced | Enforced at DB level |
| Data types | Mixed Text/Integer IDs | Normalized SERIAL integers |
| Categorical fields | Free text | Enums (controlled vocabulary) |
| Vehicle make/model | Single `Make_and_Model` column | Split into `make` and `model` |
| Follow-up tracking | "Yes"/"No" text | `BOOLEAN` |
| Access control | File-level only | Role-based (admin, mechanic, analyst) |
| Audit logging | None | Automatic trigger-based audit log |
| Analytics | Manual queries | Python + pandas + matplotlib charts |
| Version control | None | Git + GitHub |

---

## Database Overview

- **Source:** Microsoft Access (.accdb)
- **Target:** PostgreSQL 18
- **Total rows migrated:** 75,510
- **Tables:** 7 (6 core + audit log)

| Table | Rows | Description |
|---|---|---|
| customers | 5,011 | Customer names and contact info |
| mechanics | 20 | Mechanic roster |
| vehicles | 14,875 | Vehicles linked to customers |
| services | 14,998 | Core fact table — all repair records |
| parts | 38,412 | Parts used per service |
| towing | 2,194 | Towing jobs linked to services |
| services_audit | — | Automatic audit log of service changes |

---

## Project Structure

```
auto_repair_shop/
├── sql/
│   ├── schema/
│   │   ├── 001_create_tables.sql   # DDL — tables, enums, constraints, indexes
│   │   └── 002_roles.sql           # Role-based access control
│   ├── seeds/
│   │   └── seed.py                 # Data migration script (Access → PostgreSQL)
│   ├── views/
│   │   ├── 001_views.sql           # 8 analytical views
│   │   └── 002_easter_egg.sql      # 🐣
│   ├── procedures/
│   │   └── 001_procedures.sql      # 3 stored procedures
│   └── triggers/
│       └── 001_triggers.sql        # Audit trigger + delete protection
├── data/
│   ├── export_access.py            # Exports Access tables to CSV via pyodbc
│   └── exports/                    # CSV exports (git-ignored)
├── python/
│   ├── queries/
│   │   └── queries.py              # Interactive parameterized query tool
│   └── analytics/
│       ├── analytics.py            # Chart generation script
│       └── charts/                 # Generated PNG charts
├── docs/                           # ERD and data dictionary (coming soon)
├── .env.example                    # DB connection template
├── requirements.txt
└── README.md
```

---

## Schema Design Highlights

### Enums
Five PostgreSQL enum types replace free-text fields, enforcing data integrity at the database level:
- `urgency_level` — Scheduled, Standard, Emergency
- `service_type` — Oil Change, Battery Replacement, Tire Replacement, Brake Service, Engine Repair, Transmission Repair, Towing
- `payment_method` — Cash, Credit Card, Debit Card, Insurance, Company Invoice
- `vehicle_type` — Car, Truck, Van, SUV, Bus, Motorcycle
- `towing_location` — Residential, Commercial, Garage, Dealer, Highway, Parking Lot

### Foreign Keys
All relationships enforced at the database level with `ON DELETE RESTRICT` to prevent orphaned records.

### Indexes
Indexes on all foreign key columns and commonly queried fields (`repair_date`, `service_type`) for fast query performance.

---

## Analytical Views

Eight views recreate and improve the original Access queries as permanent, reusable database objects:

| View | Description |
|---|---|
| `vw_service_totals_by_brand` | Service counts per vehicle brand (replaces Access PIVOT) |
| `vw_parts_cost_summary` | Parts usage, average cost, and total cost |
| `vw_profit_by_service_type` | Profitability analysis per service type |
| `vw_mechanic_ratings` | Mechanic performance — ratings, services, revenue |
| `vw_customer_spending` | Customer visit counts and total spend |
| `vw_monthly_financials` | Monthly revenue, expenses, and profit across all years |
| `vw_towing_summary` | Towing distance stats and cost per mile |
| `vw_repeat_service_vehicles` | Vehicles with more than one service record |

---

## Stored Procedures

| Procedure | Description |
|---|---|
| `add_service` | Inserts a new service record with full validation |
| `add_towing` | Inserts a new towing record with auto-generated towing code |
| `get_vehicle_history` | Prints complete service history for a given vehicle |

---

## Triggers

**`trg_services_audit`** — fires automatically after every `UPDATE` on the services table. Logs the field changed, old value, new value, timestamp, and database user to the `services_audit` table.

**`trg_prevent_service_delete`** — fires before any `DELETE` on services. Blocks deletion if linked parts or towing records exist, with a descriptive error message.

---

## Role-Based Access Control

| Role | Permissions |
|---|---|
| `shop_admin` | Full access to all tables, sequences, and routines |
| `shop_mechanic` | Read all, insert services/parts, update service fields (blocked from `service_cost` and `service_price`) |
| `shop_analyst` | Read-only access to all tables and views |

---

## Python Query Layer

An interactive terminal tool (`python/queries/queries.py`) rebuilds the original Access parameterized queries as Python functions:

```
========================================
  Auto Repair Shop — Query Tool
========================================
1. Customer Records Search
2. Parts Used For Each Service
3. Follow-Ups Needed
4. Insurance Claims
0. Exit
========================================
```

Features case-insensitive partial name matching, formatted output with totals, and graceful handling of invalid inputs.

---

## Analytics & Charts

Five charts generated directly from PostgreSQL views using pandas, matplotlib, and seaborn:

| Chart | Type | Source View |
|---|---|---|
| Total Profit by Service Type | Bar chart | `vw_profit_by_service_type` |
| Monthly Revenue, Expenses & Profit 2024 | Line chart | `vw_monthly_financials` |
| Top 10 Most Costly Parts | Horizontal bar | `vw_parts_cost_summary` |
| Mechanic Average Ratings | Horizontal bar | `vw_mechanic_ratings` |
| Services by Vehicle Type | Pie chart | Direct query |

---

## Getting Started

### Prerequisites
- PostgreSQL 14+
- Python 3.10+
- Microsoft Access Driver (Windows, for initial data export only)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/rtsdque/auto-repair-database.git
cd auto-repair-database

# 2. Create and activate virtual environment
python -m venv venv
venv\Scripts\activate  # Windows

# 3. Install dependencies
pip install -r requirements.txt

# 4. Create the database
psql -U postgres -c "CREATE DATABASE auto_repair_shop;"

# 5. Run the schema
psql -U postgres -d auto_repair_shop -f sql/schema/001_create_tables.sql

# 6. Run roles
psql -U postgres -d auto_repair_shop -f sql/schema/002_roles.sql

# 7. Run views, procedures, triggers
psql -U postgres -d auto_repair_shop -f sql/views/001_views.sql
psql -U postgres -d auto_repair_shop -f sql/procedures/001_procedures.sql
psql -U postgres -d auto_repair_shop -f sql/triggers/001_triggers.sql

# 8. Export Access data and seed (requires original .accdb file)
python data/export_access.py
python sql/seeds/seed.py
```

### Run the query tool
```bash
python python/queries/queries.py
```

### Generate charts
```bash
python python/analytics/analytics.py
```

---

## Tech Stack

- **Database:** PostgreSQL 18
- **Language:** Python 3.13
- **Libraries:** psycopg2, SQLAlchemy, pandas, matplotlib, seaborn, python-dotenv
- **Tools:** pgAdmin 4, Git, GitHub, VS Code
- **Original source:** Microsoft Access (.accdb)
