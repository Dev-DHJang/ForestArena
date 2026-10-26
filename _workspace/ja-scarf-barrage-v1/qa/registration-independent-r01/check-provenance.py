"""Independent provenance-only equivalence checks; never writes game assets."""
import hashlib
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[4]
base = root / "_workspace/ja-scarf-barrage-v1"
read = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
old_path, new_path = [base / f"candidate-catalog-r0{v}.json" for v in (3, 4)]
old, new = read(old_path), read(new_path)
assert {k:v for k,v in old.items() if k!="assets"} == {k:v for k,v in new.items() if k!="assets"}
a,b=old["assets"][0],new["assets"][0]
added=sorted(set(b)-set(a))
changed=sorted(k for k in a if a[k]!=b[k])
assert added==["creation","rights","source_path","source_sheet_sha256"]
assert changed==["source_sha256"]
assert b["source_sheet_sha256"]==a["source_sha256"]
assert b["source_path"]==a["source_paths"][0] and b["source_sha256"]==a["source_sha256"][0]
inputs=b["creation"]["source_inputs"]
assert [x["path"] for x in inputs]==a["source_paths"]
assert [x["sha256"] for x in inputs]==a["source_sha256"]
assert [x["role"] for x in inputs]==["frames 1-16","frames 17-32 before F19 correction","frame 19 replacement"]
source_files={}
for x in inputs:
    image=root/x["path"]
    assert sha(image)==x["sha256"]
    metadata=image.with_suffix(".json")
    data=read(metadata)
    assert data["source_path"]==x["path"] and data["source_sha256"]==x["sha256"]
    with Image.open(image) as im:
        assert list(im.size)==data["dimensions"] and im.mode=="RGBA"
    assert (root/data["prompt_path"]).is_file()
    for f in (image,metadata,root/data["prompt_path"]): source_files[str(f.relative_to(root))]=sha(f)
assert read(root/inputs[2]["path"].replace(".png",".json"))["global_frame_index"]==18
# Reconstruct exactly the revised F19 cell directly from its stated new source.
revision=b["conversion"]["single_pose_revision"]
with Image.open(root/inputs[2]["path"]) as im:
    resized=im.convert("RGBA").resize(tuple(revision["canvas_size"]),Image.Resampling.LANCZOS)
    expected=Image.new("RGBA",(128,128))
    expected.alpha_composite(resized,tuple(revision["placement"]))
with Image.open(root/b["path"]) as im:
    actual=im.convert("RGBA").crop((256,128,384,256))
    assert actual.tobytes()==expected.tobytes()
assert sha(root/b["path"])==b["sha256"]
assert read(root/b["conversion"]["spec_path"])["frame_index"]==18
with Image.open(root/read(root/revision["base_candidate_record"])["path"]) as before, Image.open(root/b["path"]) as after:
    changed_cells=[]
    for i in range(32):
        box=(i%16*128,i//16*128,i%16*128+128,i//16*128+128)
        if before.convert("RGBA").crop(box).tobytes()!=after.convert("RGBA").crop(box).tobytes():changed_cells.append(i)
assert changed_cells==[18]
concept=root/"assets/character/ja-hyun/concept/ja-hyun-concept-v01.png"
concept_entry=next(x for x in read(root/"assets/character/manifest.json")["assets"] if x.get("path")==str(concept.relative_to(root)))
assert sha(concept)==concept_entry["sha256"]
assert "external license verification not asserted" in concept_entry["rights"]["status"]
assert "no additional external license verification asserted" in b["rights"]["status"]
for ref in b["rights"]["references"]:assert (root/ref).is_file()
old_timeline=read(base/"qa/afterimage-timeline-r09.json")
new_timeline=read(base/"qa/registration-timeline-r02.json")
assert old_timeline["motions"]==new_timeline["motions"]
assert old_timeline["generator_sha256"]==new_timeline["generator_sha256"]
assert not new_timeline["errors"]
old_review=read(base/"qa/afterimage-review-r09/motion-review.json")
new_review=read(base/"qa/registration-review-r02/motion-review.json")
for motion in ["path","sha256","sprite_frames_path","sprite_frames_sha256","runtime_variants","expected_action","action_source","action_source_sha256","materials"]:
    assert old_review["motions"][0][motion]==new_review["motions"][0][motion]
code_hashes={}
for f,h in old_review["sources"].items():
    if f.startswith("scripts/") or f.startswith("tools/"):
        assert new_review["sources"][f]==h and sha(root/f)==h
        code_hashes[f]=h
for f,h in new_review["sources"].items():assert sha(root/f)==h
capture=read(base/"qa/afterimage-normal-r09/state-report.json")
for f,h in capture["sources"].items():
    assert sha(root/f)==h
    if f.startswith("scripts/") or f.startswith("scenes/"):code_hashes[f]=h
for f in [b["conversion"]["spec_path"],b["conversion"]["base_layout_spec_path"],"_workspace/ja-scarf-barrage-v1/pack-revision.py",str(concept.relative_to(root))]:
    source_files[f]=sha(root/f)
result={"reviewer":"afterimage_final_r09","status":"PASS","old_catalog_sha256":sha(old_path),"new_catalog_sha256":sha(new_path),"added_fields":added,"changed_fields":changed,"all_other_fields_equal":True,"original_source_hash_array_preserved":True,"source_input_roles_verified":True,"F19_cell_exactly_reconstructs_from_declared_source":True,"only_changed_base_cell":changed_cells,"motion_timelines_exactly_equal":True,"review_materials_and_sequences_equal":True,"same_product_and_tool_hashes":code_hashes,"source_files":source_files,"approval_status":"pending","runtime_installation":False}
(base/"qa/registration-independent-r01/provenance-check.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
print("PROVENANCE_EQUIVALENCE: PASS; three sources verified, F19 exact, timeline/code/pixels unchanged")
