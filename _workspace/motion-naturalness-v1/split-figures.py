"""Separate original RGBA figures, including parts crossing nominal grid cells.
No drawing, warping or pose synthesis. Uses foreground connected regions.
"""
import numpy as np
from PIL import Image

def split_figures(image, columns, rows):
 pixels=np.asarray(image.convert('RGBA'));count=columns*rows
 mask=pixels[:,:,3]>=32;runs=[];parents=[];previous=[]
 def root(i):
  while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
  return i
 for y,row in enumerate(mask):
  edges=np.flatnonzero(np.diff(np.r_[False,row,False]));current=[]
  for left,right in zip(edges[::2],edges[1::2]):
   i=len(runs);parents.append(i);runs.append((y,int(left),int(right)));current.append(i)
   for j in previous:
    _,pl,pr=runs[j]
    if pr>=left and pl<=right:parents[root(j)]=root(i)
  previous=current
 regions={}
 for i,(y,left,right) in enumerate(runs):
  r=regions.setdefault(root(i),{'runs':[],'area':0,'box':[image.width,image.height,0,0]})
  r['runs'].append((y,left,right));r['area']+=right-left;b=r['box']
  b[:]=[min(b[0],left),min(b[1],y),max(b[2],right),max(b[3],y+1)]
 major=sorted((r for r in regions.values() if r['area']>=image.width*image.height/count*.025),key=lambda r:r['area'],reverse=True)
 if len(major)<count or major[count-1]['area']<major[0]['area']*.15:raise ValueError(f'Expected {count} complete figures; got {len(major)} primary regions')
 ordered=sorted(major[:count],key=lambda r:(r['box'][1]+r['box'][3])/2)
 primary=[]
 for row in range(rows):primary+=sorted(ordered[row*columns:(row+1)*columns],key=lambda r:(r['box'][0]+r['box'][2])/2)
 groups=[[r] for r in primary];unused=[]
 def distance(a,b):return max(a[0]-b[2],b[0]-a[2],0)+max(a[1]-b[3],b[1]-a[3],0)
 for r in regions.values():
  if any(r is p for p in primary) or r['area']<12:continue
  nearest=min(range(count),key=lambda i:distance(r['box'],primary[i]['box']))
  if distance(r['box'],primary[nearest]['box'])<=min(image.width/columns,image.height/rows)/8:groups[nearest].append(r)
  else:unused.append({'area':r['area'],'box':r['box']})
 if any(r['area']>image.width*image.height/count*.02 for r in unused):raise ValueError(f'Unassigned significant parts: {unused}')
 result=[]
 for i,items in enumerate(groups):
  b=[min(r['box'][0] for r in items),min(r['box'][1] for r in items),max(r['box'][2] for r in items),max(r['box'][3] for r in items)]
  if b[2]-b[0]>image.width/columns*1.8 or b[3]-b[1]>image.height/rows*1.7:raise ValueError(f'Connected figures at {i}: {b}')
  crop=np.zeros((b[3]-b[1],b[2]-b[0],4),dtype=np.uint8)
  for r in items:
   for y,left,right in r['runs']:crop[y-b[1],left-b[0]:right-b[0]]=pixels[y,left:right]
  result.append((Image.fromarray(crop),b))
 return result,unused
