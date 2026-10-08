import test from "node:test";
import assert from "node:assert/strict";
import { applyAction, validateProfile, type Profile } from "../src/profiles.js";

const fresh = (): Profile => ({schema_version: 2, first_granted: false, characters: [], accessories: [], selected_character: "", selected_accessory: "", opponent_character: "ja-hyun", accessibility: {text_scale: 1, reduce_visual_effects: false, haptics_enabled: true}});
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
