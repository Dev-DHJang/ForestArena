"""Replace one generated pose, preserving all other 31 candidate cells exactly."""
import copy
import hashlib
import json
from pathlib import Path
from PIL import Image

base = Path(__file__).resolve().parent
root = base.parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

old_path = base / "candidates/ja-hyun/special_scarf_sweep_barrage-r01.json"
old = json.loads(old_path.read_text())
source = base / "source/barrage-f19-r02.png"
anchors = json.loads(source.with_suffix(".anchors.json").read_text())
assert sha(source) == anchors["source_sha256"]
old_png = root / old["path"]
assert sha(old_png) == old["sha256"]
atlas = Image.open(old_png).convert("RGBA")
source_image = Image.open(source).convert("RGBA")
scale = old["conversion"]["uniform_scale"] * anchors["scale_proposal"]["source_to_previous_source_scale"]
size = (round(source_image.width * scale), round(source_image.height * scale))
resized = source_image.resize(size, Image.Resampling.LANCZOS)
sx, sy = size[0] / source_image.width, size[1] / source_image.height
x = round(64 - anchors["body_root"][0] * sx)
y = round(104 - anchors["body_root"][1] * sy)
visible = resized.getchannel("A").point(lambda n: 255 if n >= 32 else 0).getbbox()
assert visible and x + visible[0] >= 1 and y + visible[1] >= 1 and x + visible[2] <= 127 and y + visible[3] <= 127
cell = Image.new("RGBA", (128,128))
cell.alpha_composite(resized, (x,y))
index = int(anchors["global_frame_index"])
assert index == 18
box = (index % 16 * 128,index // 16 * 128,index % 16 * 128+128,index // 16 * 128+128)
atlas.paste(cell, box)
folder = base / "candidates/ja-hyun"
png = folder / "special_scarf_sweep_32f_barrage-r02.png"
atlas.save(png)
new = copy.deepcopy(old)
new["path"] = png.relative_to(root).as_posix()
new["sha256"] = sha(png)
tres = folder / "special_scarf_sweep_barrage-r02.tres"
tres.write_text((root / old["sprite_frames_path"].removeprefix("res://")).read_text().replace("res://"+old["path"],"res://"+new["path"]))
new["sprite_frames_path"] = "res://" + tres.relative_to(root).as_posix()
point = lambda p: [round(x+p[0]*sx,2),round(y+p[1]*sy,2)]
new["frame_anchors"][index] = {key: point(anchors[key]) for key in ("scarf_root","scarf_hand","body_root")}
new["frame_anchors"][index]["scarf_tips"] = [point(anchors["scarf_tips"][0]),None]
new["source_paths"].append(source.relative_to(root).as_posix())
new["source_sha256"].append(sha(source))
receipt = []
previous = Image.open(old_png).convert("RGBA")
for frame in range(32):
    bounds = (frame%16*128,frame//16*128,frame%16*128+128,frame//16*128+128)
    before = hashlib.sha256(previous.crop(bounds).tobytes()).hexdigest()
    after = hashlib.sha256(atlas.crop(bounds).tobytes()).hexdigest()
    assert (before == after) == (frame != index)
    receipt.append({"frame":frame+1,"before_rgba_sha256":before,"after_rgba_sha256":after,"changed":frame==index})
spec = {"kind":"single-generated-pose-revision","base_candidate_record":old_path.relative_to(root).as_posix(),"base_record_sha256":sha(old_path),"source_path":source.relative_to(root).as_posix(),"source_sha256":sha(source),"frame_index":index,"uniform_scale_before_pixel_rounding":scale,"canvas_size":list(size),"placement":[x,y],"body_root":new["frame_anchors"][index]["body_root"],"method":"new image_gen pose; uniform resize and whole-pose placement only; other31 cells unchanged"}
spec_path = base / "layout-r02.json"
write(spec_path,spec)
new["conversion"]["base_layout_spec_path"] = new["conversion"]["spec_path"]
new["conversion"]["base_layout_spec_sha256"] = new["conversion"]["spec_sha256"]
new["conversion"]["spec_path"] = spec_path.relative_to(root).as_posix()
new["conversion"]["spec_sha256"] = sha(spec_path)
new["conversion"]["frame_bounds"][index] = [x+visible[0],y+visible[1],x+visible[2],y+visible[3]]
new["conversion"]["single_pose_revision"] = spec
write(folder / "special_scarf_sweep_barrage-r02.json",new)
write(base / "qa/frame-preservation-r02.json",{"base_png_sha256":old["sha256"],"new_png_sha256":new["sha256"],"frames":receipt})
catalog = json.loads((base / "candidate-catalog-r01.json").read_text())
catalog["assets"] = [new]
catalog_path = base / "candidate-catalog-r02.json"
write(catalog_path,catalog)
scope = {"schema_version":1,"kind":"candidate-motion-review","catalog_sha256":sha(catalog_path),"motions":[{"character_id":"ja-hyun","motion":"special_scarf_sweep"}]}
scope_path = base / "candidate-scope-r02.json"
write(scope_path,scope)
scope_path.with_suffix(".sha256").write_text(sha(scope_path)+"\n")
print("single-pose revision: 31 unchanged RGBA cells; F19 replaced; candidate remains unregistered")
print(scope["catalog_sha256"])
