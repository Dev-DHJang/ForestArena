import fs from 'node:fs';
import path from 'node:path';
const [name]=process.argv.slice(2);
if(!name||!/^[A-Za-z0-9_.-]+$/.test(name))throw Error('Invalid export name');
const directory=path.resolve('_workspace/forestlight-ui/exports');fs.mkdirSync(directory,{recursive:true});
const source=path.join(directory,name+'.b64');
fs.writeFileSync(path.join(directory,name),Buffer.from(fs.readFileSync(source,'utf8').trim(),'base64'));
fs.unlinkSync(source);
console.log(name);
