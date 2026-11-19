"""Project test database only. Checks missing purchase date, then rolls everything back."""
import argparse
import json
from pathlib import Path
import re
import sys
from sqlalchemy import create_engine,text
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
from config import ROOT,database_url

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--confirm-test-database',required=True,choices=['olist_dw']);parser.parse_args()
    engine=create_engine(database_url('olist_dw'));con=engine.connect();transaction=con.begin()
    try:
        if con.execute(text('SELECT DB_NAME()')).scalar()!='olist_dw':raise RuntimeError('Wrong test database')
        order=con.execute(text('SELECT TOP(1) order_id FROM dbo.fact_orders ORDER BY order_id')).scalar()
        con.execute(text("UPDATE dbo.bronze_orders SET [Copy of order_purchase_timestamp]='' WHERE [Copy of order_id]=:order"),{'order':order})
        for rel in ['sql/silver/transform_orders_bronze_to_silver.sql','sql/gold/fact_orders.sql']:
            for batch in re.split(r'^\s*GO\s*$',(ROOT/rel).read_text(),flags=re.M|re.I):
                if not batch.strip():continue
                cursor=con.connection.driver_connection.cursor()
                try:
                    cursor.execute(batch)
                    while cursor.nextset():pass
                finally:cursor.close()
        rows=con.execute(text('SELECT order_date FROM dbo.dm_sales_performance WHERE order_id=:order'),{'order':order}).all()
        if not rows or any(row[0] is not None for row in rows):raise AssertionError('NULL date rows missing from sales mart')
    finally:
        if transaction.is_active:transaction.rollback()
        con.close();engine.dispose()
    evidence={'blank_bronze_timestamp_becomes_null':True,'nullable_date_fk_accepted':True,'item_rows_preserved_in_mart':len(rows),'transaction_rolled_back':True}
    (ROOT/'docs/verification/unknown-date.json').write_text(json.dumps(evidence,indent=2));print(json.dumps(evidence,indent=2))
if __name__=='__main__':main()
