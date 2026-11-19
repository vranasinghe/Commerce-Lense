"""Independent raw-data oracle: exact cents, join cardinality, order-weighted reviews."""
import json
from decimal import Decimal
import pandas as pd
from config import RAW_DIR, REPORT_DIR
from sources import read_source

def cents(series):
    return series.map(lambda x:int(Decimal(x)*100))

def reconcile(raw_dir=RAW_DIR,output_dir=REPORT_DIR):
    names=['orders','order_items','order_payments','order_reviews','customers','products','sellers']
    frames={n:read_source(n,raw_dir) for n in names}
    orders,items,payments,reviews=[frames[n] for n in names[:4]]
    joined=items.merge(payments[['order_id','payment_sequential']],on='order_id',how='left').merge(reviews[['order_id','review_id']],on='order_id',how='left')
    latest=reviews.sort_values(['review_answer_timestamp','review_creation_date','review_id'],ascending=False,kind='stable').drop_duplicates('order_id')
    order_data=orders.merge(latest[['order_id','review_score']],on='order_id',how='left',validate='one_to_one')
    merchandise=cents(items.price).sum();freight=cents(items.freight_value).sum();paid=cents(payments.payment_value).sum()
    orphans={}
    for child,col,parent in [('order_items','order_id','orders'),('order_payments','order_id','orders'),('order_reviews','order_id','orders'),('orders','customer_id','customers'),('order_items','product_id','products'),('order_items','seller_id','sellers')]:
        orphans[child+'.'+col]=int((~frames[child][col].isin(frames[parent][col])).sum())
    if any(orphans.values()):raise ValueError(orphans)
    counts=frames['customers'].customer_unique_id.value_counts()
    item_totals=items.assign(gross=cents(items.price)+cents(items.freight_value)).groupby('order_id').gross.sum()
    payment_totals=payments.assign(paid=cents(payments.payment_value)).groupby('order_id').paid.sum()
    differences=orders[['order_id','order_status']].merge(item_totals,on='order_id',how='left',validate='one_to_one').merge(payment_totals,on='order_id',how='left',validate='one_to_one')
    differences['classification']='matched'
    differences.loc[differences.gross.isna(),'classification']='no_items'
    differences.loc[differences.paid.isna(),'classification']='no_payment'
    both=differences.gross.notna() & differences.paid.notna()
    differences.loc[both & differences.paid.gt(differences.gross),'classification']='payment_above_gross'
    differences.loc[both & differences.paid.lt(differences.gross),'classification']='payment_below_gross'
    differences['difference_cents']=differences.paid.fillna(0)-differences.gross.fillna(0)
    diagnostic=[]
    for (status,kind),group in differences.groupby(['order_status','classification']):
        diagnostic.append({'order_status':status,'classification':kind,'orders':len(group),'difference_brl':str(Decimal(int(group.difference_cents.sum()))/100)})
    data={'scope':'All source order statuses; BRL, no currency conversion',
      'orders':len(orders),'items':len(items),'payments':len(payments),'reviews':len(reviews),
      'merchandise_brl':str(Decimal(int(merchandise))/100),'freight_brl':str(Decimal(int(freight))/100),
      'gross_brl':str(Decimal(int(merchandise+freight))/100),'payments_brl':str(Decimal(int(paid))/100),
      'payment_minus_gross_brl':str(Decimal(int(paid-merchandise-freight))/100),
      'original_join_rows':len(joined),'original_join_merchandise_brl':str(Decimal(int(cents(joined.price).sum()))/100),
      'unique_customers':int(counts.size),'repeat_customers_all_statuses':int((counts>1).sum()),
      'orders_with_reviews':int(order_data.review_score.notna().sum()),
      'latest_review_average':float(pd.to_numeric(order_data.review_score).mean()),
      'satisfied_reviewed_orders':int(pd.to_numeric(order_data.review_score).ge(4).sum()),
      'order_status_counts':orders.order_status.value_counts().to_dict(),'payment_difference_analysis':diagnostic,'orphans':orphans}
    output_dir.mkdir(parents=True,exist_ok=True)
    (output_dir/'source-reconciliation.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    return data
if __name__=='__main__':print(json.dumps(reconcile(),indent=2))
