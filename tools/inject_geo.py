#!/usr/bin/env python3
"""Insere geo/belgium_geo.json dans html/cloudpage_dashboard.html (entre /*GEO_START*/ et /*GEO_END*/).
Usage : python3 tools/build_geo.py && python3 tools/inject_geo.py"""
import json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
geo = open(os.path.join(ROOT, 'geo', 'belgium_geo.json'), encoding='utf-8').read()
json.loads(geo)
p = os.path.join(ROOT, 'html', 'cloudpage_dashboard.html'); t = open(p, encoding='utf-8').read()
safe = geo.replace('%', '\\u0025').replace('</', '<\\/')     # evite d interferer avec AMPScript (%%) et la balise script
t2 = re.sub(r'/\*GEO_START\*/.*?/\*GEO_END\*/', lambda m: '/*GEO_START*/const GEO = ' + safe + ';/*GEO_END*/', t, flags=re.S)
assert t2 != t or 'const GEO = {' in t
open(p, 'w', encoding='utf-8').write(t2)
print('GEO insere :', len(safe), 'octets ; page :', len(t2), 'octets')
