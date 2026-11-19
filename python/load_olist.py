"""Load original OLTP tables or mapped Bronze tables; refresh requires --refresh."""
import argparse
import logging
import json
from datetime import datetime, timezone
from config import REPORT_DIR
from sqlalchemy import create_engine, text, inspect, UnicodeText
from config import RAW_DIR, database_url
from sources import FILES, bronze_table, bronze_column, read_source
log = logging.getLogger(__name__)

def load(target='oltp', refresh=False):
    names = list(FILES) if target == 'bronze' else list(FILES)[:7]
    # Validate every source before connecting or changing data.
    frames = {name: read_source(name, RAW_DIR) for name in names}
    engine = create_engine(database_url('olist_dw' if target == 'bronze' else 'olist_oltp'), fast_executemany=True)
    try:
        with engine.begin() as connection:
            expected_database='olist_dw' if target=='bronze' else 'olist_oltp'
            if connection.exec_driver_sql('SELECT DB_NAME()').scalar()!=expected_database:
                raise ValueError(f'Connection override must target {expected_database}')
            connection.exec_driver_sql("SET XACT_ABORT ON; SET LOCK_TIMEOUT 30000;")
            result = connection.exec_driver_sql("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='CommerceLens_ingest', @LockMode='Exclusive', @LockOwner='Transaction'; SELECT @r;").scalar()
            if result < 0: raise RuntimeError('Could not acquire ingestion lock')
            for name, frame in frames.items():
                table = bronze_table(name) if target == 'bronze' else {'order_payments':'payments','order_reviews':'reviews'}.get(name,name)
                if target == 'bronze': frame = frame.rename(columns={c:bronze_column(name,c) for c in frame.columns})
                exists = inspect(connection).has_table(table, schema='dbo')
                if exists:
                    count = connection.execute(text(f'SELECT COUNT_BIG(*) FROM dbo.[{table}]')).scalar()
                    if count and not refresh: raise ValueError(f'{table} contains {count} rows; use --refresh for transactional full refresh')
                    columns = [c['name'] for c in inspect(connection).get_columns(table, schema='dbo')]
                    if columns != list(frame.columns): raise ValueError(f'{table}: schema mismatch; inspect existing database before migration')
                    if refresh: connection.execute(text(f'DELETE FROM dbo.[{table}]'))
                frame.to_sql(table, connection, schema='dbo', if_exists='append', index=False,
                             dtype={c:UnicodeText() for c in frame.columns}, chunksize=1000)
                loaded = connection.execute(text(f'SELECT COUNT_BIG(*) FROM dbo.[{table}]')).scalar()
                if loaded != len(frame): raise ValueError(f'{table}: reconciliation failed')
                log.info('Loaded %s: %d rows (pending commit)', table, loaded)
        log.info('Committed %s snapshot', target)
        try:
            REPORT_DIR.mkdir(parents=True,exist_ok=True)
            (REPORT_DIR/f'load-{target}.json').write_text(json.dumps({'target':target,'status':'committed','utc':datetime.now(timezone.utc).isoformat(),'rows':{name:len(frame) for name,frame in frames.items()}},indent=2),encoding='utf-8')
        except OSError:
            log.warning('Load committed but local audit report could not be written',exc_info=True)
    finally:
        engine.dispose()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['oltp','bronze'], default='oltp')
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s %(message)s')
    try: load(args.target, args.refresh)
    except Exception:
        log.exception('Load failed; active transaction rolled back')
        raise SystemExit(1)
if __name__ == '__main__': main()
