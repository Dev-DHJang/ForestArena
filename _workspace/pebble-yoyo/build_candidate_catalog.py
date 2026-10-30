from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];base=root/'_workspace/pebble-yoyo'
rows=[]
for c in ['ja-hyun','nabi']:
 for mode in ['ground','air']:
  folder=base/'motions'/c/mode/'r02';m=json.loads((folder/'candidate.json').read_text());png=str((folder/'sheet-128.png').relative_to(root));tres=folder/'candidate.tres'
  parts=['[gd_resource type="SpriteFrames" load_steps=18 format=3]',f'[ext_resource type="Texture2D" path="res://{png}" id="1"]']
  for i in range(16):parts.append(f'[sub_resource type="AtlasTexture" id="frame_{i}"]\natlas = ExtResource("1")\nregion = Rect2({i%8*128}, {i//8*128}, 128, 128)')
  frames=',\n'.join('{"duration": '+str(d)+', "texture": SubResource("frame_'+str(i)+'")}' for i,d in enumerate(m['frame_durations']))
  parts.append('[resource]\nanimations = [{"frames": ['+frames+'], "loop": false, "name": &"'+m['motion_id']+'", "speed": 60.0}]')
  tres.write_text('\n\n'.join(parts)+'\n')
  rows.append({'asset_id':c+'-'+m['motion_id'].replace('_','-')+'-candidate-r02','type':'animation-candidate','character_id':c,'visual_state_id':m['motion_id'],'path':png,'sha256':m['sheet_sha256'],'sprite_frames_path':'res://'+str(tres.relative_to(root)),'fps':60,'loop':False,'frame_count':16,'atlas_columns':8,'cell_size':128,'frame_durations':m['frame_durations'],'equipment_phase_frame_ranges':m['equipment_phase_frame_ranges'],'frame_anchors':m['frame_anchors'],'foot_pivot_y':120,'presentation_scale':m['presentation_scale'],'expected_action':('지상 발 디딤을 유지하며' if mode=='ground' else '공중에 무릎을 접은 채')+' 팔을 준비하고 전방으로 요요를 던져18틱 동안 늘린 뒤18틱 동안 회수하고 전투 자세로 복귀한다. 실·요요는 별도 표시하고 손 연결·좌우 반전·몸 크기를 유지한다.','action_source':'docs/gameplay/pebble-yoyo.md','equipment_resource_path':'assets/loadouts/pebble_yoyo_accessory.tres','reference_set':m['reference_set'],'reference_attachments':m['reference_attachments']})
catalog={'schema_version':1,'kind':'motion-candidates','approval_status':'pending','assets':rows,'attack_sources':['assets/combat/movesets/two_fighter_ja_hyun_moveset.tres','assets/combat/movesets/two_fighter_nabi_moveset.tres','assets/loadouts/pebble_yoyo_accessory.tres'],'character_movesets':{'ja-hyun':'assets/combat/movesets/two_fighter_ja_hyun_moveset.tres','nabi':'assets/combat/movesets/two_fighter_nabi_moveset.tres'}}
p=base/'candidate-catalog.json';p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
(base/'candidate-scope.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in rows]},ensure_ascii=False,indent=2)+'\n')
print('Prepared private candidate catalog/scope and4 review-only SpriteFrames.')
