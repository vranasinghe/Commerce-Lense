"""Original source schemas and explicitly mapped SSIS-compatible Bronze names."""
import json
from config import ROOT
SCHEMAS = json.loads((ROOT / 'docs/baseline/sources.json').read_text())
FILES = {
 'customers': 'olist_customers_dataset.csv', 'orders': 'olist_orders_dataset.csv',
 'order_items': 'olist_order_items_dataset.csv', 'products': 'olist_products_dataset.csv',
 'sellers': 'olist_sellers_dataset.csv', 'order_payments': 'olist_order_payments_dataset.csv',
 'order_reviews': 'olist_order_reviews_dataset.csv', 'geolocation': 'olist_geolocation_dataset.csv',
 'category_translation': 'product_category_name_translation.csv'}
KEYS = {'customers':['customer_id'], 'orders':['order_id'], 'order_items':['order_id','order_item_id'],
 'products':['product_id'], 'sellers':['seller_id'], 'order_payments':['order_id','payment_sequential'],
 'order_reviews':['review_id','order_id'], 'category_translation':['product_category_name']}
COPIES = {'orders': SCHEMAS[FILES['orders']]['columns'], 'order_items':['order_id','product_id','seller_id'],
 'products':['product_id','product_category_name'], 'sellers':['seller_id','seller_city','seller_state'],
 'order_payments':['order_id'], 'order_reviews':['review_id','order_id']}
def bronze_table(name):
 return 'bronze_landing_geolocation' if name == 'geolocation' else 'bronze_' + name
def bronze_column(name, column):
 if name == 'geolocation': return '"' + column + '"'
 return 'Copy of ' + column if column in COPIES.get(name,[]) else column

def read_source(name, raw_dir):
 import pandas as pd
 path = raw_dir / FILES[name]
 frame = pd.read_csv(path, dtype=str, keep_default_na=False, encoding='utf-8-sig')
 expected = SCHEMAS[FILES[name]]['columns']
 if list(frame.columns) != expected:
  raise ValueError(f'{path.name}: schema differs; expected {expected}, got {list(frame.columns)}')
 for column in sorted(set(KEYS.get(name, [])) | {c for c in frame.columns if c.endswith('_id')}):
  if not frame[column].str.fullmatch(r'[0-9a-f]{32}' if column.endswith('_id') and column != 'order_item_id' else r'.+').all():
   raise ValueError(f'{path.name}: invalid or empty key {column}')
 if name in KEYS and frame.duplicated(KEYS[name]).any():
  raise ValueError(f'{path.name}: duplicate business key {KEYS[name]}')
 return frame
