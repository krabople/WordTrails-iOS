// Owner-approved one-time installation of the isolated workflow. Apple secrets stay in GitHub.
import {spawnSync} from 'node:child_process';
import {mkdtempSync,readFileSync,unlinkSync,rmdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const source='krabople/WordTrails-iOS', signing='krabople/Lifetwine';
function command(args,input) {
  const result=spawnSync('gh',args,{input,encoding:'utf8',windowsHide:true});
  if(result.status!==0) throw new Error(`GitHub operation failed: ${result.stderr || result.error?.message}`);
  return result.stdout;
}
const directory=mkdtempSync(join(tmpdir(),'wordtrails-signing-'));
const key=join(directory,'source-key');
try {
  const generated=spawnSync('ssh-keygen',['-q','-t','ed25519','-N','','-C','Word Trails read-only source build key','-f',key],{encoding:'utf8',windowsHide:true});
  if(generated.status!==0) throw new Error('Could not create the source deploy key');
  command(['repo','deploy-key','add',`${key}.pub`,'--repo',source,'--title','Word Trails read-only Apple build source']);
  command(['secret','set','WORDTRAILS_SOURCE_DEPLOY_KEY','--repo',signing],readFileSync(key));
  const endpoint=`repos/${signing}/contents/.github/workflows/wordtrails-testflight.yml`;
  const existing=spawnSync('gh',['api',endpoint],{encoding:'utf8',windowsHide:true});
  if(existing.status!==0 && !existing.stderr.includes('404')) throw new Error('Could not establish whether the isolated workflow already exists');
  const sha=existing.status===0?JSON.parse(existing.stdout).sha:undefined;
  const content=readFileSync(new URL('../.github/workflows/wordtrails-testflight.yml',import.meta.url));
  const result=JSON.parse(command(['api','--method','PUT',endpoint,'--input','-'],JSON.stringify({message:'Add isolated Word Trails TestFlight workflow',content:content.toString('base64'),...(sha?{sha}:{})})));
  console.log(`Installed only .github/workflows/wordtrails-testflight.yml at ${result.commit.sha}. Existing Apple secrets stayed in GitHub.`);
} finally {
  for(const path of [key,`${key}.pub`]) {try{unlinkSync(path)}catch(error){if(error.code!=='ENOENT')throw error}}
  rmdirSync(directory);
}
