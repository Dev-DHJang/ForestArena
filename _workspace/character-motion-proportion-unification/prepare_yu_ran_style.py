"""유란의 승인 idle 원본만 고정 참조로 삼아 29개 개별 요청을 준비한다."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image
from prepare_nabi_style import INTENTS as NABI_INTENTS, sha

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '08_yu_ran-style-locked'
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from motion_sheet_regions import split_regions

INTENTS = {s: NABI_INTENTS[s].replace('claw hands', 'hands').replace('claw guards', 'forearms').replace('claws', 'hands').replace('claw', 'hand')
           for s in ('run', 'jump', 'guard', 'evade', 'hitstun', 'launch', 'knock_down', 'wake_up', 'ring_out', 'death', 'spawn')}
INTENTS.update({
 'attack_light_combo_01': 'Compact rightward front-hand jab.1-4 guarded small step,5-8 front fist extends at chest height,9-12 retract,13-16 low guard. Rear hand protects face, tail counterbalances behind, not the main strike.',
 'attack_light_combo_02': 'Second linked body hook.1-4 coil hips in guard,5-8 short rear-hand horizontal hook to right with visible torso turn,9-12 follow-through,13-16 guard. Distinct from straight opener, tail follows hips.',
 'attack_light_combo_03': 'Tail-assisted final combo.1-4 lower hips and gather ringed tail behind,5-9 pivot and bring the ONE large tail around toward right at waist height,10-12 full follow-through,13-16 recoil to wide guard. Human arms guard, do not become tails.',
 'attack_light_up': 'Quick compact rising palm.1-4 hand low in guard,5-8 front palm presses diagonally upper-right with slight leg extension,9-12 retract,13-16 guard. Grounded, no large leap; tail lightly counterbalances.',
 'attack_light_down': 'Short low hand check.1-4 lower center,5-8 front fist reaches forward-down at shin height while rear hand guards,9-12 retract,13-16 guard. Grounded human feet, tail tucked behind.',
 'attack_heavy_side': 'Weighty single horizontal tail sweep to right.1-4 deep hip coil and gather tail behind,5-9 pivot supporting human feet and rotate torso to swing ONE thick ringed tail across front at waist height,10-12 extended follow-through,13-16 gather tail and regain guard. Tail retains full thickness and length; use a compact rounded S bend, not a ruler-straight overlong extension. Body fully visible all16.',
 'attack_heavy_up': 'Upward tail launcher.1-4 deep crouch gathering tail low behind,5-9 strong uncoiling and small hop with the large ringed tail sweeping in a vertical curl toward upper-right,10-12 high follow-through,13-16 land and guard. Human hands tucked, no extra tail.',
 'attack_heavy_down': 'Ground-level tail sweep.1-4 sink hips,5-9 pivot low while ONE large striped tail sweeps in a broad compact curve toward right near ground,10-12 low follow-through,13-16 rise into guard. Human feet support, no disappearing torso.',
 'attack_heavy_charge': 'Charged tail slam.1-6 visibly coil hips and gather ONE ringed tail upward in a compact curve,7-8 tense low stance,9-11 release a heavy forward-down tail swing to right,12-13 follow-through,14-16 slow recovery. Charge through body tension only, no glow or VFX.',
 'attack_dash_light': 'Advancing short palm jab.1-4 lean forward into step,5-8 front palm pushes horizontally right as rear leg drives,9-12 lead foot brakes and arm retracts,13-16 guard. Tail curls behind as counterweight, not a long full-body stretch.',
 'attack_dash_heavy': 'Heavy forward body-and-tail lunge.1-4 crouch and load,5-9 leap a short distance right with forward shoulder and large striped tail sweeping around at torso height,10-12 descend in compact follow-through,13-16 land and brake. Both human legs remain articulated, tail one connected curved mass.',
 'attack_air_light': 'Compact aerial front kick. ALL16 airborne.1-4 knees tucked and hands guarding,5-8 short snap of front sneaker to right,9-12 retract leg,13-16 tuck into descending air guard. Large ringed tail curls around back as counterweight. No landing or planted foot.',
 'attack_air_heavy': 'Large aerial tail finisher. ALL16 airborne.1-4 tuck and coil hips,5-9 body turns while ONE oversized ringed tail arcs forward-down to right,10-12 follow-through with bent knees,13-16 retract into descending airborne guard. Compact rounded tail arc, no effect trails or standing recovery.',
 'special_neutral': 'ONE wide close-range ringed tail sweep, not multihit.1-4 low wide stance and gather tail,5-9 strong hip pivot driving ONE large brown-white ringed tail horizontally across forward-right space,10-12 follow-through,13-16 recoil to guard. Wide tail attack is signature; human body and both hands still visible. Bend the full long tail into a rounded hook within cell, never shrink it.',
 'special_side': 'Advancing tail-sweep step.1-4 gather tail behind and brace legs,5-9 stride right with hip rotation and large tail swinging across forward-right torso space,10-12 brake and gather tail,13-16 guard. This is presentation for existing compatibility move, not a new projectile or teleport.',
 'special_up': 'Vertical recovery leap.1-4 deep compression,5-9 thrust upward with one human fist reaching upper-right and knees lifting,10-12 high airborne extension with ONE ringed tail curling below and behind,13-16 slow compact apex/descent. End airborne. No tail rotor copies or VFX.',
 'special_down': 'Low defensive tail sweep.1-4 guarded crouch,5-9 low hip turn sweeping ONE ringed tail toward right near ground while hands shield upper body,10-12 low recoil,13-16 guard. Presentation only, no shield bubble or new counter mechanic.',
 'ultimate': 'Climactic physical tail finisher.1-4 deep coil,5-8 advancing hip turn,9-12 decisive broad forward-right ringed-tail sweep with full torso rotation,13-16 brake and regain guard. One full-size tail bent into a compact strong arc, same body scale all16; no giant spectral tail, opponent, extra copies, VFX or weapon.',
})

COMMON = '''Use case: stylized-concept.
Asset type: Forest Arena Yu-Ran16-frame motion review sprite sheet; not a redesign.
Input images: Image1 is the USER-APPROVED Yu-Ran idle's first pose, exact character AND rendering master. Image2 contains16 poses from the SAME approved idle source. Both are derived from ONE approved source. NO other character, old motion, or new style reference.
Primary request: re-pose this EXACT SAME illustrated adult feminine human-form chibi fighter. Only articulated pose, appropriate expression and natural hair/tail/ribbon follow-through change. Preserve exact face, amber eyes, nose/mouth, ash-silver hair tufts and tied hair, bangs, large black bow, teal ribbons and gem, jacket fur collar and sleeve bands, shorts straps, fingerless gloves, sneaker panels, skin tone and compact head/body/limb proportions. Exactly TWO round brown weasel ears with white inner tufts; exactly ONE oversized long thick fluffy BROWN AND WHITE RINGED tail attached at pelvis, including teal bow accent. Human face, human hands and feet, human arms/legs. Brown-white-black streetwear and restrained gold buckles. Not a child; not animal anatomy beyond approved ears/tail.
STYLE LOCK: Same fine brown-gray colored contours, subtle smooth painted shading, restrained highlights, detailed softly shaded hair clusters, fabric and fur rendering, warm palette, same eye model and edge softness as Image1. Same artist, same model, same sitting. NO restyling, flat cel shading, chunky black outline, plastic figurine sheen, watercolor or pixel art. Exact same model scale across all16, ears and tail excluded from human body height. Do NOT shrink the human body to fit tail: curve the full tail compactly using natural vertical/S bends while preserving its volume and length.
Composition: square canvas, EXACTLY4 columns x4 rows,16 genuinely DIFFERENT consecutive FULL-BODY articulated poses, left-to-right then top-to-bottom. Actions/travel face RIGHT, same slightly3/4 side-game camera. Natural body turns allowed, but attack still right. Include entire head/ears/hair/hands/feet/tail in EVERY cell. Large blank margins on all4 sides INCLUDING final-row feet and tips. Same scale, entire figure at most65% cell width/height; no overlapping cells or canvas edges. No duplicated static poses merely translated/rotated.
Backdrop: uniform OPAQUE neutral gray RGB128 for separate background extraction. NO checkerboard, gradient, ground line, cast shadow, grid, labels, text, watermark, opponent, weapon, brand emblem, VFX, impact marks, speed lines, motion smears, ghosts or hitbox. No muzzle, fur limbs, paw hands/feet, digitigrade legs, extra ears/tails/limbs or detached floating tail. Acting only, not combat hit timing.
'''

def main():
    assert not (BATCH / 'generation-prompts-r01.json').exists()
    approval = json.loads((WORK / '03_sample_approval.json').read_text())
    sample = next(r for r in approval['samples'] if r['character_id'] == 'yu-ran')
    assert approval['user_approved'] and sha(ROOT / sample['path']) == sample['sha256']
    refs = BATCH / '01_style_reference'
    refs.mkdir(parents=True)
    source = WORK / '02_samples/yu-ran/idle-r05-alpha.png'
    target = refs / 'approved-idle-source.png'
    shutil.copy2(source, target)
    poses = split_regions(Image.open(target))
    paths = [refs / 'style-master-pose01-matte.png', refs / 'style-master-16poses-matte.png']
    board = Image.new('RGBA', (1536, 1536), '#808080')
    one = Image.new('RGBA', (384, 384), '#808080')
    for i, pose in enumerate(poses):
        assert max(pose.size) < 384
        board.alpha_composite(pose, ((i%4)*384+(384-pose.width)//2, (i//4)*384+(384-pose.height)//2))
    one.alpha_composite(poses[0], ((384-poses[0].width)//2, (384-poses[0].height)//2))
    one.convert('RGB').save(paths[0]); board.convert('RGB').save(paths[1])
    record = {'date':'2026-10-17', 'approved_idle':sample, 'source_path':str(target.relative_to(ROOT)), 'source_sha256':sha(target), 'reference_paths':[str(p) for p in paths], 'reference_sha256':[sha(p) for p in paths], 'derivation':'Exact same approved idle source pixels, region crops and gray matte only; no redraw or recolor.'}
    (refs/'selection.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    entries = [e for e in json.loads((WORK/'01_baseline.json').read_text())['runtime_entries'] if e['character_id']=='yu-ran']
    assert len(entries)==30 and {e['visual_state_id'] for e in entries}-{'idle'}==set(INTENTS)
    prompts = [{'state':e['visual_state_id'], 'intent':INTENTS[e['visual_state_id']], 'prompt':COMMON+'\nMOTION '+e['visual_state_id']+': '+INTENTS[e['visual_state_id']], 'referenced_image_paths':[str(p) for p in paths], 'transparent_background':False, 'fps':e['fps'], 'loop':e['loop']} for e in entries if e['visual_state_id']!='idle']
    (BATCH/'generation-prompts-r01.json').write_text(json.dumps(prompts,ensure_ascii=False,indent=2)+'\n')
    for name in ('02_drafts','03_alpha','04_review'):
        (BATCH/name).mkdir()
    print('YU-RAN STYLE LOCK: one approved source, 29 separate prompts prepared; no runtime writes.')

if __name__=='__main__':
    main()
