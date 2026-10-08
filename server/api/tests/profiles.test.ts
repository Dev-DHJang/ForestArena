import test from "node:test";
import assert from "node:assert/strict";
import { applyAction, validateProfile, migrateProfile, type Profile } from "../src/profiles.js";

const fresh = (): Profile => ({schema_version: 3, nickname: "플레이어", minimap: {transparency: 30, marker_style: "face", show_names: true}, first_granted: false, characters: [], accessories: [], selected_character: "", selected_accessory: "", opponent_character: "ja-hyun", accessibility: {text_scale: 1, reduce_visual_effects: false, haptics_enabled: true}});
test("profile grants, free purchases, selection and accessibility preserve source", () => {
  const source = fresh();
  let p = applyAction(source, "grant_first", {id: "nabi"});
  p = applyAction(p, "purchase", {id: "yu-ran"});
  p = applyAction(p, "purchase", {id: "fixture-thorns"});
  p = applyAction(p, "select", {character: "yu-ran", accessory: "fixture-thorns", opponent: "myo-ryung"});
  p = applyAction(p, "accessibility", {text_scale: 1.3, reduce_visual_effects: true, haptics_enabled: false});
  assert.equal(source.first_granted, false);
  assert.equal(p.selected_character, "yu-ran");
  assert.equal(p.accessibility.text_scale, 1.3);
  validateProfile(p);
});
test("invalid, duplicate and unowned actions are rejected", () => {
  const p = applyAction(fresh(), "grant_first", {id: "nabi"});
  for (const [action, payload] of [
    ["grant_first", {id: "ja-hyun"}], ["purchase", {id: "nabi"}],
    ["purchase", {id: "unknown"}], ["select", {character: "yu-ran", accessory: "", opponent: "nabi"}],
    ["accessibility", {text_scale: 2, reduce_visual_effects: false, haptics_enabled: true}],
    ["reset", {}], ["select", {}],
  ]) assert.throws(() => applyAction(p, action, payload));
  assert.throws(() => validateProfile({...fresh(), schema_version: 1}));
  assert.throws(() => validateProfile({...fresh(), characters: ["nabi"]}));
  assert.throws(() => validateProfile({...fresh(), unexpected: true}));
  assert.throws(() => applyAction(fresh(), "purchase", {id: "nabi"}));
});

test("nickname and minimap actions preserve other fields and validate limits", () => {
  let p = applyAction(fresh(), "identity", {nickname: "  숲지기  "});
  assert.equal(p.nickname, "숲지기");
  p = applyAction(p, "minimap", {transparency: 90, marker_style: "dot", show_names: false});
  assert.deepEqual(p.minimap, {transparency: 90, marker_style: "dot", show_names: false});
  for (const nickname of ["", "  ", "1234567890123", "a\nb", "a\tb"]) assert.throws(() => applyAction(p, "identity", {nickname}));
  for (const transparency of [-1, 91, 1.5, "30"]) assert.throws(() => applyAction(p, "minimap", {...p.minimap, transparency}));
  assert.throws(() => applyAction(p, "minimap", {...p.minimap, marker_style: "unknown"}));
});
test("v2 migration preserves selection ownership and accessibility", () => {
  const old: Record<string, unknown> = {...applyAction(fresh(), "grant_first", {id: "nabi"}), schema_version: 2};
  delete old.nickname; delete old.minimap;
  const copy = structuredClone(old);
  const migrated = migrateProfile(old);
  assert.equal(migrated.schema_version, 3);
  assert.equal(migrated.nickname, "플레이어");
  assert.deepEqual(migrated.characters, ["nabi"]);
  assert.deepEqual(migrated.accessibility, old.accessibility);
  assert.deepEqual(old, copy);
  assert.deepEqual(migrateProfile(migrated), migrated);
  assert.throws(() => migrateProfile({...old, accessibility: null}));
});
