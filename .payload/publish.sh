#!/usr/bin/env bash
set -euo pipefail

cat .payload/source.part*.b64 | base64 --decode > /tmp/serverfarm-source.tar.gz
tar -tzf /tmp/serverfarm-source.tar.gz >/dev/null
mkdir -p /tmp/campaign
tar -xzf /tmp/serverfarm-source.tar.gz -C /tmp/campaign
find . -mindepth 1 -maxdepth 1 ! -name .git ! -name .github ! -name .payload -exec rm -rf {} +
rsync -a /tmp/campaign/ ./
mkdir -p assets/brand docs scripts .github/workflows
curl --fail --location --retry 3 \
  'https://www.serverfarmllc.com/wp-content/uploads/elementor/thumbs/Serverfarm-Logo-qqtqcc9wnm4wrmbc39le0rosoixmpaf6v0v3ul7f8u.jpg' \
  --output assets/brand/serverfarm-logo.jpg
test -s assets/brand/serverfarm-logo.jpg
printf '%s\n' '# Serverfarm brand asset' '' '- File: `serverfarm-logo.jpg`' '- Source: official Serverfarm website asset' '- Retrieval date: 2026-07-15' '- Treatment: unmodified local copy used for nominative identification' '- Candidate work is independent and is not endorsed by Serverfarm.' > assets/brand/README.md

python -m pip install --upgrade pip
pip install weasyprint pypdf beautifulsoup4 playwright
python -m playwright install --with-deps chromium

python - <<'PY'
from pathlib import Path
live='https://russelldudek.github.io/serverfarm/'
for path in Path('.').glob('*.html'):
    s=path.read_text(encoding='utf-8')
    s=s.replace('https://russelldudek.github.io/', live)
    s=s.replace('russelldudek.github.io/', 'russelldudek.github.io/serverfarm/')
    path.write_text(s, encoding='utf-8')
p=Path('index.html')
s=p.read_text(encoding='utf-8')
old='''<div class="company-lockup">\n              <span class="company-name">serverfarm</span>\n              <span class="company-qualifier">Independent candidate vision · Russell Dudek</span>\n            </div>'''
new='''<div class="company-lockup">\n              <img class="company-logo" src="assets/brand/serverfarm-logo.jpg" alt="Serverfarm">\n              <span class="company-qualifier">Independent candidate vision · Russell Dudek</span>\n            </div>'''
if old not in s:
    raise SystemExit('Expected identity lockup not found')
p.write_text(s.replace(old,new), encoding='utf-8')
with Path('styles.css').open('a', encoding='utf-8') as f:
    f.write('\n.company-logo{display:block;width:min(300px,72vw);height:auto;background:#fff;padding:.7rem 1rem;border-radius:.2rem;box-shadow:0 14px 35px rgba(0,0,0,.28)}\n')
PY

weasyprint resume.html docs/russell-dudek-serverfarm-resume.pdf
weasyprint cover-letter.html docs/russell-dudek-serverfarm-cover-letter.pdf
weasyprint interview-brief.html docs/serverfarm-interview-thesis-brief.pdf
weasyprint 120-day-plan.html docs/serverfarm-120-day-entry-plan.pdf
weasyprint campus-paralleling-review.html docs/serverfarm-campus-paralleling-review.pdf
python scripts/qa.py

python -m http.server 4173 >/tmp/serverfarm-http.log 2>&1 &
server_pid=$!
trap 'kill $server_pid' EXIT
sleep 2
python - <<'PY'
import json
from playwright.sync_api import sync_playwright
base='http://127.0.0.1:4173/'
viewports=[(1440,900),(1280,800),(768,1024),(390,844)]
pages=['index.html','resume.html','cover-letter.html','interview-brief.html','120-day-plan.html','campus-paralleling-review.html']
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch()
    for w,h in viewports:
        page=browser.new_page(viewport={'width':w,'height':h})
        for route in pages:
            page.goto(base+route, wait_until='networkidle')
            overflow=page.evaluate('document.documentElement.scrollWidth > document.documentElement.clientWidth')
            if overflow:
                raise SystemExit(f'horizontal overflow: {route} {w}x{h}')
            results.append({'route':route,'viewport':f'{w}x{h}','overflow':False})
        page.close()
    page=browser.new_page(viewport={'width':1280,'height':800})
    page.goto(base+'index.html', wait_until='networkidle')
    page.locator('[data-scenario="alarm"]').click()
    status=page.locator('#decision-state').inner_text()
    if 'Hold' not in status and 'Escalate' not in status:
        raise SystemExit(f'interaction did not change decision state: {status}')
    page.emulate_media(reduced_motion='reduce')
    animation=page.evaluate("getComputedStyle(document.querySelector('.flow-pulse')).animationName")
    if animation != 'none':
        raise SystemExit(f'reduced motion failed: {animation}')
    browser.close()
with open('render-qa.json','w') as f:
    json.dump({'checks':results,'interaction_state':status,'reduced_motion_animation':animation},f,indent=2)
PY
kill "$server_pid"
trap - EXIT

touch .nojekyll
python - <<'PY'
import hashlib, json
from pathlib import Path
files=[]
for p in sorted(Path('.').rglob('*')):
    if p.is_file() and '.git' not in p.parts and '.payload' not in p.parts:
        files.append({'path':p.as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
Path('artifact-manifest.json').write_text(json.dumps({'generated':'2026-07-15','files':files},indent=2)+'\n')
Path('campaign-audit.md').write_text('''# Candidate campaign completion audit\n\nStatus: building — source, documents, responsive states, interaction, reduced motion, links, confidentiality and exact PDF page counts passed on the materialized `main` payload. Live Pages verification follows deployment.\n\n## Verified\n- candidate vision and meaningful Campus Paralleling Board interaction\n- exactly two-page resume and exactly one-page cover letter\n- interview thesis brief, 120-day entry plan and Campus Paralleling Review PDFs\n- official Serverfarm identity asset locally stored with provenance\n- four responsive viewport classes and reduced-motion behavior\n- verified contact information and reciprocal resume / cover-letter navigation\n- zero forbidden private orchestration or source-repository strings in public files and PDFs\n\n## Public URL under verification\nhttps://russelldudek.github.io/serverfarm/\n''', encoding='utf-8')
PY

cat > .github/workflows/publish.yml <<'STABLE'
name: Publish candidate vision
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: .
      - id: deployment
        uses: actions/deploy-pages@v4
STABLE

rm -rf .payload .campaign-source.part*.b64 .build-trigger

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A
git commit -m 'Publish audited Serverfarm candidate campaign'
git push origin main
