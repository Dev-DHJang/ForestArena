"""Split isolated 4x4 poses by foreground regions instead of cutting a fixed grid."""
import numpy as np
from PIL import Image


def split_regions(image):
    pixels = np.asarray(image).copy()
    pixels[pixels[:,:,3] < 8] = 0
    # Faint model residue can bridge two otherwise separate figures.
    # Use visible alpha for region topology; keep original color/alpha on it.
    mask = pixels[:,:,3] >= 32
    runs, parents, previous = [], [], []

    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False,row,False]))
        current = []
        for left, right in zip(edges[::2],edges[1::2]):
            i = len(runs)
            parents.append(i)
            runs.append((y,int(left),int(right)))
            current.append(i)
            for j in previous:
                _, pl, pr = runs[j]
                if pr >= left and pl <= right:
                    parents[root(j)] = root(i)
        previous = current
    regions = {}
    for i, (y,left,right) in enumerate(runs):
        region = regions.setdefault(root(i),{'runs':[],'area':0,'box':[image.width,image.height,0,0]})
        region['runs'].append((y,left,right))
        region['area'] += right-left
        b = region['box']
        b[:] = [min(b[0],left),min(b[1],y),max(b[2],right),max(b[3],y+1)]
    major = sorted((r for r in regions.values() if r['area'] >= image.width*image.height/16*0.03),key=lambda r:r['area'],reverse=True)
    if len(major)<16 or major[15]['area'] < major[0]['area']*0.15:
        raise ValueError(f'Expected 16 complete isolated poses, found {len(major)} major regions')
    ordered = sorted(major[:16],key=lambda r:(r['box'][1]+r['box'][3])/2)
    primaries = {}
    for row in range(4):
        for column, r in enumerate(sorted(ordered[row*4:row*4+4],key=lambda r:(r['box'][0]+r['box'][2])/2)):
            primaries[row*4+column]=r
    groups = {i:[p] for i,p in primaries.items()}
    for r in regions.values():
        if any(r is p for p in primaries.values()) or r['area']<12:
            continue
        b = r['box']
        def distance(p):
            pb=p['box']
            return max(pb[0]-b[2],b[0]-pb[2],0)+max(pb[1]-b[3],b[1]-pb[3],0)
        nearest=min(primaries,key=lambda i:distance(primaries[i]))
        if distance(primaries[nearest]) <= min(image.size)/32:
            groups[nearest].append(r)
    frames=[]
    for i in range(16):
        items=groups[i]
        b=[min(r['box'][0] for r in items),min(r['box'][1] for r in items),
           max(r['box'][2] for r in items),max(r['box'][3] for r in items)]
        if b[2]-b[0] > image.width/4*1.8 or b[3]-b[1] > image.height/4*1.7:
            raise ValueError(f'Pose {i+1} spans multiple cells; inspect connected figures: {b}')
        crop=np.zeros((b[3]-b[1],b[2]-b[0],4),dtype=np.uint8)
        for r in items:
            for y,left,right in r['runs']:
                crop[y-b[1],left-b[0]:right-b[0]]=pixels[y,left:right]
        frames.append(Image.fromarray(crop))
    return frames
