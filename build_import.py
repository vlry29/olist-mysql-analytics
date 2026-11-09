from pathlib import Path
import csv, json, re, shutil, zipfile
from decimal import Decimal
from datetime import datetime
import argparse
parser=argparse.ArgumentParser(description='Build a MySQL import from the five original Olist CSV files; Python standard library only.')
parser.add_argument('--data-dir', required=True, type=Path)
parser.add_argument('--output-dir', type=Path, default=Path('generated'))
args=parser.parse_args()
src=args.data_dir
out=args.output_dir
out.mkdir(parents=True, exist_ok=True)
files={'customers':'olist_customers_dataset.csv','products':'olist_products_dataset.csv','category_translation':'product_category_name_translation.csv','orders':'olist_orders_dataset.csv','order_items':'olist_order_items_dataset.csv'}
keys={'customers':['customer_id'],'products':['product_id'],'category_translation':['product_category_name'],'orders':['order_id'],'order_items':['order_id','order_item_id']}
ints={'order_item_id','product_name_lenght','product_description_lenght','product_photos_qty','product_weight_g','product_length_cm','product_height_cm','product_width_cm'}
fks={'orders':['FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`)'],'order_items':['FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)','FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`)']}
def typ(c):
 if c in ints: return 'INT'
 if c in ('price','freight_value'):return 'DECIMAL(12,2)'
 if 'date' in c or 'timestamp' in c or c=='order_approved_at':return 'DATETIME'
 if c.endswith('_id'):return 'CHAR(32)'
 if c=='customer_state':return 'CHAR(2)'
 if c=='customer_zip_code_prefix':return 'VARCHAR(5)'
 return 'VARCHAR(255)'
def literal(v,t):
 if v=='':return 'NULL'
 if t=='INT':
  d=Decimal(v);assert d==int(d);return str(int(d))
 if t.startswith('DECIMAL'):
  d=Decimal(v);assert d==d.quantize(Decimal('.01')) and abs(d)<10**10;return format(d,'.2f')
 if t=='DATETIME':datetime.fromisoformat(v)
 else:
  maxlen=int(re.search(r'\((\d+)\)',t).group(1));assert len(v)<=maxlen
 # Hex literals decoded explicitly; independent of SQL quote/backslash modes.
 return "CONVERT(X'"+v.encode('utf-8').hex()+"' USING utf8mb4)"
rows={}; ddl=[]; headers={}; stats={}
for table,name in files.items():
 with (src/name).open(encoding='utf-8-sig',newline='') as f:
  reader=csv.DictReader(f);cols=reader.fieldnames; headers[table]=cols;rows[table]=list(reader)
 defs=['`'+c+'` '+typ(c)+(' NOT NULL' if c in keys[table] else '') for c in cols]
 defs+=['PRIMARY KEY ('+','.join('`'+c+'`' for c in keys[table])+')']+fks.get(table,[])
 if table=='customers':defs+=['KEY idx_customer_unique (`customer_unique_id`)']
 if table=='orders':defs+=['KEY idx_purchase (`order_purchase_timestamp`)']
 ddl+=['CREATE TABLE `'+table+'` (\n  '+',\n  '.join(defs)+'\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;']
 stats[table]=len(rows[table])
expected={'customers':99441,'orders':99441,'order_items':112650,'products':32951,'category_translation':71}
if stats != expected: raise ValueError(f'Unexpected source row counts: {stats}')
prefix='-- Olist. MySQL 8.0+ / 8.4. Fresh schema only. Stop on any import error.\nCREATE DATABASE `olist_analytics` CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;\nUSE `olist_analytics`;\nSET NAMES utf8mb4;\n'
with (out/'olist_mysql.sql').open('w',encoding='utf-8') as f:
 f.write(prefix+'\n\n'.join(ddl)+'\nSTART TRANSACTION;\n')
 for table,data in rows.items():
  cols=headers[table]
  for start in range(0,len(data),200):
   statement='INSERT INTO `'+table+'` ('+','.join('`'+c+'`' for c in cols)+') VALUES\n'+',\n'.join('('+','.join(literal(row[c],typ(c)) for c in cols)+')' for row in data[start:start+200])+';\n'
   assert len(statement.encode())<1024*1024
   f.write(statement)
 f.write('COMMIT;\n')
(out/'schema_mysql.sql').write_text('-- Reference only. Already included in olist_mysql.sql.\n'+'\n\n'.join(ddl),encoding='utf-8')

print('Generated:', out/'olist_mysql.sql')
print('Rows:', stats)
