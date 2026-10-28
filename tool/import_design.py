"""Convert captured Figma design context to native Flutter layer data.

Only captured high-fidelity frames are imported. No full-screen renders are
used as application assets. Run from the project root after adding references.
"""
import copy
import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.root = {"tag": "root", "children": []}
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = {"tag": tag, "attrs": dict(attrs), "children": []}
        self.stack[-1]["children"].append(node)
        if tag not in ("img", "br", "input"):
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in ("img", "br", "input"):
            self.stack.pop()

    def handle_endtag(self, tag):
        if len(self.stack) > 1:
            self.stack.pop()

    def handle_data(self, data):
        if data.strip():
            self.stack[-1]["children"].append(data.strip())


def parse(code):
    code = re.sub(r'className=\{className \|\| "([^"]+)"\}', r'className="\1"', code)
    code = re.sub(r'style=\{\{.*?\}\}', '', code, flags=re.S)
    code = re.sub(r'\{`([^`]*)`\}', lambda m: html.escape(m[1]), code)
    code = re.sub(r'src=\{(\w+)\}', r'src="\1"', code)
    p = Parser()
    p.feed(code)
    return p.root['children'][0]


def val(c, key):
    m = re.search(r'(?:^| )' + re.escape(key) + r'-\[([^\]]+)\]', c)
    return m[1] if m else None


def length(v, size, default=0):
    if v is None:
        return default
    if v.endswith('%'):
        return float(v[:-1]) * size / 100
    return float(v.removesuffix('px'))


def color(v):
    if not v:
        return None
    if v.startswith('#'):
        return v
    if v.startswith('rgba('):
        nums = v[5:-1].split(',')
        return '#%02x%02x%02x%02x' % (round(float(nums[3])*255), *map(int, nums[:3]))
    return None


