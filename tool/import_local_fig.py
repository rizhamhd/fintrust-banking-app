"""Import the user's local .fig: preserve original geometry, glyphs and links.

Decode canvas.fig first with tool/fig_decoder/decode.cjs. Original vector layers
are exported individually; complete-screen reference renders are never app assets.
"""
import base64, collections, copy, hashlib, html, json, math, struct, subprocess, zipfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1]
DOC=json.loads((ROOT/'design/local/document.json').read_text())
def key(g): return f"{g['sessionID']}:{g['localID']}"
NODES={key(n['guid']):n for n in DOC['nodeChanges']}
CHILDREN=collections.defaultdict(list)
for n in NODES.values():
 if 'parentIndex' in n: CHILDREN[key(n['parentIndex']['guid'])].append(n)
for kids in CHILDREN.values(): kids.sort(key=lambda n:n['parentIndex']['position'])
ARCHIVE=zipfile.ZipFile(ROOT.parent/'Assaighnment.fig')
IMAGES={p.split('/')[-1]:ARCHIVE.read(p) for p in ARCHIVE.namelist() if p.startswith('images/') and not p.endswith('/')}
OUT=ROOT/'assets/local';OUT.mkdir(exist_ok=True)
REF=ROOT/'design/local/reference';REF.mkdir(exist_ok=True)
PATHS={}
def commands(index):
 if str(index) in PATHS:return PATHS[str(index)]
 b=bytes(DOC['blobs'][index]['bytes']); result=[]; i=0
 while i<len(b):
  op=b[i];i+=1; count=[0,2,2,4,6][op]; vals=struct.unpack_from('<'+'f'*count,b,i);i+=4*count
  result.append([op,*[round(v,7) for v in vals]])
 PATHS[str(index)]=result
 return result

def path(index):return ' '.join('ZMLQC'[op]+' '.join(str(x) for x in values) for i,(op,*values) in enumerate(commands(index)) if op != 0 or i != 0)
def rgba(c,opacity=1):
 return '#%02x%02x%02x'%(round(c.get('r',0)*255),round(c.get('g',0)*255),round(c.get('b',0)*255)),c.get('a',1)*opacity

def matrix(t):return [t.get(k,v) for k,v in zip(('m00','m10','m01','m11','m02','m12'),(1,0,0,1,0,0))]
def matrixstr(t):return 'matrix('+','.join(str(v) for v in matrix(t))+')'
def bounds(n):
 a,b,c,d,e,f=matrix(n.get('transform',{}));w=n.get('size',{}).get('x',0);h=n.get('size',{}).get('y',0)
 pts=[(a*x+c*y+e,b*x+d*y+f) for x,y in [(0,0),(w,0),(0,h),(w,h)]]
 xs,ys=zip(*pts);return min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)

def resolved_children(n):
 if n['type']!='INSTANCE':return CHILDREN.get(key(n['guid']),[])
 source=NODES.get(key(n.get('symbolData',{}).get('symbolID',n['guid'])))
 if source is None:return []
 overrides={}
 for group in [n.get('symbolData',{}).get('symbolOverrides',[]),n.get('derivedSymbolData',[])]:
  for o in group:
   ids=o.get('guidPath',{}).get('guids',[])
   if ids: overrides.setdefault(key(ids[-1]),{}).update({k:v for k,v in o.items() if k!='guidPath'})
 def clone(base):
  k=key(base['guid']); item=copy.deepcopy(base); item.update(overrides.get(k,{}))
  item['_children']=[clone(x) for x in CHILDREN.get(k,[])]
  return item
 return [clone(c) for c in CHILDREN.get(key(source['guid']),[])]

def visible(n):return n.get('visible',True) and n.get('opacity',1)>0 and n.get('phase')!='REMOVED'

