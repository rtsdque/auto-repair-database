"""
analytics.py
Pulls data from the Auto Repair Shop PostgreSQL database and generates
five analytical charts using pandas, matplotlib, and seaborn.

Charts produced:
    1. Total Profit by Service Type       (bar chart)
    2. Monthly Revenue vs Expenses 2024   (line chart)
    3. Top 10 Most Costly Parts           (horizontal bar chart)
    4. Mechanic Average Ratings           (bar chart)
    5. Services by Vehicle Type           (pie chart)

Usage:
    python python/analytics/analytics.py

Charts are saved to python/analytics/charts/ as PNG files
and also displayed on screen.
"""

import os
import warnings
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
from pathlib import Path

warnings.filterwarnings("ignore")
load_dotenv()

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DB_URL = (
    f"postgresql+psycopg2://"
    f"{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}"
    f"/{os.getenv('DB_NAME')}"
)

CHARTS_DIR = Path("python/analytics/charts")
CHARTS_DIR.mkdir(parents=True, exist_ok=True)

# Global style
sns.set_theme(style="darkgrid", palette="muted")
TITLE_FONT  = {"fontsize": 14, "fontweight": "bold", "pad": 15}
LABEL_FONT  = {"fontsize": 11}
ACCENT      = "#4C72B0"
COLORS      = sns.color_palette("muted", 10)


def get_engine():
    return create_engine(DB_URL)


def save_and_show(fig, filename):
    path = CHARTS_DIR / filename
    fig.savefig(path, dpi=150, bbox_inches="tight")
    print(f"  Saved: {path}")
    plt.show()
    plt.close(fig)


# ---------------------------------------------------------------------------
# Chart 1: Total Profit by Service Type
# Source: vw_profit_by_service_type
# ---------------------------------------------------------------------------

def chart_profit_by_service():
    print("Generating Chart 1: Total Profit by Service Type...")

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text("""
            SELECT service_type, total_profit, average_profit, total_performed
            FROM vw_profit_by_service_type
            ORDER BY total_profit DESC
        """), conn)

    fig, ax = plt.subplots(figsize=(10, 6))

    bars = ax.bar(df["service_type"], df["total_profit"], color=COLORS, edgecolor="white", linewidth=0.8)

    # Add value labels on top of each bar
    for bar in bars:
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 10000,
            f"${bar.get_height():,.0f}",
            ha="center", va="bottom", fontsize=9, fontweight="bold"
        )

    ax.set_title("Total Profit by Service Type", **TITLE_FONT)
    ax.set_xlabel("Service Type", **LABEL_FONT)
    ax.set_ylabel("Total Profit ($)", **LABEL_FONT)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    ax.set_xticklabels(df["service_type"], rotation=25, ha="right")
    plt.tight_layout()

    save_and_show(fig, "01_profit_by_service_type.png")


# ---------------------------------------------------------------------------
# Chart 2: Monthly Revenue vs Expenses — 2024
# Source: vw_monthly_financials
# ---------------------------------------------------------------------------

def chart_monthly_financials():
    print("Generating Chart 2: Monthly Revenue vs Expenses (2024)...")

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text("""
            SELECT month_number, month_name, total_revenue, total_expenses, total_profit
            FROM vw_monthly_financials
            WHERE year = 2024
            ORDER BY month_number
        """), conn)

    df["month_name"] = df["month_name"].str.strip()

    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(df["month_name"], df["total_revenue"],  marker="o", linewidth=2.5, label="Revenue",  color="#4C72B0")
    ax.plot(df["month_name"], df["total_expenses"], marker="s", linewidth=2.5, label="Expenses", color="#DD8452")
    ax.plot(df["month_name"], df["total_profit"],   marker="^", linewidth=2.5, label="Profit",   color="#55A868")

    ax.set_title("Monthly Revenue, Expenses & Profit — 2024", **TITLE_FONT)
    ax.set_xlabel("Month", **LABEL_FONT)
    ax.set_ylabel("Amount ($)", **LABEL_FONT)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    ax.set_xticklabels(df["month_name"], rotation=30, ha="right")
    ax.legend(fontsize=10)
    plt.tight_layout()

    save_and_show(fig, "02_monthly_financials_2024.png")


# ---------------------------------------------------------------------------
# Chart 3: Top 10 Most Costly Parts (by total cost)
# Source: vw_parts_cost_summary
# ---------------------------------------------------------------------------