manifest = {}
scenes = {}
for path in sorted((ROOT / 'design/reference').glob('*.txt')):
    code = path.read_text().split('SUPER CRITICAL:')[0]
    if 'export default function' not in code:
        continue
    prefix = re.search(r'const assetPathPrefix = "([^"]+)"', code)[1]
    assets = {}
    for name, filename in re.findall(r'const (\w+) = `\$\{assetPathPrefix\}/([^`]+)`', code):
        local = 'assets/figma/' + filename
        assets[name] = local
        manifest[local] = prefix + '/' + filename
    functions = {}
    for match in re.finditer(r'(?:export default )?function (\w+)\([^\n]*\) \{\s*return \(\s*([\s\S]*?)\s*\);\s*\}', code):
        functions[match[1].lower()] = parse(match[2])
    main = re.search(r'export default function (\w+)', code)[1].lower()
    tree = functions[main]
    layers = []

    def walk(n, box, inherited=None, clip=None):
        if isinstance(n, str):
            return
        n = copy.deepcopy(n)
        a = n.get('attrs', {})
        if n['tag'] in functions:
            replacement = copy.deepcopy(functions[n['tag']])
            replacement['attrs']['classname'] = a.get('classname', '')
            n = replacement
            a = n['attrs']
        c = a.get('classname', '')
        px, py, pw, ph = box
        inset = val(c, 'inset')
        ins = [0, 0, 0, 0]
        if inset:
            bits = inset.split('_')
            bits = bits*4 if len(bits)==1 else bits*2 if len(bits)==2 else bits
            ins = [length(v, ph if i % 2 == 0 else pw) for i, v in enumerate(bits)]
        x = px + length(val(c, 'left'), pw, ins[3])
        y = py + length(val(c, 'top'), ph, ins[0])
        size = val(c, 'size')
        w = length(val(c, 'w') or size, pw, pw-ins[1]-ins[3])
        h = length(val(c, 'h') or size, ph, ph-ins[0]-ins[2])
        # Rotated bars use a fixed outer frame; their visual bounds are that frame.
        if 'rotate-90' in c:
            return rotated(n, box, inherited, clip)
        radius = length(val(c, 'rounded'), min(w,h)) if val(c,'rounded') not in (None,'inherit') else 0
        bg = color(val(c, 'bg')) or ('#ffffff' if 'bg-white' in c else None)
        border = color(val(c, 'border')) or ('#000000' if re.search(r'(?:^| )border(?: |$)', c) else None)
        style = dict(inherited or {'fontSize':16, 'color':'#000000', 'weight':400, 'font':'Inter'})
        ts = val(c, 'text')
        # Color and size may both appear as arbitrary text classes.
        for t in re.findall(r'(?:^| )text-\[([^\]]+)\]', c):
            if t.endswith('px'): style['fontSize'] = length(t,0)
            elif color(t): style['color'] = color(t)
        if 'text-white' in c: style['color']='#ffffff'
        if 'text-black' in c: style['color']='#000000'
        for name, weight in [('light',300),('normal',400),('medium',500),('semibold',600),('bold',700)]:
            if 'font-'+name in c: style['weight']=weight
        if 'Instrument_Sans' in c: style['font']='Instrument Sans'
        if re.search(r'(?:^| )italic(?: |$)',c): style['italic']=True
        base = {'x':x,'y':y,'w':w,'h':h,'id':a.get('data-node-id',''),'name':a.get('data-name','')}
        if bg or border or 'bg-gradient' in c:
            layer = dict(base, type='box', radius=radius)
            if bg: layer['color']=bg
            if border: layer['border']=border
            if 'shadow-[' in c: layer['shadow']=True
            if 'bg-gradient' in c:
                layer['gradient']=[color(val(c,'from')),color(val(c,'to'))]
                layer['reverse']='bg-gradient-to-l' in c
            layers.append(layer)
        if n['tag']=='img':
            layer=dict(base,type='image',asset=assets[a['src']],radius=radius,cover='object-cover' in c)
            if clip: layer['clip']=clip
            layers.append(layer)
            return
        # Text and rich text remain native selectable/accessibility-aware widgets.
        if n['tag'] in ('p','span') or (n['tag']=='a' and any(isinstance(k,str) for k in n['children'])):
            def content(node):
                return node if isinstance(node,str) else ''.join(content(k) for k in node['children'])
            layers.append(dict(base,type='text',text=content(n),**style))
            return
        nextclip = {'x':x,'y':y,'w':w,'h':h,'radius':radius} if 'overflow-hidden' in c else clip
        for child in n['children']:
            walk(child,(x,y,w,h),style,nextclip)

    def rotated(n, box, inherited, clip):
        # Each rotation in these captured frames is a decorative chart bar.
        child = n['children'][0]
        child['attrs']['classname'] = re.sub(r'(?:w|h)-\[[^\]]+\]', '', child['attrs'].get('classname',''))
        walk(child,box,inherited,clip)

    walk(tree,(0,0,440,956))
    # The splash uses mixed-size rich text; preserve its two visual lines.
    if path.stem=='211_945':
        layers=[l for l in layers if not(l['type']=='text' and l['y']==450)]
        layers += [dict(type='text',id='brand',x=147,y=459,w=170,h=49,text='FinTrust',fontSize=40,color='#0f172a',weight=500,font='Inter',brand=True),dict(type='text',id='tagline',x=149,y=507,w=180,h=34,text='Digital Bank',fontSize=26,color='#000000',weight=500,font='Inter')]
    layers = [l for kind in ('box', 'image', 'text') for l in layers if l['type'] == kind]
    scenes[path.stem.replace('_',':')]={'name':tree['attrs']['data-name'],'layers':layers}

(ROOT/'assets/design.json').write_text(json.dumps(scenes,indent=2))
(ROOT/'design/asset_manifest.json').write_text(json.dumps(manifest,indent=2))
print(f'Imported {len(scenes)} screens, {len(manifest)} original assets')
