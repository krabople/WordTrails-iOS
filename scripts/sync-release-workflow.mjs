// Only the owner-approved Word Trails workflow is updated. No secret values are read.
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const endpoint='repos/krabople/Lifetwine/contents/.github/workflows/wordtrails-testflight.yml';
function gh(args,input){const r=spawnSync('gh',args,{input,encoding:'utf8',windowsHide:true});if(r.status!==0)throw Error(r.stderr||'GitHub operation failed');return JSON.parse(r.stdout)}
const existing=gh(['api',endpoint]);
const content=readFileSync(new URL('../.github/workflows/wordtrails-testflight.yml',import.meta.url)).toString('base64');
const result=gh(['api','--method','PUT',endpoint,'--input','-'],JSON.stringify({message:'Update isolated Word Trails release workflow',sha:existing.sha,content}));
console.log(`Updated only Word Trails workflow: ${result.commit.sha}`);
