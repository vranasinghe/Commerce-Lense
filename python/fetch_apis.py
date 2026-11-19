"""Fetch validated reference feeds; failed feeds never replace existing files."""
import json
import hashlib
from datetime import timezone
import logging
import os
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from config import LANDING_DIR
log = logging.getLogger(__name__)

def validate_records(kind, records):
    if not isinstance(records, list) or not records:
        raise ValueError(f'{kind}: expected nonempty array')
    required = {'states_regions': {'sigla','nome','regiao'},
                'holidays': {'date','localName','name','countryCode','types'},
                'usd_brl_rates': {'data','valor'}}[kind]
    for row in records:
        if not isinstance(row, dict) or not required <= row.keys():
            raise ValueError(f'{kind}: missing required fields')
        if kind == 'usd_brl_rates':
            datetime.strptime(row['data'], '%d/%m/%Y')
            try:
                value = Decimal(str(row['valor']).replace(',', '.'))
            except InvalidOperation as exc:
                raise ValueError('Invalid SGS value') from exc
            if not value.is_finite() or value <= 0: raise ValueError('Invalid SGS value')
        elif kind == 'holidays':
            datetime.strptime(row['date'], '%Y-%m-%d')
            if row['countryCode'] != 'BR' or not isinstance(row['types'], list):
                raise ValueError('Invalid Brazilian holiday')
        elif not isinstance(row['regiao'], dict) or 'nome' not in row['regiao']:
            raise ValueError('Invalid IBGE region')
    return records

def fetch_all(output_dir=None, session=None):
    output_dir = Path(output_dir or LANDING_DIR / 'api')
    output_dir.mkdir(parents=True, exist_ok=True)
    owns_session = session is None
    session = session or requests.Session()
    if owns_session:
        retry = Retry(total=3, backoff_factor=1, status_forcelist=[429,500,502,503,504], allowed_methods=['GET'])
        session.mount('https://', HTTPAdapter(max_retries=retry))
        session.headers.update({'User-Agent':'CommerceLens/1.0 academic DWBI'})
    urls = {
      'states_regions':['https://servicodados.ibge.gov.br/api/v1/localidades/estados'],
      'holidays':[f'https://date.nager.at/api/v3/PublicHolidays/{year}/BR' for year in (2016,2017,2018)],
      'usd_brl_rates':['https://api.bcb.gov.br/dados/serie/bcdata.sgs.10813/dados?formato=json&dataInicial=01/01/2016&dataFinal=31/12/2018']}
    status = {}
    try:
        for kind, endpoints in urls.items():
            temp = output_dir / (kind + '.json.tmp')
            try:
                records = []
                for url in endpoints:
                    response = session.get(url, timeout=(10,60))
                    response.raise_for_status()
                    records.extend(validate_records(kind, response.json()))
                temp.write_text(json.dumps(records, ensure_ascii=False), encoding='utf-8')
                os.replace(temp, output_dir / (kind + '.json'))
                status[kind] = {'status':'success','rows':len(records),'sha256':hashlib.sha256((output_dir/(kind+'.json')).read_bytes()).hexdigest(),'fetched_utc':datetime.now(timezone.utc).isoformat()}
                log.info('%s: %d records saved', kind, len(records))
            except (requests.RequestException, ValueError, TypeError, InvalidOperation, OSError):
                log.exception('%s failed; previous snapshot retained', kind)
                temp.unlink(missing_ok=True)
                status[kind] = {'status':'failed'}
        (output_dir/'fetch_status.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
    finally:
        if owns_session: session.close()
    return status
if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    raise SystemExit(0 if all(s['status']=='success' for s in fetch_all().values()) else 1)
