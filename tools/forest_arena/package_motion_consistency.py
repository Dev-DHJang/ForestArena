"""Package real-renderer audit captures; retain timing and source fingerprints."""
import argparse,hashlib,html,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw

def package(captures,out,boards_only=False):
    index=json.loads((captures/'capture-index.json').read_text())
    (out/'playback').mkdir(exist_ok=True);(out/'runtime-boards').mkdir(exist_ok=True)
    media=[]
    for row in index['motions']:
        key=row['character_id']+'--'+row['motion_id'];source=captures/key
        target=out/'playback'/(key+'.mp4')
        if not boards_only: subprocess.run(['ffmpeg','-v','error','-y','-framerate','30','-i',str(source/'%05d.png'),'-c:v','libx264','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(target)],check=True)
        wanted=[0];seen=set()
        for i,job in enumerate(row['jobs']):
            sample=job['sample'];tag=(job['segment'],sample['phase'])
            if tag not in seen and job['segment'] not in ['idle-before','idle-after']:
                seen.add(tag)
                matches=[n for n,j in enumerate(row['jobs']) if j['segment']==job['segment'] and j['sample']['phase']==sample['phase']]
                wanted.append(matches[len(matches)//2])
        wanted.append(len(row['jobs'])-1)
        board=Image.new('RGB',(640,len(wanted)*280),'#293440');d=ImageDraw.Draw(board)
        for j,i in enumerate(wanted):
            job=row['jobs'][i];sample=job['sample']
            d.text((5,j*280+4),f'{key} | {job["segment"]} / {sample["phase"]} | F{sample["frame"]+1} | clip t={i/30:.3f}s (includes 0.5s idle prefix)',fill='white')
            # Keep native/2x normal + mirrored with actual renderer effects.
            shot=Image.open(source/f'{i:05}.png');board.paste(shot.resize((640,256)),(0,j*280+22))
        board.save(out/'runtime-boards'/(key+'.jpg'),quality=94)
        # Exact native aspect screenshot for detailed inspection, no aspect squeeze.
        preview=wanted[1] if len(wanted)>2 else wanted[0]
        Image.open(source/f'{preview:05}.png').save(out/'runtime-boards'/(key+'-detail.png'))
        media.append({'character_id':row['character_id'],'motion_id':row['motion_id'],'frame_count':row['frames'],'fps':30,'duration_seconds':row['frames']/30,'mp4':'playback/'+key+'.mp4','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'runtime_board':'runtime-boards/'+key+'.jpg'})
        print('PACKAGED',key,flush=True)
    (out/'playback-index.json').write_text(json.dumps({'renderer':index['renderer'],'timeline_sha256':index['timeline_sha256'],'method':'Observed real presentation transforms replayed with actual fighter_attack_effects; fixed audit camera; 30 FPS sampling of 60 Hz timeline; 0.5 second idle before/after. Not a simulated match or Android result.','motions':media},ensure_ascii=False,indent=2)+'\n')
    content=['<!doctype html><html lang="ko"><meta charset="utf-8"><title>모션 외형 비교</title><style>body{background:#192430;color:#eee;font:16px sans-serif;max-width:1300px;margin:auto}img,video{max-width:100%}article{border-top:1px solid #789;padding:16px}button{padding:10px}a{color:#9df}</style><h1>모션 외형 비교</h1><p>122모션·2,000원화 프레임. 상단 원화보드: 승인4각도·RAW/실제 표시 배율. 영상: 2배 확대와 원래 크기, 정상/좌우 반전. 고정 검사 카메라와 실제 효과 코드 재생이며 실제 경기·Android 결과가 아닙니다. 원속도 30FPS(60Hz에서 2틱마다), 앞뒤 대기 각0.5초. 작은 차이까지 기록하며 재작업은 별도 결정합니다.</p><p><a href="review-list.md">검토 목록</a> · <a href="review-list.csv">CSV</a></p>']
    for row in media:
        key=row['character_id']+'--'+row['motion_id'];content.append(f'<article id="{key}"><h2>{html.escape(key)}</h2><video controls preload="none" loop src="{row["mp4"]}"></video><p><button onclick="this.closest(\'article\').querySelector(\'video\').playbackRate=1">정상 1×</button> <button onclick="this.closest(\'article\').querySelector(\'video\').playbackRate=.25">느리게 0.25×</button></p><a href="boards/{key}.jpg">전체 프레임 원본 크기</a><details><summary>원화 전체 프레임과 대표 이미지</summary><img loading="lazy" src="boards/{key}.jpg"></details><details><summary>게임 표시·효과 표본</summary><img loading="lazy" src="{row["runtime_board"]}"></details></article>')
    (out/'index.html').write_text('\n'.join(content)+'</html>')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--captures',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--boards-only',action='store_true');a=p.parse_args();package(a.captures,a.output,a.boards_only)
