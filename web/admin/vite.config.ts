import {defineConfig,type Plugin} from 'vite';
import vue from '@vitejs/plugin-vue';
// 프록시는 브라우저가 보낸 출처를 먼저 검사한 뒤 Spring 로컬 출처로 전달한다.
const localApi:Plugin={name:'local-admin-api-origin',configureServer(server){server.middlewares.use((req,res,next)=>{
  if(!req.url?.startsWith('/admin/api/'))return next();
  const origin=req.headers.origin,expected='http://'+req.headers.host;
  if((origin&&origin!==expected)||req.headers['sec-fetch-site']==='cross-site'){
    res.statusCode=403;res.setHeader('Content-Type','application/json;charset=UTF-8');res.end(JSON.stringify({error:'같은 출처에서 요청하세요.'}));return;
  }
  next();
});}};
export default defineConfig({plugins:[vue(),localApi],server:{host:'127.0.0.1',cors:false,proxy:{'/admin/api':{target:'http://127.0.0.1:8080',changeOrigin:true,configure(proxy){proxy.on('proxyReq',request=>request.setHeader('Origin','http://127.0.0.1:8080'));}}}},build:{chunkSizeWarningLimit:1100}});
