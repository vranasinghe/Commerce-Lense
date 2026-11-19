"""Load successful API snapshots into Bronze; --refresh explicitly replaces a snapshot."""
import argparse
import json
import hashlib
from sqlalchemy import create_engine, text
from config import LANDING_DIR, database_url
from fetch_apis import validate_records

def load(refresh=False):
    folder = LANDING_DIR/'api'
    status = json.loads((folder/'fetch_status.json').read_text())
    names = ['states_regions','holidays','usd_brl_rates']
    snapshots = {}
    for name in names:
        if status.get(name,{}).get('status') != 'success':
            raise ValueError(f'{name}: latest fetch failed; refusing stale data')
        raw = (folder/(name+'.json')).read_text(encoding='utf-8')
        if hashlib.sha256(raw.encode('utf-8')).hexdigest()!=status[name].get('sha256'):
            raise ValueError(f'{name}: snapshot/status digest mismatch; fetch again')
        validate_records(name,json.loads(raw))
        snapshots[name] = raw
    engine = create_engine(database_url('olist_dw'))
    try:
        with engine.begin() as con:
            if con.exec_driver_sql('SELECT DB_NAME()').scalar()!='olist_dw':
                raise ValueError('Connection override must target olist_dw')
            con.exec_driver_sql('SET XACT_ABORT ON;')
            lock=con.exec_driver_sql("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource='CommerceLens_ingest',@LockMode='Exclusive',@LockOwner='Transaction'; SELECT @r;").scalar()
            if lock<0:raise RuntimeError('Could not acquire API ingestion lock')
            for name,raw in snapshots.items():
                table = 'dbo.bronze_landing_'+name
                count = con.execute(text(f'SELECT COUNT(*) FROM {table} WITH (TABLOCKX,HOLDLOCK)')).scalar()
                if count and not refresh: raise ValueError(f'{table} populated; use --refresh')
                con.execute(text(f'DELETE FROM {table}'))
                con.execute(text(f'INSERT INTO {table}(raw_json) VALUES (:raw)'),{'raw':raw})
    finally: engine.dispose()
if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--refresh',action='store_true')
    load(parser.parse_args().refresh)
