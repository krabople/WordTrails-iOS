"""Screen ESDB common words with wordfreq 3.1.1. pip install wordfreq==3.1.1

Only build-time use; no runtime library or word-frequency database is shipped.
Derived familiar list and trail catalog: CC BY-SA 4.0, attribution bundled.
"""
import json,pathlib
from wordfreq import zipf_frequency
root=pathlib.Path(__file__).resolve().parents[1]
r=root/'Sources/TrailCore/Resources'
excluded={x.strip() for x in (root/'scripts/familiar-exclusions.txt').read_text(encoding='utf-8-sig').splitlines() if x and not x.startswith('#')}

included={x.strip() for x in (root/"scripts/familiar-inclusions.txt").read_text(encoding="utf-8-sig").splitlines() if x and not x.startswith("#")}

def familiar(word):
    if word in included: return True
    s=word.lower()
    if zipf_frequency(s,'en') >= (2.7 if len(s)==3 else 3.0): return True
    # Recognizable regular inflections can be much rarer than their familiar base.
    bases=[]
    if s.endswith('s'): bases += [s[:-1],s[:-2] if s.endswith('es') else '',s[:-3]+'y' if s.endswith('ies') else '']
    if s.endswith('ed'): bases += [s[:-1],s[:-2],s[:-3] if len(s)>3 and s[-3]==s[-4] else '',s[:-3]+'y' if s.endswith('ied') else '']
    if s.endswith('ing'): bases += [s[:-3],s[:-3]+'e',s[:-4] if len(s)>4 and s[-4]==s[-5] else '']
    if s.endswith('er'): bases += [s[:-2],s[:-1],s[:-3]+'y' if s.endswith('ier') else '']
    return any(base and zipf_frequency(base,'en')>=3.3 for base in bases)

words=[w for w in (r/'familiar-words-esdb.txt').read_text().split() if w not in excluded and familiar(w)]
(r/'familiar-words.txt').write_text('\n'.join(words)+'\n',encoding='utf-8')
manifest=json.loads((r/'dictionary-source.json').read_text())
manifest.update(familiarCount=len(words),familiarScreen={'package':'wordfreq 3.1.1','source':'https://github.com/rspeer/wordfreq','zipf':{'threeLetter':2.7,'other':3.0,'regularInflectionBase':3.3},'exclusions':'scripts/familiar-exclusions.txt','inclusions':'scripts/familiar-inclusions.txt','licence':'Derived familiar list and catalog CC BY-SA 4.0; see Familiar-Licence.txt'})
(r/'dictionary-source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'{len(words)} frequency-screened familiar forms')
