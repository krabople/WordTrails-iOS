"""Import the pinned upstream ESDB release with its official extraction tool.

Usage: python scripts/import-dictionary.py RELEASE_DIRECTORY TOOLS_DIRECTORY DB_PATH
Release: en-wl/wordlist-diff tag rel-2026.02.25
"""
import hashlib, json, os, pathlib, re, subprocess, sys
os.environ['PYTHONUTF8'] = '1'

release, tools, db = map(lambda x: pathlib.Path(x).resolve(), sys.argv[1:4])
resources = pathlib.Path(__file__).resolve().parents[1] / 'Sources/TrailCore/Resources'
tool = tools / 'scowl'
if not db.exists():
    with (release / 'scowl.txt').open('rb') as source:
        subprocess.run([sys.executable, str(tool), 'import', '--db', str(db)], stdin=source, check=True)

def extract(size):
    args = [sys.executable, str(tool), 'word-list', '--db', str(db), str(size), 'A,B,Z,C,D', '5',
            '--wo-poses=abbr', '--wo-pos-categories=nonword,special,wordpart', '--categories=', '--deaccent']
    output = subprocess.check_output(args).decode('utf-8')
    # Lowercase lexical words only: no proper names, initials, apostrophes or compounds.
    return {word.upper() for word in output.splitlines() if re.fullmatch(r'[a-z]{3,6}', word)}

accepted = extract(85)
familiar = extract(35)
legacy = set((resources / 'legacy-words-v1.txt').read_text().split())
accepted |= legacy
familiar &= accepted
for name, words in [('words.txt', accepted), ('familiar-words.txt', familiar)]:
    (resources / name).write_text('\n'.join(sorted(words))+'\n', encoding='utf-8')
(resources / 'Dictionary-Licence.txt').write_bytes((release / 'Copyright').read_bytes())
manifest = {'name':'ESDB (SCOWL)', 'release':'rel-2026.02.25',
            'source':'https://github.com/en-wl/wordlist-diff/tree/rel-2026.02.25',
            'sourceCommit':subprocess.check_output(['git','-C',str(release),'rev-parse','HEAD'],text=True).strip(),
            'sourceSha256':hashlib.sha256((release/'scowl.txt').read_bytes()).hexdigest(),
            'size':85, 'familiarSize':35, 'dialects':['American','British','Oxford British','Canadian','Australian'],
            'wordCount':len(accepted), 'familiarCount':len(familiar),
            'filter':'Lowercase ASCII lexical words, 3–6 letters; excludes abbreviation and nonword categories. Includes legacy accepted words for saved progress.'}
(resources/'dictionary-source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(manifest,indent=2))