class Renderer:
 def __init__(self):self.defs=[];self.counter=0
 def uid(self):self.counter+=1;return 'd'+str(self.counter)
 def paint(self,p,n):
  if p.get('visible',True)==False:return 'none',1
  kind=p.get('type'); opacity=p.get('opacity',1)
  if kind=='SOLID':return rgba(p.get('color',{}),opacity)
  if kind=='GRADIENT_LINEAR':
   ident=self.uid();t=p.get('transform',{});a,b,c,d,e,f=matrix(t);det=a*d-b*c
   w=n['size']['x'];h=n['size']['y']
   def inv(x,y):return ((d*(x-e)-c*(y-f))/det*w,(-b*(x-e)+a*(y-f))/det*h)
   x1,y1=inv(0,.5);x2,y2=inv(1,.5)
   stops=''.join(f'<stop offset="{s["position"]}" stop-color="{rgba(s["color"])[0]}" stop-opacity="{rgba(s["color"])[1]}"/>' for s in p['stops'])
   self.defs.append(f'<linearGradient id="{ident}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>')
   return f'url(#{ident})',opacity
  return 'none',1
 def geometry(self,n,field,paintfield):
  out=[];geom=n.get(field,[]); paints=n.get(paintfield,[])
  for shape in geom:
   for p in paints:
    if not p.get('visible',True):continue
    data=path(shape['commandsBlob']);rule='evenodd' if shape.get('windingRule')=='ODD' else 'nonzero'
    if p['type']=='IMAGE':
     ident=self.uid();self.defs.append(f'<clipPath id="{ident}"><path d="{data}" fill-rule="{rule}"/></clipPath>')
     hsh=bytes(p['image']['hash']).hex();blob=IMAGES[hsh]
     mime='image/png' if blob[:8]==b'\x89PNG\r\n\x1a\n' else 'image/jpeg'
     a,b,c,d,e,f=matrix(p.get('transform',{}));det=a*d-b*c;w=n['size']['x'];h=n['size']['y']
     trans=f'matrix({d/det*w},{-b/det*h},{-c/det*w},{a/det*h},{(c*f-d*e)/det*w},{(b*e-a*f)/det*h})'
     out.append(f'<g clip-path="url(#{ident})"><image width="1" height="1" preserveAspectRatio="none" transform="{trans}" href="data:{mime};base64,{base64.b64encode(blob).decode()}"/></g>')
    else:
     fill,op=self.paint(p,n)
     item=f'<path d="{data}" fill="{fill}" fill-opacity="{op}" fill-rule="{rule}"/>'
     if field=='strokeGeometry' and n.get('strokeAlign') in ('INSIDE','OUTSIDE'):
      ident=self.uid();fills=''.join(f'<path d="{path(g["commandsBlob"])}" fill="white"/>' for g in n.get('fillGeometry',[]))
      if n['strokeAlign']=='INSIDE':
       self.defs.append(f'<clipPath id="{ident}">{fills}</clipPath>'); item=f'<g clip-path="url(#{ident})">{item}</g>'
      else:
       self.defs.append(f'<mask id="{ident}" x="-100%" y="-100%" width="300%" height="300%"><rect x="-10000" y="-10000" width="20000" height="20000" fill="white"/>{fills.replace("white","black")}</mask>');item=f'<g mask="url(#{ident})">{item}</g>'
     out.append(item)
  return ''.join(out)
 def glyphs(self,n):
  out=[]
  for g in textglyphs(n):
   out.append(f'<path d="{path(g["path"])}" fill="{g["color"]}" transform="translate({g["x"]},{g["y"]}) scale({g["size"]}, {-g["size"]})"/>')
  return ''.join(out)
 def node(self,n,transform=True):
  if not visible(n):return ''
  if n['type']=='TEXT':content=self.glyphs(n)
  else:
   content=self.geometry(n,'fillGeometry','fillPaints')+self.geometry(n,'strokeGeometry','strokePaints')
   kids=n.get('_children') if '_children' in n else resolved_children(n)
   mask_id=None
   for c in kids:
    if c.get('isMask') or c.get('mask'):
     mask_id=self.uid(); self.defs.append(f'<mask id="{mask_id}" mask-type="{"luminance" if c.get("maskType")=="LUMINANCE" else "alpha"}">{self.node(c)}</mask>')
    else:
     child=self.node(c)
     content+=f'<g mask="url(#{mask_id})">{child}</g>' if mask_id else child
  effects=[e for e in n.get('effects',[]) if e.get('visible',True)]
  for e in effects:
   if e['type'] not in ('DROP_SHADOW','INNER_SHADOW'):continue
   ident=self.uid();col,alpha=rgba(e['color']);offset=e.get('offset',{});dx=offset.get('x',0);dy=offset.get('y',0);sigma=e.get('radius',0)/2
   shape=''.join(f'<path d="{path(g["commandsBlob"])}" fill="white"/>' for g in n.get('fillGeometry',[]))
   if not shape:continue
   if e['type']=='DROP_SHADOW':
    self.defs.append(f'<filter id="{ident}" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="{sigma}"/><feOffset dx="{dx}" dy="{dy}"/><feFlood flood-color="{col}" flood-opacity="{alpha}"/><feComposite in2="SourceAlpha" operator="in"/></filter>')
    # Blur+offset mask, then remove the object's interior (transparent cards).
    blur=self.uid();mask=self.uid()
    self.defs.append(f'<filter id="{blur}" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="{sigma}"/><feOffset dx="{dx}" dy="{dy}"/></filter>')
    self.defs.append(f'<mask id="{mask}" x="-100%" y="-100%" width="300%" height="300%"><g filter="url(#{blur})">{shape}</g>{shape.replace("white","black")}</mask>')
    shadow=f'<rect x="-1000" y="-1000" width="3000" height="3000" fill="{col}" opacity="{alpha}" mask="url(#{mask})"/>'
    content=shadow+content
   else:
    self.defs.append(f'<filter id="{ident}" x="-100%" y="-100%" width="300%" height="300%"><feOffset in="SourceAlpha" dx="{dx}" dy="{dy}"/><feGaussianBlur stdDeviation="{sigma}" result="shifted"/><feComposite in="SourceAlpha" in2="shifted" operator="out" result="edge"/><feFlood flood-color="{col}" flood-opacity="{alpha}"/><feComposite operator="in" in2="edge"/></filter>')
    content+=f'<g filter="url(#{ident})">{shape}</g>'
  opacity=n.get('opacity',1)
  return f'<g opacity="{opacity}" transform="{matrixstr(n.get("transform",{})) if transform else ""}">{content}</g>'
 def svg(self,content,box):
  x,y,w,h=box
  return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{x} {y} {w} {h}"><defs>{"".join(self.defs)}</defs>{content}</svg>'

