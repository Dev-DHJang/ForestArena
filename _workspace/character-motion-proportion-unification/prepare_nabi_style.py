"""Freeze approved Nabi idle master; prepare 28 new motions with one style block."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / '07_nabi-style-locked'
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from motion_sheet_regions import split_regions

INTENTS = {
    'run': 'Rightward running loop IN PLACE.1-4 front contact and compression,5-8 push off and passing stride,9-12 opposite foot contact and compression,13-16 opposite push off and return. Real alternating legs, opposing bent arm swing, moderate forward lean; single tail and hair trail smoothly. No attacks.',
    'jump': 'One complete jump.1-3 compress guard,4-6 push off and rise with knees bent,7-9 compact apex,10-12 extend legs into descent,13-16 land with bent knees then guard. Smooth body-center arc, no attacks.',
    'attack_light_combo_01': 'Short forward claw jab.1-4 low guard and small front step,5-8 extend front lavender claw guard horizontally right while other hand protects face,9-12 retract,13-16 return guard. A compact quick opener, not a wide crossing slash.',
    'attack_light_combo_02': 'Two-hand crossed claw FINISH.1-4 draw both forearms apart,5-9 sweep both lavender claw guards in a broad diagonal crossing in front to the right,10-12 follow through with torso turn,13-16 recover. Two physical arms only, no slash effects.',
    'attack_light_up': 'Short rising claw check.1-4 low guard with front hand lowered,5-8 quick upward diagonal forearm/claw cut toward upper-right with small knee extension,9-12 retract,13-16 guard. Remain grounded; compact attack, not a high leap.',
    'attack_light_down': 'Short low claw check.1-4 crouch,5-8 reach front lavender claw guard forward-down toward shin level while back hand guards face,9-12 retract from low position,13-16 guard. Human feet remain planted, no kick.',
    'attack_heavy_side': 'Large horizontal claw strike.1-4 coil torso with front arm pulled back,5-9 rotate supporting foot/hips and drive a wide claw sweep to the right at torso level,10-12 large follow-through,13-16 recover. More extended and weighty silhouette than light jab.',
    'attack_heavy_up': 'Rising claw launcher.1-4 deep crouch with both arms low,5-9 strong upward uncoiling into rising upper-right claw cut and small leap,10-12 high follow-through,13-16 land then guard. Tail counterbalances continuously.',
    'attack_heavy_down': 'Wide grounded low claw rake.1-4 lower hips,5-9 pivot in a low stance and sweep one claw arm broadly just above ground toward right,10-12 hold low follow-through,13-16 recover. A low hand-led attack, not a leg sweep.',
    'attack_heavy_charge': 'Charged claw strike.1-5 deep braced coiling with claws drawing back,6-8 strong visible torso tension and lowered center,9-11 explosive large forward claw thrust to right,12-13 follow-through,14-16 slow recovery. No glow or VFX; charge conveyed by body only.',
    'attack_dash_light': 'Short advancing claw jab.1-4 forward leaning entry step,5-8 compact one-hand horizontal claw jab with legs carrying forward momentum,9-12 brake on lead foot and retract,13-16 recover low guard. Not a kick or static idle.',
    'attack_dash_heavy': 'Heavy lunging claw finisher.1-4 deep coil,5-9 long forward lunge with widely extended forward claw arm and strong back-leg push,10-12 extended follow-through,13-16 long braking recovery. Broader silhouette than dash light.',
    'attack_air_light': 'Compact aerial claw snap. ALL16 airborne, feet never planted.1-4 knees tucked with hands guarding,5-8 quick short forward claw extension right,9-12 retract,13-16 return tucked descending airborne guard. Keep body compact; no landing or kick.',
    'attack_air_heavy': 'Large airborne crossed-claw finisher. ALL16 airborne.1-4 tuck and coil torso,5-9 turn torso and extend claws forward-down right in a broad crossing cut,10-12 full follow-through,13-16 retract into descending airborne posture. No ground or standing recovery, no VFX.',
    'special_neutral': 'One focused close-range claw attack, NOT repeated multi-hit.1-4 low guard drawing both claws back,5-9 commit forward with a powerful concentrated two-claw thrust toward right,10-12 recoil from extension,13-16 guard. Human arms and single tail clearly readable.',
    'special_side': 'Pounce slash.1-4 crouch and load rear leg,5-9 leap forward right with one claw arm extended in a decisive slash,10-12 descend with claws retracting,13-16 absorb landing and regain guard. Clear forward airborne travel; no copied silhouettes or effects.',
    'special_up': 'Vertical recovery claw rise.1-4 deep compression,5-9 powerful upward jump with one lavender claw guard reaching upper-right,10-12 high airborne extension and tail trailing below,13-16 compact slow apex/descent. End airborne, no forced landing. Not a kick.',
    'special_down': 'Guard rake.1-4 lower into defensive braced crouch with forearms shielding face,5-9 open the guard into a low forward claw rake to right,10-12 retract while staying low,13-16 guard. Pose only: no shield bubble, auto-counter cues or invulnerability effects.',
    'ultimate': 'Physical claw finisher.1-4 deep wind-up,5-8 forward low pounce and sweeping claw reach,9-12 large two-handed crossing finish toward right with full torso rotation,13-16 brake and recover. Distinct climactic broad silhouette but same actual model scale. No giant energy claws, extra arms, ghost copies or opponent.',
    'guard': 'Defensive guard loop-like acting.1-4 raise forearms/claw guards in front of face and chest,5-8 brace knees and shoulders,9-12 small weight transfer maintaining cover,13-16 settle back into protected stance. Real small articulation; no strike, shield prop or bubble.',
    'evade': 'Rightward evasive duck and low slip.1-4 compress and tuck claw hands close,5-9 lower head and shift shoulders/hips forward under an imagined attack,10-12 plant leading foot and rise,13-16 recover. No attack or disappearing pose, no ghosts.',
    'hitstun': 'Brief non-graphic hit reaction, NOT attack.1-4 guarded stance,5-9 chest and head recoil backward with arms opening and pained expression,10-12 catch balance,13-16 guarded recovery. No attacker, injury, blood, impact effect or forward striking claws.',
    'launch': 'Non-graphic upward knockback.1-4 startled low recoil,5-9 feet lift with torso tilting backward and limbs reacting,10-12 airborne backward arch,13-16 compact airborne fall preparation. End airborne; no standing recovery or attack.',
    'knock_down': 'Non-graphic knockdown.1-4 lose balance backward,5-8 knees buckle and body drops,9-12 land on side/back with bent human legs,13-16 settle down on ground. Face remains recognizable, no wounds or gore. Do not recover to standing.',
    'wake_up': 'Get up from knockdown.1-4 lie on side/back,5-8 roll onto hip and brace one human hand,9-12 bring feet under hips and rise through crouch,13-16 regain low guard. One tail follows naturally, never a second body or limb.',
    'ring_out': 'Ring-out tumble.1-4 startled balance loss,5-9 rotate backward in air,10-12 tumble farther,13-16 compact falling pose, NEVER standing recovery. All16 complete same-size bodies visible, no fade, shrinking, blood or effects.',
    'death': 'Non-graphic exhausted defeat.1-4 guard weakens,5-8 shoulders slump and knees fold,9-12 sit then recline on side,13-16 remain motionless defeated with small breathing variation. No gore, wounds, horror, ghost, disappearance or standing recovery.',
    'spawn': 'Physical arrival.1-4 full-body descending airborne pose,5-8 lower legs toward landing,9-12 crouched landing absorption,13-16 rise into low guard. No teleportation glow, fading, particles, missing feet or opponent.',
}

COMMON = '''Use case: stylized-concept.
Asset type: Forest Arena Nabi 16-frame motion review sprite sheet, not a redesign.
Input images: Image1 is the USER-APPROVED Nabi idle's first pose, the exact style and character model master. Image2 contains the SAME approved idle art in16 poses. Both come from ONE approved source; no other art or character is a style reference.
Primary request: re-pose this exact SAME illustrated character into the motion below. Only pose/expression appropriate to motion and continuous hair/tail/ribbon follow-through may change. Keep exact face/eyes/nose/mouth, layered wavy hair clusters, bangs/bow/charm arrangement, jacket stripes, shorts/skirt layers, shoe panels, and compact proportions from Image1. Keep purple eyes, dark violet-black hair with purple highlights, exactly TWO dark triangular cat ears with pink inner fur, ONE large full dark-violet curved tail, human face/hands/feet/arms/legs, black-purple-white street fighter clothing, small gold bells and purple ribbons, signature long lavender metal claw guards on human hands. Neutral claws may retract; attacks extend guards, never replace fingers with animal paws. Adult feminine character with stylized chibi proportions, not a child.
STYLE LOCK: Same fine colored contours, smooth soft violet-gray blended shadows, restrained highlights, detailed flowing hair clusters, skin tone, material rendering, color saturation, edge sharpness and eye model as approved master. Same artist, same character model, same sitting. NO restyling, flat cel shading, chunky black outlines, different face, plastic figurine lighting, watercolor or pixel art. Keep exact head/body/limb/hand/shoe proportions and one camera/model scale across all16. Ears/tail excluded from crown-to-sole body measurement; do not shorten body to fit the tail.
Composition: square canvas, exactly4 columns x4 rows,16 genuinely DIFFERENT consecutive full-body poses, left-to-right then top-to-bottom. Attack/travel faces RIGHT with consistent slightly three-quarter side game camera; natural body turns may reveal back/side but action still right. Actual articulated limbs and torso, not translated/rotated duplicate copies. Full head/ears/tail/claws/shoes fit each cell with generous margin on ALL4 sides including fourth-row feet. Same scale across poses, entire figure at most65% of cell width/height, leave outer border. No extra limbs/ears/tails, animal muzzle, fur human limbs, paw hands/feet, digitigrade legs, copied brand emblems or unrelated weapons/props.
Background: uniform OPAQUE neutral gray RGB128 for subsequent background extraction, NO checkerboard, gradient, ground line, cast shadow, scenery, grid, label, text, watermark, opponent, impact mark, speed line, motion smear, ghost image, aura, VFX or hitbox. Visual acting only; the16 frames do not define combat timing or hit detection.
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert not (BATCH / 'generation-prompts-r01.json').exists(), 'Do not overwrite a prepared batch'
    approval = json.loads((WORK / '03_sample_approval.json').read_text())
    sample = next(r for r in approval['samples'] if r['character_id'] == 'nabi')
    assert approval['user_approved'] is True and sha(ROOT / sample['path']) == sample['sha256']
    refs = BATCH / '01_style_reference'
    refs.mkdir(parents=True)
    source = WORK / '02_samples/nabi/idle-r07-alpha.png'
    target = refs / 'approved-idle-source.png'
    shutil.copy2(source, target)
    frames = split_regions(Image.open(target))
    paths = [refs / 'style-master-pose01-matte.png', refs / 'style-master-16poses-matte.png']
    board = Image.new('RGBA', (1536, 1536), '#808080')
    for i, frame in enumerate(frames):
        assert frame.width < 384 and frame.height < 384
        board.alpha_composite(frame, ((i % 4) * 384 + (384-frame.width)//2, (i//4)*384 + (384-frame.height)//2))
    board.convert('RGB').save(paths[1])
    one = Image.new('RGBA', (384, 384), '#808080')
    one.alpha_composite(frames[0], ((384-frames[0].width)//2, (384-frames[0].height)//2))
    one.convert('RGB').save(paths[0])
    record = {'date': '2026-10-17', 'approved_idle': sample, 'source_path': str(target.relative_to(ROOT)),
              'source_sha256': sha(target), 'reference_paths': [str(p) for p in paths],
              'reference_sha256': [sha(p) for p in paths],
              'derivation': 'Same approved idle source pixels; region crops and gray matte only. No redraw or recolor.'}
    (refs / 'selection.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    entries = [e for e in json.loads((WORK / '01_baseline.json').read_text())['runtime_entries'] if e['character_id'] == 'nabi']
    assert len(entries) == 29 and {e['visual_state_id'] for e in entries} - {'idle'} == set(INTENTS)
    prompts = [{'state': e['visual_state_id'], 'intent': INTENTS[e['visual_state_id']],
                'prompt': COMMON + '\nMOTION ' + e['visual_state_id'] + ': ' + INTENTS[e['visual_state_id']],
                'referenced_image_paths': [str(p) for p in paths], 'transparent_background': False,
                'fps': e['fps'], 'loop': e['loop']} for e in entries if e['visual_state_id'] != 'idle']
    (BATCH / 'generation-prompts-r01.json').write_text(json.dumps(prompts, ensure_ascii=False, indent=2)+'\n')
    for name in ('02_drafts', '03_alpha', '04_review'):
        (BATCH / name).mkdir()
    print('NABI STYLE LOCK: approved idle unchanged, one master source, 28 prompts prepared; no runtime writes.')


if __name__ == '__main__':
    main()
