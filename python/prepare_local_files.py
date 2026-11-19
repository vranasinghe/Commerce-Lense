"""Preserve legacy landing formats. JSON reviews require a JSON parser in SSIS."""
import logging
import shutil
from config import RAW_DIR, LANDING_DIR
from sources import read_source, FILES

def prepare(raw_dir=RAW_DIR, landing_dir=LANDING_DIR):
    frames = {name: read_source(name, raw_dir) for name in ['sellers','order_reviews','category_translation','order_payments','geolocation']}
    for folder in ['sellers','reviews','reference','payments','geolocation','api']:
        (landing_dir / folder).mkdir(parents=True, exist_ok=True)
    frames['sellers'].to_csv(landing_dir/'sellers/sellers.txt', sep='|', index=False)
    # Preserve numeric/null JSON types used by the original preparation script.
    import pandas as pd
    reviews = pd.read_csv(raw_dir/FILES['order_reviews'])
    reviews.to_json(landing_dir/'reviews/reviews.json', orient='records', lines=True, force_ascii=False)
    frames['category_translation'].to_excel(landing_dir/'reference/category_translation.xlsx', index=False)
    for name, dest in [('order_payments','payments/payments.csv'),('geolocation','geolocation/geolocation.csv')]:
        shutil.copyfile(raw_dir/FILES[name], landing_dir/dest)
    logging.info('Prepared landing files at %s', landing_dir)
if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    prepare()
