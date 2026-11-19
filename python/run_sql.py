"""Ordered warehouse build in one transaction. Never runs the legacy migration automatically."""
import argparse
import logging
import re
from sqlalchemy import create_engine
from config import ROOT, database_url

def script_paths(include_api=False):
    silver=sorted((ROOT/'sql/silver').glob('*.sql'))
    if not include_api:
        silver=[p for p in silver if not any(t in p.name for t in ['holidays','usd_brl_rates','states_regions'])]
    return silver + [ROOT/'sql/gold'/p for p in ['dim_customers.sql','dim_products.sql','dim_sellers.sql','dim_date.sql','fact_orders.sql','fact_order_summary.sql']] + [ROOT/'sql/datamarts'/p for p in ['dm_sales_performance.sql','dm_customer_insights.sql']] + [ROOT/'sql/validation/validate_warehouse.sql']

def run(include_api=False):
    engine=create_engine(database_url('olist_dw'))
    try:
        with engine.begin() as con:
            if con.exec_driver_sql('SELECT DB_NAME()').scalar()!='olist_dw':
                raise ValueError('Connection override must target olist_dw')
            con.exec_driver_sql('SET XACT_ABORT ON; SET NOCOUNT ON; SET LOCK_TIMEOUT 30000;')
            result=con.exec_driver_sql("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='CommerceLens_ingest',@LockMode='Exclusive',@LockOwner='Transaction'; SELECT @r;").scalar()
            if result<0: raise RuntimeError('Could not acquire pipeline lock')
            for path in script_paths(include_api):
                logging.info('Executing %s',path.relative_to(ROOT))
                for batch in re.split(r'^\s*GO\s*$',path.read_text(encoding='utf-8'),flags=re.M|re.I):
                    if batch.strip():
                        # SQLAlchemy may auto-close a non-row first result; later THROWs
                        # then disappear. Drain the underlying ODBC cursor explicitly.
                        cursor=con.connection.driver_connection.cursor()
                        try:
                            cursor.execute(batch)
                            while True:
                                if cursor.description:
                                    rows=cursor.fetchall()
                                    logging.info('Result: %s', [tuple(row) for row in rows])
                                if not cursor.nextset(): break
                        finally:
                            cursor.close()
            logging.info('All SQL batches completed; committing snapshot')
    finally: engine.dispose()
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--include-api',action='store_true')
    logging.basicConfig(level=logging.INFO)
    run(parser.parse_args().include_api)
