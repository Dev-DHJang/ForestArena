"""Build evidence for a human appearance audit; never classify artwork automatically."""
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path
from PIL import Image, ImageDraw
from motion_layout import layout, frame_box, motion_id
from review_motion_actions import timeline_errors


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
def composite(cell, scale, position, offset=(0,0), flip=False, size=(160,160)):
    """Fixed fighter origin (80,132-14); no artwork bounds fitting."""
    if not math.isfinite(scale) or scale <= 0: raise ValueError('invalid display scale')
    canvas=Image.new('RGBA',size,'#9ca5ad')
    d=ImageDraw.Draw(canvas); d.line((0,132,size[0],132),fill='#53616d')
    image=cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else cell
    image=image.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS)
    x=round(size[0]/2+position[0]+(-64+offset[0])*scale)
    y=round(118+position[1]+(-64+offset[1])*scale)
    canvas.alpha_composite(image,(x,y))
    return canvas.convert('RGB')


def prepare(root, timeline_path, out):
    if (out/'motion-review.json').exists(): raise ValueError('preserve completed review; use a new output directory')
    rows=[r for r in json.loads((root/'assets/character/manifest.json').read_text())['assets'] if r.get('type')=='animation-runtime']
    timeline=json.loads(timeline_path.read_text())
    errors=timeline_errors(root,timeline,rows)
    if errors: raise ValueError('; '.join(errors))
    out.mkdir(parents=True,exist_ok=True); (out/'boards').mkdir(exist_ok=True)
    (out/'.gdignore').write_text('')
    bykey={(r['character_id'],r['motion']):r for r in timeline['motions']}
    records=[]; snapshot={p:sha(root/p) for p in timeline['sources']}
    for source in ['docs/contracts/character-appearance-v01.json', 'tools/forest_arena/motion_consistency_timeline.gd', 'tools/forest_arena/motion_review_timeline.gd', 'tools/forest_arena/render_motion_consistency.gd', 'tools/forest_arena/package_motion_consistency.py', 'scripts/scarf_attack_paths.gd', 'scripts/claw_attack_paths.gd', 'forest_arena/data/resource_registry.json', 'forest_arena/assets/ui/premium-menu-v07/characters/ja-hyun-concept-v01.png']:
        # Fixture projects need only the appearance contract; actual audit pins all available consumers.
        if (root/source).is_file(): snapshot[source]=sha(root/source)
    for row in rows:
        cid,mid=row['character_id'],motion_id(row); spec=layout(row); rt=bykey[cid,mid]
        sheet=Image.open(root/row['path']).convert('RGBA')
        expected=spec['sheet_size']
        if sheet.size!=expected: raise ValueError(f'{cid}/{mid}: sheet {sheet.size} != {expected}')
        snapshot[row['path']]=sha(root/row['path'])
        if snapshot[row['path']]!=row['sha256']: raise ValueError('manifest PNG hash mismatch')
        refbase=Path('assets/character')/cid/'reference/v01'
        for name in ['reference.json','combat.png','front.png','side.png','rear.png']: snapshot[str(refbase/name)]=sha(root/refbase/name)
        board=Image.new('RGB',(1280,160+math.ceil(spec['frame_count']/8)*320),'#293440'); d=ImageDraw.Draw(board)
        d.text((6,4),f'{cid}/{mid} | refs at 1/8 | raw / effective display | 1-based frames',fill='white')
        for col,view in enumerate(['combat','front','side','rear']):
            image=Image.open(root/refbase/(view+'.png')).convert('RGBA').resize((128,128),Image.Resampling.LANCZOS)
            back=Image.new('RGBA',(128,128),'#9ca5ad');back.alpha_composite(image);board.paste(back.convert('RGB'),(col*160+16,25)); d.text((col*160+16,16),view,fill='white')
        samples=[s for v in rt['variants'] for s in v['samples']]
        if not samples or any('sprite_scale' not in s for s in samples): raise ValueError('missing observed transform')
        first=samples[0]; scales={s['sprite_scale'][0] for s in samples}
        if len(scales)!=1: raise ValueError('unexpected varying motion scale')
        d.text((660,32),f'Observed scale: {first["sprite_scale"][0]:.5f}',fill='white')
        d.text((660,52),'Reference size is a comparison guide, not a new game scale.',fill='white')
        d.text((660,72),'* = authored frame not selected in timeline; position is estimated.',fill='white')
        bounds=[]; unshown=[]
        for i in range(spec['frame_count']):
            cell=sheet.crop(frame_box(i,spec));bounds.append(cell.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox())
            y=160+(i//8)*320;x=(i%8)*160
            raw=Image.new('RGBA',(160,160),'#9ca5ad');raw.alpha_composite(cell,(16,20));board.paste(raw.convert('RGB'),(x,y))
            matches=[s for s in samples if s['frame']==i]
            if matches: sample=matches[0];pos=sample['sprite_position']
            else:
                unshown.append(i+1);pos=list(first['sprite_position'])
                # Authored unshown drawing: same model scale; read body anchor explicitly.
                anchors=row.get('frame_anchors',[])
                if len(anchors)==spec['frame_count'] and 'body_root' in anchors[i]:
                    anchor=anchors[i]['body_root'];pos=[(64-anchor[0])*first['sprite_scale'][0],14-(anchor[1]-64)*first['sprite_scale'][0]]
            board.paste(composite(cell,first['sprite_scale'][0],pos,first['sprite_offset']),(x,y+160))
            d.text((x+3,y+3),f'F{i+1} RAW',fill='#132331');d.text((x+3,y+163),f'F{i+1} DISPLAY'+(' *' if not matches else ''),fill='#132331')
        path=f'boards/{cid}--{mid}.jpg';board.save(out/path,quality=93)
        variants=[]
        for v in rt['variants']:
            hits={}
            for n,s in enumerate(v['samples']):
                f=str(s['frame']+1);hits.setdefault(f,[]).append(round(n/60,4))
            variants.append({'attack_id':v['attack_id'],'duration_seconds':len(v['samples'])/60,'frame_times_seconds':{f:[min(t),max(t)+1/60] for f,t in hits.items()}})
        records.append({'character_id':cid,'motion_id':mid,'frame_count':spec['frame_count'],'png_path':row['path'],'png_sha256':snapshot[row['path']],'sprite_frames_path':row['sprite_frames_path'],'manifest_status':row.get('status'),'approval_record':row.get('motion_registration',{}).get('approval_record',row.get('motion_unification',{}).get('approval_record')),'display_scale':first['sprite_scale'][0],'alpha_bounds':bounds,'unshown_authored_frames':unshown,'variants':variants,'board':path,'classification':'not-reviewed','observations':[]})
    write(out/'source-snapshot.json',{'sources':snapshot,'timeline_sha256':sha(timeline_path),'baseline_commit':'4221f6cc6bee607aa6f7d2f30d1d0b2230126def'})
    write(out/'coverage.json',{'schema_version':1,'motions':records,'motion_count':len(records),'frame_count':sum(r['frame_count'] for r in records),'warnings':timeline['warnings']})
    print(f'Prepared {len(records)} motions / {sum(r["frame_count"] for r in records)} frames')

def validate_sources(root, snapshot):
    errors=[]
    for path,digest in snapshot['sources'].items():
        source=root/path
        if not source.is_file(): errors.append('missing source: '+path)
        elif sha(source)!=digest: errors.append('changed source: '+path)
    return errors


def validate(root,out):
    snapshot=json.loads((out/'source-snapshot.json').read_text())
    errors=validate_sources(root,snapshot)
    if not (out/'timeline.json').is_file() or sha(out/'timeline.json')!=snapshot['timeline_sha256']: errors.append('changed/missing observed timeline')
    coverage=json.loads((out/'coverage.json').read_text())
    review=json.loads((out/'motion-review.json').read_text())
    media=json.loads((out/'playback-index.json').read_text())
    if media['timeline_sha256']!=snapshot['timeline_sha256']:errors.append('playback uses a different timeline')
    manifest=[r for r in json.loads((root/'assets/character/manifest.json').read_text())['assets'] if r.get('type')=='animation-runtime']
    expected={(r['character_id'],motion_id(r)):layout(r)['frame_count'] for r in manifest}
    for label,rows in [('coverage',coverage['motions']),('review',review['motions']),('playback',media['motions'])]:
        keys=[(r['character_id'],r['motion_id']) for r in rows]
        if len(keys)!=len(set(keys)) or set(keys)!=set(expected):errors.append(label+' coverage differs from manifest')
    for row in review['motions']:
        key=row['character_id'],row['motion_id'];count=expected.get(key,0)
        if row.get('reviewed_frames')!=list(range(1,count+1)):errors.append('missing reviewed frames: '+str(key))
        if row.get('classification') not in ['difference-observed','no-difference-observed','judgment-deferred','evidence-missing']:errors.append('unreviewed classification: '+str(key))
        for note in row.get('observations',[]):
            if not note.get('frames') or any(type(f)!=int or not 1<=f<=count for f in note['frames']):errors.append('invalid finding frame: '+str(key))
            if not all(note.get(f) for f in ['category','severity','confidence','observation','proposed_followup']):errors.append('incomplete finding: '+str(key))
        if row['classification']=='no-difference-observed' and row.get('observations'):errors.append('findings contradicted by classification: '+str(key))
    for row in media['motions']:
        path=out/row['mp4']
        if not path.is_file() or sha(path)!=row['sha256']:errors.append('missing/changed playback: '+row['mp4'])
    if coverage['frame_count']!=sum(expected.values()):errors.append('wrong total authored frames')
    for path,digest in review.get('evidence_sha256',{}).items():
        asset=out/path
        if not asset.is_file() or sha(asset)!=digest:errors.append('missing/changed evidence: '+path)
    if errors:raise ValueError('; '.join(errors))
    print(f'MOTION_CONSISTENCY_AUDIT: PASS ({len(expected)} motions / {sum(expected.values())} authored frames; evidence consistency only)')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--project-root',type=Path,default=Path('.'));p.add_argument('--timeline',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--validate',action='store_true');a=p.parse_args()
    if a.validate:validate(a.project_root.resolve(),a.output)
    elif a.timeline:prepare(a.project_root.resolve(),a.timeline,a.output)
    else:p.error('--timeline is required for prepare')
