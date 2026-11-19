import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock
import requests
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
from config import ROOT, RAW_DIR
from sources import FILES, SCHEMAS, read_source
from fetch_apis import fetch_all, validate_records
from prepare_local_files import prepare
from reconcile_sources import reconcile

class SourceTests(unittest.TestCase):
    def test_all_sources_and_schemas(self):
        for name,filename in FILES.items():
            with self.subTest(source=name):
                data=read_source(name,RAW_DIR)
                self.assertEqual(len(data),SCHEMAS[filename]['rows'])
    def test_preserved_original_assets(self):
        manifest=json.loads((ROOT/'docs/baseline/manifest.json').read_text())
        for rel,entry in manifest.items():
            if rel.endswith(('.csv','.pbix','.dtsx','.ispac')):
                self.assertEqual(hashlib.sha256((ROOT/rel).read_bytes()).hexdigest(),entry['sha256'],rel)
    def test_reject_schema_drift(self):
        with tempfile.TemporaryDirectory() as folder:
            Path(folder,FILES['orders']).write_text('unexpected\nvalue\n')
            with self.assertRaises(ValueError):read_source('orders',Path(folder))
    def test_reconciliation(self):
        with tempfile.TemporaryDirectory() as folder:
            result=reconcile(output_dir=Path(folder))
            self.assertTrue(all(v==0 for v in result['orphans'].values()))
            self.assertGreater(result['original_join_rows'],result['items'])
            self.assertEqual(result['merchandise_brl'],'13591643.7')
            self.assertEqual(result['freight_brl'],'2251909.54')
    def test_landing_roundtrip(self):
        import pandas as pd
        with tempfile.TemporaryDirectory() as folder:
            prepare(landing_dir=Path(folder))
            self.assertEqual(len(pd.read_csv(Path(folder)/'sellers/sellers.txt',sep='|',dtype=str)),3095)
            reviews=pd.read_json(Path(folder)/'reviews/reviews.json',lines=True)
            self.assertEqual(len(reviews),99224)
            self.assertEqual(len(pd.read_excel(Path(folder)/'reference/category_translation.xlsx')),71)
            for name,path in [('order_payments','payments/payments.csv'),('geolocation','geolocation/geolocation.csv')]:
                self.assertEqual((Path(folder)/path).read_bytes(),(RAW_DIR/FILES[name]).read_bytes())

class APITests(unittest.TestCase):
    def test_rate_is_single_value(self):
        row={'data':'02/01/2017','valor':'3.25'}
        self.assertEqual(validate_records('usd_brl_rates',[row]),[row])
        for value in ['NaN','-1','missing']:
            with self.subTest(value=value),self.assertRaises(ValueError):
                validate_records('usd_brl_rates',[{'data':'02/01/2017','valor':value}])
    def test_holiday_types_array(self):
        row={'date':'2017-01-01','name':'New year','localName':'Ano novo','countryCode':'BR','types':['Public']}
        validate_records('holidays',[row])
        row['types']='Public'
        with self.assertRaises(ValueError):validate_records('holidays',[row])
    def test_failed_fetch_retains_files_and_reports_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'holidays.json';p.write_text('original')
            session=Mock();session.get.side_effect=requests.Timeout('fixture timeout')
            result=fetch_all(folder,session)
            self.assertEqual(p.read_text(),'original')
            self.assertTrue(all(v['status']=='failed' for v in result.values()))
    def test_partial_holiday_year_does_not_publish_partial_feed(self):
        with tempfile.TemporaryDirectory() as folder:
            session=Mock();response=Mock()
            response.json.return_value=[{'sigla':'SP','nome':'Sao Paulo','regiao':{'nome':'Sudeste'}}]
            holiday=Mock();holiday.json.return_value=[{'date':'2016-01-01','name':'New Year','localName':'Ano Novo','countryCode':'BR','types':['Public']}]
            session.get.side_effect=[response,holiday,requests.Timeout('year missing'),requests.Timeout('rate missing')]
            result=fetch_all(folder,session)
            self.assertEqual(result['states_regions']['status'],'success')
            self.assertFalse((Path(folder)/'holidays.json').exists())
if __name__=='__main__':unittest.main()