def chart_top_parts():
    print("Generating Chart 3: Top 10 Most Costly Parts...")

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text("""
            SELECT part, total_cost, total_used, average_cost
            FROM vw_parts_cost_summary
            ORDER BY total_cost DESC
            LIMIT 10
        """), conn)

    fig, ax = plt.subplots(figsize=(10, 7))

    bars = ax.barh(df["part"][::-1], df["total_cost"][::-1], color=COLORS, edgecolor="white")

    for bar in bars:
        ax.text(
            bar.get_width() + 5000,
            bar.get_y() + bar.get_height() / 2,
            f"${bar.get_width():,.0f}",
            va="center", fontsize=9, fontweight="bold"
        )

    ax.set_title("Top 10 Most Costly Parts (Total Cost)", **TITLE_FONT)
    ax.set_xlabel("Total Cost ($)", **LABEL_FONT)
    ax.set_ylabel("Part", **LABEL_FONT)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    plt.tight_layout()

    save_and_show(fig, "03_top_10_costly_parts.png")


# ---------------------------------------------------------------------------
# Chart 4: Mechanic Average Ratings
# Source: vw_mechanic_ratings
# ---------------------------------------------------------------------------

def chart_mechanic_ratings():
    print("Generating Chart 4: Mechanic Average Ratings...")

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text("""
            SELECT mechanic_name, average_rating, total_services
            FROM vw_mechanic_ratings
            ORDER BY average_rating DESC, mechanic_name
        """), conn)

    fig, ax = plt.subplots(figsize=(11, 7))

    bar_colors = [
        "#55A868" if r >= 3.0 else "#DD8452" if r >= 2.5 else "#C44E52"
        for r in df["average_rating"]
    ]

    bars = ax.barh(df["mechanic_name"][::-1], df["average_rating"][::-1],
                   color=bar_colors[::-1], edgecolor="white")

    for bar in bars:
        ax.text(
            bar.get_width() + 0.02,
            bar.get_y() + bar.get_height() / 2,
            f"{bar.get_width():.1f}",
            va="center", fontsize=9, fontweight="bold"
        )

    ax.set_xlim(0, 5.5)
    ax.axvline(x=3.0, color="gray", linestyle="--", linewidth=1, alpha=0.7, label="Rating = 3.0")
    ax.set_title("Mechanic Average Ratings (out of 5)", **TITLE_FONT)
    ax.set_xlabel("Average Rating", **LABEL_FONT)
    ax.set_ylabel("Mechanic", **LABEL_FONT)
    ax.legend(fontsize=9)
    plt.tight_layout()

    save_and_show(fig, "04_mechanic_ratings.png")


# ---------------------------------------------------------------------------
# Chart 5: Services by Vehicle Type
# Source: vehicles + services tables
# ---------------------------------------------------------------------------

def chart_services_by_vehicle_type():
    print("Generating Chart 5: Services by Vehicle Type...")

    engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text("""
            SELECT v.vehicle_type::TEXT AS vehicle_type, COUNT(s.service_id) AS total_services
            FROM vehicles v
            INNER JOIN services s ON v.vehicle_id = s.vehicle_id
            GROUP BY v.vehicle_type
            ORDER BY total_services DESC
        """), conn)

    fig, ax = plt.subplots(figsize=(8, 8))

    wedges, texts, autotexts = ax.pie(
        df["total_services"],
        labels=df["vehicle_type"],
        autopct="%1.1f%%",
        colors=COLORS,
        startangle=140,
        wedgeprops={"edgecolor": "white", "linewidth": 1.5}
    )

    for autotext in autotexts:
        autotext.set_fontsize(10)
        autotext.set_fontweight("bold")

    ax.set_title("Services by Vehicle Type", **TITLE_FONT)
    plt.tight_layout()

    save_and_show(fig, "05_services_by_vehicle_type.png")


# ---------------------------------------------------------------------------
# Main — run all charts
# ---------------------------------------------------------------------------

def main():
    print("\n" + "="*50)
    print("  Auto Repair Shop — Analytics Dashboard")
    print("="*50 + "\n")

    chart_profit_by_service()
    chart_monthly_financials()
    chart_top_parts()
    chart_mechanic_ratings()
    chart_services_by_vehicle_type()

    print("\n" + "="*50)
    print(f"  All charts saved to: python/analytics/charts/")
    print("="*50 + "\n")


if __name__ == "__main__":
    main()