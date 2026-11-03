const v=await penpot.currentFile.saveVersion('MENU09 대표3장 r01 · 승인대기');return{label:v.label,createdAt:v.createdAt,isAutosave:v.isAutosave,file:penpot.currentFile.id,revn:penpot.currentFile.revn};
