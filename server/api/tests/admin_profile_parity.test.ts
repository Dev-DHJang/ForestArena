import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateProfile} from '../src/profiles.js';
const cases = JSON.parse(readFileSync(new URL('../../tests/fixtures/profile-validation-fixtures.json', import.meta.url),'utf8')) as {name:string;valid:boolean;profile:unknown}[];
test('Java and TypeScript share accepted and rejected administrator profile examples',()=>{
 for(const sample of cases) {
  if(sample.valid) assert.doesNotThrow(()=>validateProfile(sample.profile), sample.name);
  else assert.throws(()=>validateProfile(sample.profile), sample.name);
 }
});
