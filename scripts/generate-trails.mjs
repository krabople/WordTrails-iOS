// Both graphs must agree on the minimum. Every puzzle includes a familiar-word witness.
import {readFileSync,writeFileSync} from 'node:fs';
const resource=new URL('../Sources/TrailCore/Resources/',import.meta.url);
const words=readFileSync(new URL('words.txt',resource),'utf8').trim().split(/\s+/).sort();
const familiar=new Set(readFileSync(new URL('familiar-words.txt',resource),'utf8').trim().split(/\s+/));
const buckets=new Map();
for(let i=0;i<words.length;i++)for(let j=0;j<words[i].length;j++){const w=words[i],key=w.slice(0,j)+'*'+w.slice(j+1);if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(i)}
const adjacency=words.map((w,i)=>{const out=[];for(let j=0;j<w.length;j++)for(const n of buckets.get(w.slice(0,j)+'*'+w.slice(j+1)))if(n!==i)out.push(n);return out.sort((a,b)=>a-b)});
const common=words.map(w=>familiar.has(w)),commonEdges=adjacency.map(a=>a.filter(i=>common[i]));
let seed=0x574f5244;
function random(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296}
function shuffled(input){const a=[...input];for(let i=a.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function search(start,edges,max){const dist=new Int16Array(words.length).fill(-1),parent=new Int32Array(words.length).fill(-1),q=new Int32Array(words.length);let head=0,tail=1;q[0]=start;dist[start]=0;while(head<tail){const w=q[head++];if(dist[w]>=max)continue;for(const next of edges[w])if(dist[next]<0){dist[next]=dist[w]+1;parent[next]=w;q[tail++]=next}}return{dist,parent}}
const rules={3:{min:4,max:7},4:{min:5,max:8},5:{min:6,max:9},6:{min:7,max:10}};
const target=10000,puzzles=[],counts={};
for(let length=3;length<=6;length++){
  const ids=shuffled(words.map((_,i)=>i).filter(i=>common[i]&&words[i].length===length));
  const used=new Set();let count=0,sources=0;
  for(const start of ids){
    const full=search(start,adjacency,rules[length].max),known=search(start,commonEdges,rules[length].max);
    const candidates=shuffled(ids.filter(goal=>known.dist[goal]>=rules[length].min&&known.dist[goal]<=rules[length].max&&full.dist[goal]===known.dist[goal]));
    let fromThisStart=0;
    for(const goal of candidates){const pair=[words[start],words[goal]].sort().join('-');if(used.has(pair))continue;
      const path=[];for(let n=goal;n>=0;n=known.parent[n])path.push(words[n]);path.reverse();
      puzzles.push({id:`v2-${words[start]}-${words[goal]}`,start:words[start],goal:words[goal],par:full.dist[goal]+(length>=5?2:1),minimumSteps:full.dist[goal],familiarPath:path});
      used.add(pair);count++;if(++fromThisStart>=128||count>=target)break;
    }
    sources++;if(count>=target)break;
  }
  if(count<target)throw Error(`Only ${count} qualifying ${length}-letter trails; never relax difficulty or familiarity silently.`);
  counts[length]={count,minimumSteps:rules[length].min,maximumSteps:rules[length].max,parAllowance:length>=5?2:1,sources};console.log(`${length} letters: ${count} verified trails`);
}
const catalog=shuffled(puzzles);
writeFileSync(new URL('trails.json',resource),JSON.stringify(catalog)+'\n');
writeFileSync(new URL('trail-audit.json',resource),JSON.stringify({version:2,total:catalog.length,byLength:counts,seed:'574f5244',acceptedWords:words.length,familiarWords:familiar.size,rule:'Full-dictionary shortest distance equals familiar-only shortest distance; no reverse-pair duplicates.'},null,2)+'\n');
console.log(`Wrote ${catalog.length} trails with familiar shortest-path witnesses.`);
