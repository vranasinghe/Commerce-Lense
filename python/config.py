"""Shared environment configuration. Export variables before launching scripts."""
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = Path(os.environ.get("OLIST_RAW_DIR", ROOT / "docs"))
LANDING_DIR = Path(os.environ.get("OLIST_LANDING_DIR", ROOT / "data/landing"))
REPORT_DIR = Path(os.environ.get("OLIST_REPORT_DIR", ROOT / "data/processed"))
def database_url(database: str):
    from sqlalchemy.engine import URL
    return URL.create("mssql+pyodbc", query={"odbc_connect": os.environ.get(
        "OLIST_ODBC_CONNECTION", f"DRIVER={{{os.environ.get('OLIST_ODBC_DRIVER', 'ODBC Driver 17 for SQL Server')}}};SERVER={os.environ.get('OLIST_SQL_SERVER', '.')};DATABASE={database};Trusted_Connection=yes;")})
