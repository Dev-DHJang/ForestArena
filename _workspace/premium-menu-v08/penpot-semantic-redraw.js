const N=storage.v08;
N.semanticRedrawCache=N.semanticRedrawCache||{};
N.semanticUtf8=text=>{
 const out=[];for(const char of text){const n=char.codePointAt(0);if(n<128)out.push(n);else if(n<2048)out.push(192|(n>>6),128|(n&63));else if(n<65536)out.push(224|(n>>12),128|((n>>6)&63),128|(n&63));else out.push(240|(n>>18),128|((n>>12)&63),128|((n>>6)&63),128|(n&63));}return new Uint8Array(out);
};
// Text-spec hashing stays local: the existing N.sha256 endpoint accepts PNGs only.
N.semanticSha256UTF8=text=>{
 const input=N.semanticUtf8(text),size=Math.ceil((input.length+9)/64)*64,data=new Uint8Array(size),words=new Uint32Array(64);
 data.set(input);data[input.length]=128;const bits=input.length*8,high=Math.floor(bits/4294967296),low=bits>>>0;
 for(let i=0;i<4;i++){data[size-8+i]=(high>>>(24-i*8))&255;data[size-4+i]=(low>>>(24-i*8))&255;}
 const K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
 const H=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19],rotate=(n,b)=>(n>>>b)|(n<<(32-b));
 for(let offset=0;offset<size;offset+=64){
  for(let i=0;i<16;i++){const p=offset+i*4;words[i]=(data[p]<<24)|(data[p+1]<<16)|(data[p+2]<<8)|data[p+3];}
  for(let i=16;i<64;i++){const a=words[i-15],b=words[i-2],s0=rotate(a,7)^rotate(a,18)^(a>>>3),s1=rotate(b,17)^rotate(b,19)^(b>>>10);words[i]=(words[i-16]+s0+words[i-7]+s1)>>>0;}
  let [a,b,c,d,e,f,g,h]=H;
  for(let i=0;i<64;i++){const s1=rotate(e,6)^rotate(e,11)^rotate(e,25),choose=(e&f)^(~e&g),t1=(h+s1+choose+K[i]+words[i])>>>0,s0=rotate(a,2)^rotate(a,13)^rotate(a,22),majority=(a&b)^(a&c)^(b&c),t2=(s0+majority)>>>0;h=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}
  [a,b,c,d,e,f,g,h].forEach((value,i)=>H[i]=(H[i]+value)>>>0);
 }
 return H.map(value=>value.toString(16).padStart(8,'0')).join('');
};
N.semanticRedrawSignature=async change=>{
 const spec=N.spec.scenes.find(s=>s.name===change.name);if(!spec)throw Error('Semantic scene absent from the loaded spec: '+change.name);
 const serialized=JSON.stringify(spec),cached=N.semanticRedrawCache[change.name];
 const sha256=cached?.serialized===serialized?cached.sha256:N.semanticSha256UTF8(serialized);N.ensureFlags();
 if(!/^[a-f0-9]{64}$/.test(sha256))throw Error('Invalid semantic spec SHA-256: '+change.name);
 N.semanticRedrawCache[change.name]={serialized,sha256};
 return JSON.stringify({version:'semantic-redraw-v1',name:change.name,nativeSpecHash:N.nativeSpecHash(change.name),specSha256:sha256,declaredAfterSha256:change.afterSha256||null});
};
N.redrawSemanticBatch=async(changes,count=2)=>{
 N.ensureFlags();if(!Number.isInteger(count)||count<1||count>2)throw Error('Semantic redraw batch size must be 1 or 2');
 const rows=Array.isArray(changes)?changes:changes?.changedExisting;if(!Array.isArray(rows))throw Error('Provide semantic-changed-scenes.json or its changedExisting array');
 const unique=new Set(),pending=[];let completed=0;
 // Validate all requested identities before changing any native children.
 for(const row of rows){
  const change=typeof row==='string'?{name:row}:row;if(!change?.name||unique.has(change.name))throw Error('Invalid or duplicate semantic scene '+change?.name);unique.add(change.name);
  const board=N.boards[change.name];if(!board||board.name!==change.name||!board.getPluginData('v08-ready'))throw Error('Existing ready semantic source missing: '+change.name);
  const page=N.pageForExport(board);if(!page.root.children.some(b=>b.id===board.id))throw Error('Semantic source is not on its recorded original page: '+change.name);
  const signature=await N.semanticRedrawSignature(change);N.ensureFlags();
  if(board.getPluginData('v08-semantic-redraw')===signature)completed++;else pending.push({change,board,page,signature});
 }
 if(!pending.length)return {out:[],completed,total:rows.length,savedVerified:false};
 const page=pending[0].page,selected=pending.filter(item=>item.page.id===page.id).slice(0,count),out=[],invalidate=[];
 if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();
 if(penpot.selection?.length)penpot.selection=[];
 if(N.quietSemanticViewport!==false&&penpot.viewport){penpot.viewport.center={x:-3000,y:-3000};penpot.viewport.zoom=1;}
 for(const item of selected){
  N.ensureFlags();if(penpot.currentPage.id!==page.id)throw Error('Semantic source page became inactive: '+item.change.name);
  const {board,change}=item,spec=N.spec.scenes.find(s=>s.name===change.name),identity={id:board.id,x:board.x,y:board.y,w:board.width,h:board.height,ready:board.getPluginData('v08-ready')};
  const legacy=board.children.filter(child=>child.getPluginData('premium-menu-v08')!=='true').map(child=>({child,id:child.id,hidden:child.hidden}));
  const token=penpot.history.undoBlockBegin();
  try{
   for(const child of board.children.filter(child=>child.getPluginData('premium-menu-v08')==='true'))child.remove();
   // Deliberately use the currently installed portrait-aware draw wrapper.
   N.draw(board,spec);
   const own=board.children.filter(child=>child.getPluginData('premium-menu-v08')==='true');
   if(own.length!==spec.elements.length||own.some((child,i)=>child.name!==spec.elements[i].name))throw Error('Semantic native element count/order differs: '+change.name);
   for(let i=0;i<own.length;i++){
    const element=spec.elements[i],shape=own[i];
    if(element.kind==='text'&&(shape.type!=='text'||shape.characters!==element.text))throw Error('Semantic text is not editable or differs: '+change.name+' '+element.name);
    if(element.kind==='button'){const label=shape.children?.find(child=>child.name==='Label');if(label?.type!=='text'||label.characters!==element.text)throw Error('Semantic button label is not editable or differs: '+change.name+' '+element.name);}
   }
   if(board.id!==identity.id||board.x!==identity.x||board.y!==identity.y||board.width!==identity.w||board.height!==identity.h||board.getPluginData('v08-ready')!==identity.ready||!page.root.children.some(b=>b.id===board.id))throw Error('Semantic redraw changed source identity, geometry, readiness or page: '+change.name);
   for(const old of legacy)if(!board.children.some(child=>child.id===old.id)||old.child.hidden!==old.hidden)throw Error('Semantic redraw changed a preserved legacy child: '+change.name);
   const proto=N.protoMap?.[change.name];if(proto&&(proto.getPluginData('v08-fast-prepared')||proto.getPluginData('v08-wired')))invalidate.push(proto);
   completed++;out.push({name:change.name,id:board.id,page:page.name,elements:own.length,nativeSpecHash:N.nativeSpecHash(change.name),specSha256:JSON.parse(item.signature).specSha256});
  }finally{penpot.history.undoBlockFinish(token);}
 }
 // Metadata is also changed only on the active page. Existing export records and
 // media remain untouched; export helpers detect the new nativeSpecHash.
 if(invalidate.length){
  const protoPage=N.pageForExport(invalidate[0]);if(invalidate.some(board=>N.pageForExport(board).id!==protoPage.id))throw Error('Prototype invalidation spans more than one page');
  if(penpot.currentPage.id!==protoPage.id)await penpot.openPage(protoPage);N.ensureFlags();
  for(const proto of invalidate){proto.setPluginData('v08-fast-prepared','');proto.setPluginData('v08-wired','');if(N.protoFastInfo)delete N.protoFastInfo[proto.name.slice('PROTO / '.length)];}
  if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();
 }
 for(const item of selected)item.board.setPluginData('v08-semantic-redraw',item.signature);
 await N.post('semantic-redraw-progress.json',{last:out[out.length-1]?.name||null,page:page.name,completed,total:rows.length,at:new Date().toISOString(),savedVerified:false});N.ensureFlags();
 return {out,completed,total:rows.length,page:page.name,savedVerified:false};
};
return {semanticRedraw:true,mode:'foreground-await-only',batchMaximum:2,policy:'preserve-existing-source-id-and-page'};
