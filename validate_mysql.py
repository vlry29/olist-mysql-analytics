"""Execute the supplied read-only analytical SQL against the user's MySQL."""
import argparse
import getpass
import json
import re
from pathlib import Path
import mysql.connector

parser = argparse.ArgumentParser()
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', default=3306, type=int)
parser.add_argument('--user', default='root')
args = parser.parse_args()
base = Path(__file__).resolve().parents[1]
# The maintained analysis contains no semicolons inside string literals.
sql = re.sub(r'--[^\n]*', '', (base/'sql/02_analysis.sql').read_text())
statements = [x.strip() for x in sql.split(';') if x.strip()]
con = mysql.connector.connect(host=args.host, port=args.port, user=args.user,
                              password=getpass.getpass('MySQL password: '),
                              database='olist_analytics')
report = []
results = {}
try:
    cur = con.cursor()
    task = 0
    for statement in statements:
        cur.execute(statement)
        if not cur.with_rows:
            continue
        task += 1
        rows = cur.fetchall()
        results[task] = rows
        report.append({'task': task, 'row_count': len(rows),
                       'columns': list(cur.column_names), 'preview': rows[:3]})
    assert task == 19
    assert results[1][0][0] == 99441
    assert results[6][0] == (99441, 99441, 96096)
    assert results[7][0][0] == 610
    assert results[11][0][0] == 96478
    assert str(results[11][0][1]) == '13221498.11'
    assert float(results[11][0][2]) == 137.04
    assert results[15][0][0:2] == (93358, 2801)
    assert len(results[14]) == len(results[17]) == 2801
    assert all(r[4] <= r[3] and 0 <= float(r[5]) <= 100 for r in results[18])
    assert all(float(r[5]) == 100 for r in results[18] if r[2] == 0)
    assert all(str(r[1]) < '2018-08-01' for r in results[18])
    assert sum(r[2] for r in results[19]) == 625
    (base/'mysql_validation.json').write_text(json.dumps(
        {'status': 'passed', 'server_version': con.get_server_info(), 'queries': report},
        ensure_ascii=False, indent=2, default=str))
    print('PASS: 19 analytical queries and key result checks. mysql_validation.json saved.')
finally:
    con.close()
