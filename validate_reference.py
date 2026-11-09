import sqlglot,sqlite3,json
from pathlib import Path
base=Path(__file__).resolve().parents[1]
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--sqlite-db', required=True)
args=parser.parse_args()
con=sqlite3.connect(f'file:{Path(args.sqlite_db).resolve()}?mode=ro', uri=True)
report=[]
for n,q in enumerate(sqlglot.parse((base/'sql/02_analysis.sql').read_text(),read='mysql')):
 if q is None or q.key in ('use','semicolon'): continue
 try:
  translated=q.sql(dialect='sqlite')
  translated=translated.replace('TIMESTAMPDIFF(second_purchase, first_purchase, SECOND)', '(ROUND((julianday(second_purchase) - julianday(first_purchase)) * 86400))')
  translated=translated.replace('TIMESTAMPDIFF(m.month_start, s.cohort_month, MONTH)', "((CAST(strftime('%Y',m.month_start) AS INT)-CAST(strftime('%Y',s.cohort_month) AS INT))*12+CAST(strftime('%m',m.month_start) AS INT)-CAST(strftime('%m',s.cohort_month) AS INT))")
  translated=translated.replace("CAST('2018-08-01' AS DATE)", "DATE('2018-08-01')")
  import re
  translated=re.sub(r"CAST\((STRFTIME\([^;]*?\)) AS DATE\)", r"DATE(\1)", translated)
  cur=con.execute(translated); names=[d[0] for d in cur.description]; rows=cur.fetchall()
  report.append({'task':n,'rows':len(rows),'columns':names,'preview':rows[:3]})
  if n not in (9,14,16,17):
   (base/f'results/task_{n:02}.json').write_text(json.dumps([dict(zip(names,row)) for row in rows],ensure_ascii=False,indent=2))
 except Exception as e:
  print('FAILED',n,str(e),translated); raise
(base/'results/validation.json').write_text(json.dumps({'method':'MySQL SQL parsed with sqlglot; translated to SQLite and run on the same source data. Not a MySQL server execution test.','queries':report},ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
