const S=storage.menu09;const out=[];for(const s of S.spec.scenes.filter(s=>!S.spec.base_keys.includes(s.key)))out.push(await S.make(s.key));return out;
