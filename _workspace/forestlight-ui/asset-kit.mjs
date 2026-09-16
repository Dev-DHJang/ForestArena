import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';

const root = process.cwd();
const out = path.join(root, 'assets/ui/forestlight-v01');
fs.mkdirSync(out, {recursive:true});
const icons = {
 leaf:'M15 49C12 22 29 12 52 12C51 36 39 55 15 49Z M16 48L42 23 M26 37L25 25 M33 31L43 32',
 light:'M12 48L35 16L30 33L53 20L33 52L36 36Z',
 heavy:'M13 18L26 11L49 32L39 44Z M33 40L20 54 M15 49L26 59 M13 17L9 30L29 49',
 special:'M32 7C39 22 47 25 56 32C41 36 37 45 32 58C25 42 19 38 8 32C22 26 27 18 32 7Z M27 26L38 32L27 39Z',
 jump:'M13 52C14 32 25 26 43 19 M30 16L47 16L44 33 M18 51L30 51 M37 46L49 46',
 dash:'M8 21L39 21C57 21 55 9 45 12 M14 32L51 32 M8 43L37 43C53 43 48 57 40 52',
 back:'M40 12L18 32L40 52 M18 32L56 32',
 close:'M15 15L49 49 M49 15L15 49',
 settings:'M32 9L39 18L50 18L48 30L55 39L44 45L40 56L29 51L17 54L14 42L6 35L15 26L17 14Z M24 31A9 9 0 1 0 42 31A9 9 0 1 0 24 31',
 check:'M12 33L26 47L53 16',
 lock:'M20 29V20A12 12 0 0 1 44 20V29 M14 29H50V55H14Z M32 39V46',
 story:'M10 13Q22 8 32 16Q44 8 54 13V50Q43 45 32 52Q20 45 10 50Z M32 16V52',
 solo:'M32 9L50 24L43 48L32 56L21 48L14 24Z M25 28L39 28',
 team:'M20 14A8 8 0 1 0 20 30A8 8 0 1 0 20 14 M44 14A8 8 0 1 0 44 30A8 8 0 1 0 44 14 M6 52Q6 32 20 34Q34 32 34 52 M34 38Q58 28 58 52',
 ai:'M14 18H50V48H14Z M24 28V33 M40 28V33 M24 41H40 M32 8V18 M7 26V41 M57 26V41',
 practice:'M32 7V57 M7 32H57 M14 32A18 18 0 1 0 50 32A18 18 0 1 0 14 32 M25 32A7 7 0 1 0 39 32A7 7 0 1 0 25 32',
 character:'M21 18A11 11 0 1 0 43 18A11 11 0 1 0 21 18 M12 56C12 29 52 29 52 56Z',
 accessory:'M10 20L22 10L42 10L54 20L32 55Z M10 20H54 M22 10L24 20L32 55 M42 10L40 20',
 shop:'M11 25L16 10H48L53 25 M9 25Q14 37 23 25Q32 37 41 25Q51 37 55 25 M14 34V55H50V34 M25 55V40H39V55',
 social:'M8 12H49V40H29L16 52V40H8Z M23 21H40 M23 30H35',
 mission:'M17 10H47V56H17Z M25 22L29 26L39 16 M25 36H39 M25 46H39',
 profile:'M10 10H54V54H10Z M24 24A8 8 0 1 0 40 24A8 8 0 1 0 24 24 M20 47Q32 31 44 47',
 play:'M22 12L51 32L22 52Z',
 pause:'M20 13V51 M44 13V51',
 seed:'M15 50C8 27 28 13 49 10C56 30 44 53 15 50Z M18 46L40 22',
 ringout:'M13 38A20 20 0 1 0 37 12 M8 8L35 35 M18 8H8V18',
 respawn:'M14 23A22 22 0 1 1 12 40 M14 8V23H29 M32 24V44 M23 34L32 24L41 34',
 eliminated:'M10 32A22 22 0 1 0 54 32A22 22 0 1 0 10 32 M17 17L47 47',
 filter:'M10 14H54L37 34V53L27 48V34Z',
 sound:'M9 25H20L34 13V51L20 39H9Z M43 23Q55 32 43 41',
 arena:'M7 25L32 12L57 25L32 38Z M7 35L32 48L57 35 M7 45L32 58L57 45',
 job:'M12 22H52V53H12Z M22 22V12H42V22 M12 34Q32 47 52 34 M30 34H34V42H30Z',
 trophy:'M20 10H44V25Q44 41 32 43Q20 41 20 25Z M20 16H9V25Q9 34 22 34 M44 16H55V25Q55 34 42 34 M32 43V53 M21 55H43'
};
const assets=[];
function add(name,w,h,body){
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
 const file=path.join(out,name+'.svg');fs.writeFileSync(file,svg);
 execFileSync('magick',['-background','none',file,path.join(out,name+'.png')]);
 assets.push({id:'IMG/forestlight/'+name,name,width:w,height:h,svg,png:'assets/ui/forestlight-v01/'+name+'.png',source:'assets/ui/forestlight-v01/'+name+'.svg',sha256:crypto.createHash('sha256').update(svg).digest('hex')});
}
const states=['default','pressed','selected','disabled'];
for(const type of ['primary','secondary','danger','tab','panel','card'])for(const state of states){
 const w=type==='panel'?640:type==='card'?360:320,h=type==='panel'?440:type==='card'?380:88;
 const base=state==='disabled'?'#DAE3DA':state==='pressed'?'#80AA70':type==='danger'?'#F3ADA0':type==='secondary'?'#91D5EF':type==='panel'||type==='card'?'#F4F9EE':'#B8DE78';
 const border=state==='selected'?'#27634D':state==='disabled'?'#AEBEAF':'#81AD8D';
 add(type+'-'+state,w,h,`<defs><linearGradient id="glass" x2="0" y2="1"><stop stop-color="#FFFFFF" stop-opacity=".9"/><stop offset="1" stop-color="${base}" stop-opacity=".92"/></linearGradient></defs><path d="M28 5H${w-46}Q${w-5} 5 ${w-5} 42V${h-28}Q${w-5} ${h-5} ${w-28} ${h-5}H46Q5 ${h-5} 5 ${h-42}V28Q5 5 28 5Z" fill="${base}" stroke="${border}" stroke-width="3"/><path d="M29 11H${w-46}Q${w-12} 11 ${w-12} 42V${h-29}Q${w-12} ${h-12} ${w-29} ${h-12}H46Q12 ${h-12} 12 ${h-42}V29Q12 11 29 11Z" fill="url(#glass)"/><path d="M${w-52} 17Q${w-12} 10 ${w-17} 51Q${w-46} 49 ${w-52} 17Z M${w-47} 22L${w-22} 44" fill="none" stroke="${border}" stroke-width="2" opacity=".72"/><path d="M25 ${h-23}L53 ${h-23}" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>${state==='selected'?'<path d="M20 35L29 44L44 26" fill="none" stroke="#27634D" stroke-width="4"/>':''}`);
}
for(const [name,d]of Object.entries(icons))add('icon-'+name,64,64,`<path d="${d}" fill="none" stroke="#183D35" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>`);
for(const name of ['light','heavy','special','jump','dash'])for(const state of states){
 const fill=state==='disabled'?'#DAE3DA':state==='pressed'?'#7CB56C':name==='special'?'#91D5EF':'#B8DE78';
 add('action-'+name+'-'+state,160,160,`<defs><radialGradient id="orb" cx=".36" cy=".22" r=".9"><stop stop-color="#FFFFFF"/><stop offset=".42" stop-color="${fill}"/><stop offset="1" stop-color="#7EBCA4"/></radialGradient></defs><circle cx="80" cy="80" r="74" fill="url(#orb)" stroke="#27634D" stroke-width="3"/><circle cx="80" cy="80" r="65" fill="none" stroke="#FFFFFF" stroke-opacity=".8" stroke-width="2"/><path d="M105 9Q149 12 149 55Q117 53 105 9Z" fill="${fill}" stroke="#27634D" stroke-width="2"/><path d="M116 20L142 46" stroke="#27634D" stroke-width="2"/><g transform="translate(42 42) scale(1.2)"><path d="${icons[name]}" fill="none" stroke="#183D35" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></g>${state==='selected'?'<circle cx="80" cy="80" r="78" fill="none" stroke="#27634D" stroke-width="3"/>':''}`);
}
for(const state of ['default','up','down','left','right','disabled']){
 let body='<circle cx="160" cy="160" r="145" fill="#F4F9EE" fill-opacity=".7" stroke="#91D5EF" stroke-width="4"/>';
 ['up','right','down','left'].forEach((dir,i)=>{body+=`<g transform="rotate(${i*90} 160 160)"><path d="M160 25Q212 79 177 129L160 144L143 129Q108 79 160 25Z" fill="${state===dir?'#79B658':state==='disabled'?'#DAE3DA':'#B8DE78'}" stroke="#27634D" stroke-width="3"/><path d="M160 55V115 M148 78L160 65L172 78" fill="none" stroke="#183D35" stroke-width="4" stroke-linecap="round"/></g>`;});
 body+='<circle cx="160" cy="160" r="19" fill="#91D5EF" stroke="#27634D" stroke-width="3"/>';add('dpad-'+state,320,320,body);
}
add('slider',440,64,'<rect x="8" y="24" width="424" height="16" rx="8" fill="#DCE7DA"/><rect x="8" y="24" width="280" height="16" rx="8" fill="#B8DE78"/><circle cx="288" cy="32" r="23" fill="#F4F9EE" stroke="#27634D" stroke-width="3"/><path d="M280 39Q275 23 298 22Q299 39 280 39Z" fill="#91D5EF"/>');
for(const on of [true,false])add('toggle-'+(on?'on':'off'),104,56,`<rect x="3" y="3" width="98" height="50" rx="25" fill="${on?'#B8DE78':'#DCE7DA'}" stroke="#81AD8D" stroke-width="2"/><circle cx="${on?76:28}" cy="28" r="20" fill="#F4F9EE" stroke="#27634D" stroke-width="2"/>`);
add('loading',320,32,'<rect x="2" y="2" width="316" height="28" rx="14" fill="#DAE7DB"/><rect x="4" y="4" width="218" height="24" rx="12" fill="#91D5EF"/><path d="M202 24Q198 9 219 7Q223 24 202 24Z" fill="#27634D"/>');
const manifest={schema_version:1,status:'produced-design-review',created_on:'2026-09-16',method:'Original hand-authored SVG geometry; PNG rendered from the same vector masters with ImageMagick.',rights:'No third-party visual assets incorporated. Wild Rift consulted only for ergonomic and information-layout principles. No legal clearance assertion.',references:['https://www.leagueoflegends.com/pl-pl/news/game-updates/sterowanie-w-wild-rift/','https://interfaceingame.com/screenshots/league-of-legends-wild-rift-controls/'],runtime_registered:false,assets:assets.map(({svg,...a})=>a)};
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(out,'asset-requirements.csv'),'asset_slot,output_path,source_path,status\n'+assets.map(a=>[a.id,a.png,a.source,'produced-design-review'].join(',')).join('\n')+'\n');
fs.writeFileSync(path.join(root,'_workspace/forestlight-ui/asset-bundle.json'),JSON.stringify(assets));
console.log(JSON.stringify({assets:assets.length,out}));
