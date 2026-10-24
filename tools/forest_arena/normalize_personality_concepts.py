"""Permission-guarded mechanical preparation. Never registers game assets.

The CLI must not be used on artwork until the user approves local alpha/size
cleanup. Unit tests exercise only synthetic fixtures. No repainting or AI calls.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from verify_personality_concepts import ROOT, WORK, ROSTER, image_errors, check_review

POLICY={'alpha_threshold':8,'transparent_margin':48,'allow_upscale':False,
        'preserve_aspect_ratio':True,'repaint':False}


def normalize_image(image):
    errors=image_errors(image,require_margin=False)
    if errors:
        raise ValueError('; '.join(errors))
    pixels=np.asarray(image).copy()
    alpha=pixels[:,:,3]
    dropped=int(((alpha>0)&(alpha<POLICY['alpha_threshold'])).sum())
    pixels[alpha<POLICY['alpha_threshold'],3]=0
    pixels[pixels[:,:,3]==0,:3]=0  # Invisible RGB must not look like a backdrop in previews.
    clean=Image.fromarray(pixels)
    box=clean.getchannel('A').getbbox()
    if box is None:
        raise ValueError('No visible character after alpha cleanup')
    cropped=clean.crop(box)
    # Four extra pixels absorb the resampling kernel without violating 48px margin.
    padding=POLICY['transparent_margin']+4
    scale=min(1.0,(1024-2*padding)/cropped.width,(1536-2*padding)/cropped.height)
    size=(max(1,int(cropped.width*scale)),max(1,int(cropped.height*scale)))
    if size!=cropped.size:
        cropped=cropped.resize(size,Image.Resampling.LANCZOS)
    offset=((1024-cropped.width)//2,(1536-cropped.height)//2)
    final=Image.new('RGBA',(1024,1536))
    final.paste(cropped,offset)  # Copy alpha once; using an alpha mask here would square it.
    values=np.asarray(final).copy()
    values[values[:,:,3]<POLICY['alpha_threshold'],3]=0
    values[values[:,:,3]==0,:3]=0
    final=Image.fromarray(values)
    errors=image_errors(final)
    if errors:
        raise ValueError('; '.join(errors))
    return final,{'policy':POLICY.copy(),'source_alpha_bbox':list(box),
                  'uniform_scale':scale,'offset':list(offset),'dropped_faint_pixels':dropped}


def prepare_review(report_path,permission_path,root=ROOT):
    # Reject absent/false/stale permission BEFORE opening or writing any artwork.
    if not permission_path.is_file():
        raise PermissionError('User approval for local normalization is required')
    permission=json.loads(permission_path.read_text())
    report_sha=hashlib.sha256(report_path.read_bytes()).hexdigest()
    if (permission.get('user_approved_local_normalization') is not True
            or permission.get('raw_report_sha256')!=report_sha
            or permission.get('policy')!=POLICY):
        raise PermissionError('Missing, changed-policy or stale local normalization approval')
    report=json.loads(report_path.read_text())
    errors=check_review(report,root,require_margin=False)
    if errors:
        raise ValueError('; '.join(errors))
    work=root/'_workspace/character-personality-concepts'
    destination=work/'05_normalized'
    if destination.exists():
        raise FileExistsError('Preserve existing normalized candidates; do not overwrite')
    prepared=[]
    for cid in ROSTER:
        row=report[cid]
        source=(root/row['path']).resolve()
        if not source.is_relative_to((work/'03_drafts').resolve()):
            raise ValueError('Only review draft sources may be normalized')
        with Image.open(source) as image:
            final,details=normalize_image(image)
        prepared.append((cid,row,final,details))
    destination.mkdir(parents=True)
    result={}
    for cid,row,image,details in prepared:
        path=destination/f'{cid}-concept-personality-v01.png'
        image.save(path)
        result[cid]={**row,'path':str(path.relative_to(root)),
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'raw_source_path':row['path'],'raw_source_sha256':row['sha256'],
            'normalization':details,'user_approved':False,
            'review_status':'needs-new-visual-qa-and-user-approval'}
    output=work/'normalized-candidates.json'
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--permission',type=Path,default=WORK/'normalization-permission.json')
    args=parser.parse_args()
    prepare_review(WORK/'review-candidates.json',args.permission)
    print('PERSONALITY_NORMALIZATION: prepared 4 review candidates; NOT asset registration or user approval')
