if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong target');
const pages=penpotUtils.getPages();
const boards=[];
for(const p of pages){const page=penpotUtils.getPageById(p.id);for(const b of page.root.children){boards.push({page:p.name,id:b.id,name:b.name,type:b.type,width:b.width,height:b.height,childCount:b.children?.length||0});}}
const components=penpot.library.local.components.map(c=>({id:c.id,name:c.name,path:c.path}));
const source=penpotUtils.getPageByName('04_Lobby_Meta').root.children.find(b=>b.name==='SCR_03_Lobby');
const char=penpotUtils.getPageByName('04_Lobby_Meta').root.children.find(b=>b.name==='SCR_05_CharacterDetail');
return {file:{id:penpot.currentFile.id,name:penpot.currentFile.name},pages,boards,components,tokens:penpotUtils.tokenOverview(),lobby:source?penpotUtils.shapeStructure(source,2):null,character:char?penpotUtils.shapeStructure(char,2):null};
