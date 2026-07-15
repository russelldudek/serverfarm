#!/usr/bin/env python3
from pathlib import Path
import re, json, sys, os
from pypdf import PdfReader

root = Path(__file__).resolve().parents[1]
required_paths = [
    'index.html','resume.html','cover-letter.html','interview-brief.html',
    '120-day-plan.html','campus-paralleling-review.html','styles.css',
    'brand-tokens.css','app.js','brand-intelligence.md','source-notes.md',
    'README.md','assets/brand/README.md','.github/workflows/pages.yml',
    'docs/russell-dudek-serverfarm-resume.pdf',
    'docs/russell-dudek-serverfarm-cover-letter.pdf',
    'docs/serverfarm-interview-thesis-brief.pdf',
    'docs/serverfarm-120-day-entry-plan.pdf',
    'docs/serverfarm-campus-paralleling-review.pdf'
]
errors=[]
for rel in required_paths:
    f=root/rel
    if not f.exists() or f.stat().st_size == 0:
        errors.append(f'missing/empty: {rel}')

# The workflow must materialize the official asset before CI can pass.
logo = root/'assets/brand/serverfarm-logo.jpg'
if os.getenv('GITHUB_ACTIONS') == 'true' and (not logo.exists() or logo.stat().st_size < 1000):
    errors.append('official Serverfarm identity asset missing/invalid in CI')

forbidden = re.compile(r'role[\s_-]*forge', re.I)
repo_invitation = re.compile(r'(public|campaign|source)\s+repository|github\.com/russelldudek/serverfarm', re.I)
text_suffixes={'.html','.css','.js','.md','.txt','.json','.svg','.xml','.yml','.yaml'}
for f in root.rglob('*'):
    if f.is_file() and f.suffix.lower() in text_suffixes and 'pdf-renders' not in f.parts:
        txt=f.read_text(errors='ignore')
        if forbidden.search(txt): errors.append(f'forbidden internal name: {f.relative_to(root)}')
        # Internal workflow/source records may refer to file paths, but no public source invitation or URL.
        if repo_invitation.search(txt): errors.append(f'candidate-facing repository invitation: {f.relative_to(root)}')

campaign_url='https://russelldudek.github.io/serverfarm/'
contact_values=['412.287.8640','russelldudek@gmail.com','linkedin.com/in/russelldudek',campaign_url]
accessible_links=['tel:+14122878640','mailto:russelldudek@gmail.com','https://www.linkedin.com/in/russelldudek',campaign_url]
for html in ['resume.html','cover-letter.html']:
    txt=(root/html).read_text()
    for val in contact_values:
        if val not in txt: errors.append(f'{html} missing {val}')
    for href in accessible_links:
        if href not in txt: errors.append(f'{html} missing accessible link {href}')

index=(root/'index.html').read_text()
if 'assets/brand/serverfarm-logo.jpg' not in index:
    errors.append('index missing official logo path')
if 'Candidate vision for Data Center Campus Director - by Russell Dudek' not in index:
    errors.append('index missing independent-candidate qualifier')
if 'View Cover Letter' not in (root/'resume.html').read_text(): errors.append('resume reciprocal link')
if 'View Resume' not in (root/'cover-letter.html').read_text(): errors.append('cover reciprocal link')

expected_pages={
    'russell-dudek-serverfarm-resume.pdf':2,
    'russell-dudek-serverfarm-cover-letter.pdf':1,
    'serverfarm-interview-thesis-brief.pdf':3,
    'serverfarm-120-day-entry-plan.pdf':4,
    'serverfarm-campus-paralleling-review.pdf':2,
}
pdf_checks={}
for name,count in expected_pages.items():
    p=root/'docs'/name
    if not p.exists():
        continue
    reader=PdfReader(str(p))
    pages=len(reader.pages)
    text='\n'.join((pg.extract_text() or '') for pg in reader.pages)
    metadata=' '.join(str(v) for v in (reader.metadata or {}).values())
    if pages != count: errors.append(f'{name}: {pages} pages, expected {count}')
    if forbidden.search(metadata+text): errors.append(f'forbidden internal name in pdf: {name}')
    if repo_invitation.search(metadata+text): errors.append(f'repository invitation in pdf: {name}')
    # Every printable artifact carries a discoverable candidate identity and live candidate destination.
    for val in ['Russell Dudek','412.287.8640','russelldudek@gmail.com',campaign_url]:
        if val not in text: errors.append(f'{name} missing PDF text: {val}')
    pdf_checks[name]={'pages':pages,'expected':count,'campaign_url':campaign_url in text}

result={
    'status':'passed' if not errors else 'failed',
    'errors':errors,
    'required_files':len(required_paths),
    'official_logo_present':logo.exists() and logo.stat().st_size >= 1000 if logo.exists() else False,
    'pdfs':pdf_checks,
}
(root/'qa-results.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
sys.exit(1 if errors else 0)
