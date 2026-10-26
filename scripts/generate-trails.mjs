// Deterministic build-time catalog. The app never has to generate its catalog on launch.
import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url), resource=new URL('Sources/TrailCore/Resources/',root);
const words=[...new Set(readFileSync(new URL('words.txt',resource),'utf8').toUpperCase().split(/\s+/).filter(w=>/^[A-Z]{3,6}$/.test(w) && !['DAN','KEN','TURD','STUPID'].includes(w)))].sort();
writeFileSync(new URL('words.txt',resource),words.join('\n')+'\n');
const index=new Map();
for(const word of words) for(let i=0;i<word.length;i++) {const key=word.slice(0,i)+'*'+word.slice(i+1);if(!index.has(key)) index.set(key,[]);index.get(key).push(word)}
function neighbors(word){const found=new Set();for(let i=0;i<word.length;i++)for(const x of index.get(word.slice(0,i)+'*'+word.slice(i+1))||[])if(x!==word)found.add(x);return [...found].sort()}
function path(start,goal){const queue=[start],parent=new Map([[start,null]]);let head=0;while(head<queue.length){const w=queue[head++];if(w===goal){const route=[];let x=goal;while(x!==null){route.push(x);x=parent.get(x)}return route.reverse()}for(const n of neighbors(w))if(!parent.has(n)){parent.set(n,w);queue.push(n)}}return null}
const authored=[['CAT','DOG'],['SUN','MAP'],['HAT','PIG'],['BED','CUP'],['BIG','HOT'],['PEN','BAG'],['RED','TOP'],['LOG','FIN'],['COLD','WARM'],['HEAD','TAIL'],['LOVE','HATE'],['FISH','BIRD'],['DARK','LIME'],['FIRE','SNOW'],['FOOT','HAND'],['MOON','STAR'],['STONE','SHARE'],['SHORE','PLATE'],['BRAIN','SPEAK'],['GRASS','GRAIN'],['LIGHT','SOUND'],['HEART','CROWN'],['SMILE','SPARE'],['BLACK','WHITE'],['PLANET','PLATES'],['STREAM','SCREAM'],['STRING','STRONG'],['SINGER','FINGER'],['SHARED','SCARED'],['GARDEN','HARDEN'],['CARTED','MARTEN']];
const puzzles=[];
function add(start,goal,route){if(!puzzles.some(p=>p.start===start&&p.goal===goal))puzzles.push({id:`${start}-${goal}`,start,goal,par:route.length-1})}
for(const [a,b]of authored){const route=path(a,b);if(route&&route.length>2)add(a,b,route)}
for(let length=3;length<=6;length++){const candidates=words.filter(w=>w.length===length);for(let i=0;i<candidates.length;i+=(length===6?1:5)){for(const offset of[7,19,37]){const start=candidates[i],goal=candidates[(i+offset)%candidates.length],route=path(start,goal);if(route&&route.length>=4&&route.length<=10)add(start,goal,route)}if(puzzles.filter(p=>p.start.length===length).length>=60)break}}
puzzles.sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
for(let length=3;length<=6;length++)if(puzzles.filter(p=>p.start.length===length).length<6)throw Error(`Too few ${length}-letter puzzles`);
writeFileSync(new URL('trails.json',resource),JSON.stringify(puzzles,null,2)+'\n');
console.log(JSON.stringify({words:words.length,trails:puzzles.length,byLength:Object.fromEntries([3,4,5,6].map(n=>[n,puzzles.filter(p=>p.start.length===n).length]))},null,2));
