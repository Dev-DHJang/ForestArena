const p=penpotUtils.getPageByName('19_Menu_States_v08_08');
const b=p.root.children.find(b=>b.name==='MENU08 / SCR_03_Lobby / applied-myo-ryung');
const images=penpotUtils.findShapes(s=>s.fills?.some(f=>f.fillImage),b).map(s=>({id:s.id,name:s.name,hidden:s.hidden,media:s.fills.find(f=>f.fillImage).fillImage,slot:s.getPluginData('v08-image-slot')}));
const lib=penpot.library.local.components.filter(c=>c.path==='Premium Menu v08').map(c=>({id:c.id,name:c.name}));
return {images,lib,structure:penpotUtils.shapeStructure(b,1)};