def textglyphs(n):
 styles={x['styleID']:x for x in n.get('textData',{}).get('styleOverrideTable',[])};charstyles=n.get('textData',{}).get('characterStyleIDs',[]);out=[]
 for g in n.get('derivedTextData',{}).get('glyphs',[]):
  sid=charstyles[g['firstCharacter']] if g.get('firstCharacter',0)<len(charstyles) else 0
  style=styles.get(sid,{})
  paints=style.get('fillPaints',n.get('fillPaints',[]));p=next((p for p in paints if p.get('visible',True)),{})
  color,opacity=rgba(p.get('color',{}),p.get('opacity',1))
  commands(g['commandsBlob'])
  out.append({'path':g['commandsBlob'],'x':g['position']['x'],'y':g['position']['y'],'size':g.get('fontSize',n.get('fontSize',16)),'color':color,'opacity':opacity})
 return out

frames=[n for n in CHILDREN['211:182'] if n.get('size',{}).get('x')==440 and n['type']=='FRAME']
frames.sort(key=lambda n:n['transform']['m02'])
scenes={};jobs=[];assets=[]
for frame in frames:
 fid=key(frame['guid']);layers=[{'type':'box','id':fid,'x':0,'y':0,'w':440,'h':956,'color':'#ffffff','radius':0}];links=[]
 for n in CHILDREN[fid]:
  if not visible(n):continue
  if key(n['guid']) in {'211:1003','211:1004','211:1005','272:347','272:350'}:continue
  nid=key(n['guid']);x,y,w,h=bounds(n);base={'id':nid,'name':n.get('name',''),'x':x,'y':y,'w':w,'h':h}
  interactions=n.get('prototypeInteractions',[])
  for o in n.get('symbolData',{}).get('symbolOverrides',[]):interactions+=o.get('prototypeInteractions',[])
  for reaction in interactions:
   if reaction.get('isDeleted') or reaction.get('event',{}).get('interactionType')!='ON_CLICK':continue
   for action in reaction.get('actions',[]):
    if 'transitionNodeID' in action:links.append(dict(base,target=key(action['transitionNodeID']),label=n.get('name','')))
  if n['type']=='TEXT':
   font=n.get('fontName',{});style=font.get('style','Regular');paint=next((p for p in n.get('fillPaints',[]) if p.get('visible',True)),{})
   layer=dict(base,type='text',text=n.get('textData',{}).get('characters',''),fontSize=n.get('fontSize',16),color=rgba(paint.get('color',{}))[0],weight=700 if 'Bold' in style else 500 if 'Medium' in style else 300 if 'Light' in style else 400,font=font.get('family','Inter'),italic='Italic' in style,glyphs=textglyphs(n))
   layers.append(layer)
  elif nid in ('256:355','256:356','256:357'):
   # Display only the illustration region of the original supplied pictures.
   # Keep source pixels intact; Flutter crops and contains this region at runtime.
   crops={'256:355':[3,3,440,651],'256:356':[9,2,422,638],'256:357':[18,2,414,661]}
   paint=next(p for p in n['fillPaints'] if p['type']=='IMAGE')
   source=OUT/(nid.replace(':','_')+'_original.png')
   source.write_bytes(IMAGES[bytes(paint['image']['hash']).hex()])
   from PIL import Image
   iw,ih=Image.open(source).size
   layers.append(dict(base,type='image',x=0,y=8,w=440,h=550,asset=str(source.relative_to(ROOT)),sourceRect=crops[nid],sourceSize=[iw,ih]))
  elif w>0 and h>0:
   pad=12 if n.get('effects') else 1
   render=Renderer();body=render.node(n);box=(x-pad,y-pad,w+2*pad,h+2*pad)
   stem=nid.replace(':','_');svg=OUT/(stem+'.svg');png=svg.with_suffix('.png');svg.write_text(render.svg(body,box));jobs.append((svg,png,3))
   layers.append(dict(base,type='image',x=box[0],y=box[1],w=box[2],h=box[3],asset=str(png.relative_to(ROOT)),logicalBounds=[x,y,w,h]))
   assets.append({'id':nid,'screen':fid,'file':str(png.relative_to(ROOT)),'geometry':box})
 scenes[fid]={'name':frame['name'].strip(),'layers':layers,'links':list({(l['id'],l['target']):l for l in links}.values())}
 r=Renderer();body=r.node(frame,transform=False);svg=REF/(fid.replace(':','_')+'.svg');svg.write_text(r.svg(body,(0,0,440,956)));jobs.append((svg,svg.with_suffix('.png'),1))
(ROOT/'assets/design.json').write_text(json.dumps(scenes,separators=(',',':')))
(ROOT/'assets/glyphs.json').write_text(json.dumps(PATHS,separators=(',',':')))
(ROOT/'design/local/asset_manifest.json').write_text(json.dumps(assets,indent=2))

def raster(job):
 svg,png,scale=job
 subprocess.run(['rsvg-convert','--zoom='+str(scale),'--output',str(png),str(svg)],check=True,stderr=subprocess.PIPE)
with ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(raster,jobs))
print(f'Imported {len(scenes)} screens, {len(assets)} original layer assets, {sum(len(v["links"]) for v in scenes.values())} navigation links, {len(PATHS)} original paths')
