const S=storage.menu09;const b=S.boards.lobby;const bytes=await b.export({type:'png',scale:1});S.exportBytes=bytes;return{bytes:bytes.length,type:Object.prototype.toString.call(bytes)};
