#!/usr/bin/env python3
"""Insere geo/belgium_geo.json dans html/cloudpage_dashboard.html (entre /*GEO_START*/ et /*GEO_END*/).
Usage : python3 tools/build_geo.py && python3 tools/inject_geo.py"""
import json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = json.load(open(os.path.join(ROOT, 'geo', 'belgium_geo.json'), encoding='utf-8'))
B36 = '0123456789abcdefghijklmnopqrstuvwxyz'
def b36(n):
    s = ''
    while True:
        s = B36[n % 36] + s; n //= 36
        if not n: return s
def enc(path):
    """trace SVG M x y L ... Z -> deltas (zigzag, base 36), sous-traces separees par | : la page reste legere (decodee par le navigateur)"""
    out = []
    for sub in path.split('M')[1:]:
        px = py = 0; toks = []
        for q in sub.rstrip('Z').split('L'):
            x, y = (int(v) for v in q.split(' '))
            for v in (x - px, y - py): toks.append(b36(v << 1 if v >= 0 else ((-v) << 1) - 1))
            px, py = x, y
        out.append(','.join(toks))
    return '|'.join(out)
src['provinces'] = [dict(x, d=enc(x['d'])) for x in src['provinces']]
src['postal'] = {k: v[2] for k, v in src['postal'].items()}   # code postal -> province (les zones par code postal ne sont plus affichees)
geo = json.dumps(src, ensure_ascii=False, separators=(',', ':'))
p = os.path.join(ROOT, 'html', 'cloudpage_dashboard.html'); t = open(p, encoding='utf-8').read()
DEC = "(function(){const un=z=>z%2?-((z+1)/2):z/2,dp=s=>s.split('|').map(u=>{const t=u.split(','),o=[];let x=0,y=0;for(let i=0;i<t.length;i+=2){x+=un(parseInt(t[i],36));y+=un(parseInt(t[i+1],36));o.push(x+' '+y);}return 'M'+o.join('L')+'Z';}).join('');GEO.provinces.forEach(p=>{p.d=dp(p.d);});})();"
safe = geo.replace('%', '\\u0025').replace('</', '<\\/')     # evite d interferer avec AMPScript (%%) et la balise script
t2 = re.sub(r'/\*GEO_START\*/.*?/\*GEO_END\*/', lambda m: '/*GEO_START*/const GEO = ' + safe + ';\n' + DEC + '/*GEO_END*/', t, flags=re.S)
assert t2 != t or 'const GEO = {' in t
open(p, 'w', encoding='utf-8').write(t2)
print('GEO insere :', len(safe), 'octets ; page :', len(t2), 'octets')
