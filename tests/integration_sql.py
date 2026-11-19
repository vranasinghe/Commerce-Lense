"""Opt-in regression test. Run ONLY against the project test database.
Temporarily injects one malformed Bronze price and restores it in finally.
"""
import argparse
import json
import logging
from pathlib import Path
import sys
from sqlalchemy import create_engine, text
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
from config import ROOT, database_url
from run_sql import run

def fingerprint(con):
    result={}
    for table in ['silver_orders','silver_order_items','dim_customers','dim_products','dim_sellers','fact_orders','fact_payments','fact_reviews']:
        # SQL CHECKSUM collisions are possible; financial/key EXCEPT tests remain authoritative.
        result[table]=list(con.execute(text(f'SELECT COUNT_BIG(*),CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM dbo.{table}')).one())
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--confirm-test-database',required=True,choices=['olist_dw'])
    parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    engine=create_engine(database_url('olist_dw'))
    with engine.connect() as con:
        if con.execute(text('SELECT DB_NAME()')).scalar()!='olist_dw':raise RuntimeError('Wrong test database')
        before=fingerprint(con)
        order_id,item_id,price=con.execute(text('SELECT TOP(1) [Copy of order_id],order_item_id,price FROM dbo.bronze_order_items ORDER BY [Copy of order_id],order_item_id')).one()
    params={'order':order_id,'item':item_id,'price':price}
    try:
        with engine.begin() as con:
            changed=con.execute(text("UPDATE dbo.bronze_order_items SET price='invalid_fixture' WHERE [Copy of order_id]=:order AND order_item_id=:item"),params).rowcount
            if changed!=1:raise AssertionError('Fixture must change exactly one row')
        rejected=False
        try:run()
        except Exception:rejected=True
        if not rejected:raise AssertionError('Malformed price was accepted')
        with engine.connect() as con:
            if fingerprint(con)!=before:raise AssertionError('Failed build changed committed warehouse')
    finally:
        with engine.begin() as con:
            con.execute(text('UPDATE dbo.bronze_order_items SET price=:price WHERE [Copy of order_id]=:order AND order_item_id=:item'),params)
    run(include_api=True)
    with engine.connect() as con:
        after=fingerprint(con)
        # Full refresh may regenerate fact identity values; compare natural grain/amounts instead.
        for table in before:
            if table!='fact_orders' and before[table]!=after[table]:raise AssertionError(f'Rerun changed {table}')
        if before['fact_orders'][0]!=after['fact_orders'][0]:raise AssertionError('Rerun changed item count')
        con.exec_driver_sql("IF EXISTS(SELECT order_id,order_item_id,price,freight_value FROM dbo.silver_order_items EXCEPT SELECT order_id,order_item_id,price,freight_value FROM dbo.fact_orders) THROW 51000,'Rerun financial mismatch',1;")
    evidence={'malformed_bronze_rejected':True,'failed_build_warehouse_unchanged':True,'bronze_restored':True,'identical_snapshot_rerun':True,'counts':{k:v[0] for k,v in after.items()}}
    (ROOT/'docs/verification/integration-sql.json').write_text(json.dumps(evidence,indent=2))
    print(json.dumps(evidence,indent=2))
    engine.dispose()
if __name__=='__main__':main()
