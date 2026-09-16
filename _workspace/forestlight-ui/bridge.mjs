import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd(),evidence=path.join(root,'_workspace/forestlight-ui/exports');fs.mkdirSync(evidence,{recursive:true});
http.createServer(async(req,res)=>{
 res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Methods','GET,POST,OPTIONS');res.setHeader('Access-Control-Allow-Headers','Content-Type');res.setHeader('Access-Control-Allow-Private-Network','true');
 if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
 const url=new URL(req.url,'http://127.0.0.1:4412');
 if(req.method==='POST'&&url.pathname.startsWith('/export/')){const name=path.basename(url.pathname);if(!/^[A-Za-z0-9_.-]+$/.test(name)){res.writeHead(400);return res.end();}const chunks=[];for await(const c of req)chunks.push(c);fs.writeFileSync(path.join(evidence,name),Buffer.concat(chunks));return res.end('ok');}
 const relative=decodeURIComponent(url.pathname).replace(/^\//,'');const file=path.resolve(root,relative);const allowed=['assets/ui/forestlight-v01/','assets/character/','forest_arena/assets/quality/high/background/','_workspace/forestlight-ui/'];
 if(!file.startsWith(root+path.sep)||!allowed.some(a=>relative.startsWith(a))||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);return res.end();}
 res.setHeader('Content-Type',file.endsWith('.json')?'application/json':file.endsWith('.png')?'image/png':file.endsWith('.svg')?'image/svg+xml':'text/plain');fs.createReadStream(file).pipe(res);
}).listen(4412,'127.0.0.1',()=>console.log('Forestlight local asset bridge on 127.0.0.1:4412'));
