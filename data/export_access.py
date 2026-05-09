"""
export_access.py
Reads all 6 tables from the Access database and exports them as CSVs
to data/exports/ for use by the seed script.
"""

import pyodbc
import pandas as pd
from pathlib import Path

# --- Config ---
ACCESS_FILE = r"C:\Users\16315\Desktop\Python\Projects\Auto Repair Database\Microsoft Access Files\Group 6 - Vehicle Repair Database.accdb"
EXPORT_DIR  = Path(__file__).parent / "exports"
EXPORT_DIR.mkdir(exist_ok=True)

TABLES = ["CUSTOMERS", "MECHANICS", "VEHICLES", "SERVICES", "PARTS", "TOWING"]

# --- Connect ---
conn_str = (
    r"DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};"
    rf"DBQ={ACCESS_FILE};"
)

print("Connecting to Access database...")
conn = pyodbc.connect(conn_str)

# --- Export each table ---
for table in TABLES:
    print(f"Exporting {table}...", end=" ")
    df = pd.read_sql(f"SELECT * FROM [{table}]", conn)
    out_path = EXPORT_DIR / f"{table.lower()}.csv"
    df.to_csv(out_path, index=False)
    print(f"{len(df):,} rows → {out_path.name}")

conn.close()
print("\nAll tables exported successfully.")