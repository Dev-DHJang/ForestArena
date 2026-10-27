const fs=require('fs'),assert=require('node:assert/strict');
const N={},utils={findShapes:(_,root)=>[root,...root.children]};
new Function('storage','penpot','penpotUtils',fs.readFileSync(__dirname+'/penpot-audit.js','utf8'))({v08:N},{},utils);
const board={id:'root',children:[{id:'kept'}]};
assert.deepEqual(N.auditDescendants(board),[{id:'kept'}]);
board.children.push({id:'unexpected'});assert.equal(N.auditDescendants(board).length,2);
const old={id:'keep',hidden:false,fills:[{color:'#102f27',opacity:null}],children:['a','b']};
const current={children:['a','b'],fills:[{image:null,opacity:null,color:'#102f27'}],hidden:false,id:'keep'};
assert.equal(N.auditComparableShape(old),N.auditComparableShape(current));
for(const changed of [
 {...current,fills:[{color:'#ffffff',opacity:null,image:null}]},
 {...current,fills:[{color:'#102f27',opacity:.2,image:null}]},
 {...current,fills:[{color:'#102f27',opacity:null,image:'replacement'}]},
 {...current,hidden:true},
 {...current,children:['b','a']},
 {...current,id:'replacement'},
])assert.notEqual(N.auditComparableShape(old),N.auditComparableShape(changed));
new Function('storage','penpot','penpotUtils',fs.readFileSync(__dirname+'/penpot-comparisons.js','utf8'))({v08:N},{},{});
const sourceText={name:'TITLE',type:'text',characters:'친구',width:100,height:75.4,getPluginData:()=> 'true'};
const copyText={...sourceText,height:71,resize(w,h){this.width=w;this.height=h;},growType:'auto-height'};
assert.equal(N.alignComparisonText({children:[sourceText]},{children:[copyText]}).length,1);
assert.equal(copyText.height,75.4);assert.equal(copyText.growType,'fixed');assert.equal(sourceText.height,75.4);
assert.equal(N.alignComparisonText({children:[sourceText]},{children:[copyText]}).length,0);
assert.throws(()=>N.alignComparisonText({children:[sourceText]},{children:[{...copyText,height:71,characters:'다른 문구'}]}),/content differs/);
console.log(JSON.stringify({passed:true,cases:12,note:'Serialization-only differences and exactly the search root normalize; extra descendants and real preservation changes fail. Comparison text height follows source without accepting changed text.'}));
