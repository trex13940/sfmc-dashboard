#!/usr/bin/env python3
"""Genere geo/belgium_geo.json (contours des provinces + points des codes postaux belges, deja projetes pour un SVG).
Sources : GeoNames postal codes BE (CC BY 4.0) et Natural Earth admin-1 (domaine public).
Usage : python3 tools/build_geo.py   (puis python3 tools/inject_geo.py pour l inserer dans html/cloudpage_dashboard.html)"""
import json, urllib.request, zipfile, io, collections, os, re, math
from shapely.geometry import shape
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson"
GN = "https://download.geonames.org/export/zip/BE.zip"
LON0, LAT1, LAT0, K = 2.5, 51.55, 50.6, 400.0          # projection equirectangulaire (1 deg de latitude = 400 unites)
COS = math.cos(math.radians(LAT0))
proj = lambda lon, lat: (round((lon - LON0) * COS * K), round((LAT1 - lat) * K))
PROV = {  # id : (Natural Earth name, nl, fr, en)
 'ANT': ('Antwerp', 'Antwerpen', 'Anvers', 'Antwerp'), 'BRU': ('Brussels', 'Brussel', 'Bruxelles', 'Brussels'),
 'HAI': ('Hainaut', 'Henegouwen', 'Hainaut', 'Hainaut'), 'LIE': ('Liege', 'Luik', 'Liège', 'Liège'),
 'LIM': ('Limburg', 'Limburg', 'Limbourg', 'Limburg'), 'LUX': ('Luxembourg', 'Luxemburg', 'Luxembourg', 'Luxembourg'),
 'NAM': ('Namur', 'Namen', 'Namur', 'Namur'), 'OVL': ('East Flanders', 'Oost-Vlaanderen', 'Flandre-Orientale', 'East Flanders'),
 'VBR': ('Flemish Brabant', 'Vlaams-Brabant', 'Brabant flamand', 'Flemish Brabant'), 'WBR': ('Walloon Brabant', 'Waals-Brabant', 'Brabant wallon', 'Walloon Brabant'),
 'WVL': ('West Flanders', 'West-Vlaanderen', 'Flandre-Occidentale', 'West Flanders')}
def prov_of(admin2):
    a = admin2.lower()
    for key, pid in [('brabant wallon','WBR'),('waals','WBR'),('vlaams','VBR'),('brabant flamand','VBR'),('bruxelles','BRU'),('brussel','BRU'),
                     ('hainaut','HAI'),('henegouwen','HAI'),('namur','NAM'),('namen','NAM'),('liège','LIE'),('luik','LIE'),('liege','LIE'),
                     ('luxemb','LUX'),('oost','OVL'),('orientale','OVL'),('west-v','WVL'),('occidentale','WVL'),('antwerp','ANT'),('anvers','ANT'),('limb','LIM')]:
        if key in a: return pid
    return None
def fetch(u): return urllib.request.urlopen(u, timeout=120).read()
ne = json.loads(fetch(NE))
feats = {f['properties']['name']: f for f in ne['features'] if f['properties'].get('admin') == 'Belgium'}
provinces = []
for pid, (nename, nl, fr, en) in PROV.items():
    g = shape(feats[nename]['geometry']).simplify(0.004, preserve_topology=True)
    polys = [g] if g.geom_type == 'Polygon' else list(g.geoms)
    d = ''
    for p in polys:
        if p.area < 0.0004: continue   # ignore les micro-polygones
        pts = [proj(x, y) for x, y in p.exterior.coords]
        dedup = [pts[0]] + [q for a, q in zip(pts, pts[1:]) if q != a]
        d += 'M' + 'L'.join(f'{x} {y}' for x, y in dedup) + 'Z'
    provinces.append({'id': pid, 'nl': nl, 'fr': fr, 'en': en, 'd': d})
zf = zipfile.ZipFile(io.BytesIO(fetch(GN)))
acc = collections.OrderedDict()
for line in zf.read('BE.txt').decode('utf-8').splitlines():
    c = line.split('\t')
    pc, place, adm2, lat, lon = c[1], c[2], c[5], float(c[9]), float(c[10])
    a = acc.setdefault(pc, {'lat': [], 'lon': [], 'name': place, 'prov': collections.Counter()})
    a['lat'].append(lat); a['lon'].append(lon); a['prov'][prov_of(adm2) or '?'] += 1
postal = {}
for pc, a in acc.items():
    pid = a['prov'].most_common(1)[0][0]
    x, y = proj(sum(a['lon']) / len(a['lon']), sum(a['lat']) / len(a['lat']))
    postal[pc] = [x, y, pid, a['name']]
unk = [k for k, v in postal.items() if v[2] == '?']
out = {'viewBox': [0, 0, round((6.45 - LON0) * COS * K), round((LAT1 - 49.45) * K)], 'provinces': provinces, 'postal': postal,
       'attribution': 'Postal code positions: GeoNames (CC BY 4.0). Province outlines: Natural Earth (public domain).'}
os.makedirs(os.path.join(ROOT, 'geo'), exist_ok=True)
with open(os.path.join(ROOT, 'geo', 'belgium_geo.json'), 'w', encoding='utf-8') as f: json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
print('provinces', len(provinces), '| codes postaux', len(postal), '| sans province', unk[:5], '| taille', os.path.getsize(os.path.join(ROOT, 'geo', 'belgium_geo.json')), 'octets | viewBox', out['viewBox'])
