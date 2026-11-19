"""Profile raw files without modifying them; write JSON for repeatable comparison."""
import json
import pandas as pd
from config import RAW_DIR, REPORT_DIR
from sources import FILES, KEYS, read_source

def profile(raw_dir=RAW_DIR, output_dir=REPORT_DIR):
    result = {}
    for name in FILES:
        frame = read_source(name, raw_dir)
        clean = frame.replace('', pd.NA)
        record = {'rows':len(frame), 'columns':list(frame.columns),
                  'duplicate_rows':int(frame.duplicated().sum()),
                  'duplicate_keys':int(frame.duplicated(KEYS[name]).sum()) if name in KEYS else None,
                  'null_percent':(clean.isna().mean()*100).round(4).to_dict(),
                  'dtypes':frame.dtypes.astype(str).to_dict(), 'ranges':{}}
        for column in frame.columns:
            if any(t in column for t in ['timestamp','_date','_at']):
                values=pd.to_datetime(clean[column],errors='coerce')
                record['ranges'][column]={'min':str(values.min()),'max':str(values.max()),
                  'failed_conversions':int((clean[column].notna() & values.isna()).sum())}
            elif column in ['price','freight_value','payment_value','review_score','geolocation_lat','geolocation_lng','order_item_id','payment_sequential','payment_installments'] or any(column.endswith(t) for t in ['_lenght','_qty','_g','_cm']):
                values=pd.to_numeric(clean[column],errors='coerce')
                record['ranges'][column]={'min':float(values.min()),'max':float(values.max()),
                  'failed_conversions':int((clean[column].notna() & values.isna()).sum())}
            elif column in ['order_status','payment_type','customer_state','seller_state']:
                record.setdefault('categories',{})[column]=sorted(frame[column].unique().tolist())
        allowed = {
          'order_status': {'created','approved','invoiced','processing','shipped','delivered','unavailable','canceled'},
          'payment_type': {'credit_card','boleto','voucher','debit_card','not_defined'},
          'customer_state': set('AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO'.split()),
          'seller_state': set('AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO'.split())}
        record['unexpected_categories']={c:sorted(set(values)-allowed[c]) for c,values in record.get('categories',{}).items()}
        result[name]=record
    output_dir.mkdir(parents=True,exist_ok=True)
    (output_dir/'profile.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result
if __name__ == '__main__':
    print(json.dumps({k:v['rows'] for k,v in profile().items()},indent=2))
