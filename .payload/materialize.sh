#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs assets/brand

test -f assets/brand/serverfarm-logo.jpg
test "$(stat -c%s assets/brand/serverfarm-logo.jpg)" -eq 4156
cat > assets/brand/README.md <<'EOF'
# Serverfarm brand asset

- File: `serverfarm-logo.jpg`
- Source: official Serverfarm website asset
- Source URL: `https://www.serverfarmllc.com/wp-content/uploads/elementor/thumbs/Serverfarm-Logo-qqtqcc9wnm4wrmbc39le0rosoixmpaf6v0v3ul7f8u.jpg`
- Retrieval date: 2026-07-15
- Treatment: unmodified local copy used only for nominative employer identification
- Context: independent candidate vision by Russell Dudek; not affiliated with or endorsed by Serverfarm
EOF

python - <<'PY'
from pathlib import Path
p=Path('brand-intelligence.md')
s=p.read_text(encoding='utf-8')
start=s.index('## Visible company identity')
end=s.index('## Color token provenance')
replacement='''## Visible company identity
The candidate vision displays the locally committed, unmodified official Serverfarm logo above the fold, immediately paired with `Candidate vision for Data Center Campus Director - by Russell Dudek` and a clear independent-work disclaimer.

## Official logo implementation
The official asset is stored at `assets/brand/serverfarm-logo.jpg`, sourced directly from Serverfarm's public website, and used only for nominative employer identification. It is not traced, redrawn, recolored, cropped, animated or merged into candidate artwork. Provenance is recorded in `assets/brand/README.md`.

'''
p.write_text(s[:start]+replacement+s[end:],encoding='utf-8')
PY

python -m pip install --disable-pip-version-check weasyprint pypdf beautifulsoup4 playwright
weasyprint resume.html docs/russell-dudek-serverfarm-resume.pdf
weasyprint cover-letter.html docs/russell-dudek-serverfarm-cover-letter.pdf
weasyprint interview-brief.html docs/serverfarm-interview-thesis-brief.pdf
weasyprint 120-day-plan.html docs/serverfarm-120-day-entry-plan.pdf
weasyprint campus-paralleling-review.html docs/serverfarm-campus-paralleling-review.pdf
python scripts/qa.py

python -m playwright install --with-deps chromium
python -m http.server 4173 >/tmp/serverfarm-http.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
sleep 2
python - <<'PY'
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

routes=['index.html','resume.html','cover-letter.html','interview-brief.html','120-day-plan.html','campus-paralleling-review.html']
checks=[]
with sync_playwright() as p:
    browser=p.chromium.launch()
    for width,height in [(1440,900),(1280,800),(768,1024),(390,844)]:
        page=browser.new_page(viewport={'width':width,'height':height})
        for route in routes:
            page.goto('http://127.0.0.1:4173/'+route,wait_until='networkidle')
            overflow=page.evaluate('document.documentElement.scrollWidth > document.documentElement.clientWidth')
            broken=page.locator('img').evaluate_all("els => els.filter(i => !i.complete || i.naturalWidth === 0).map(i => i.getAttribute('src'))")
            assert not overflow, (route,width,height,'horizontal overflow')
            assert not broken, (route,width,height,broken)
            checks.append({'route':route,'viewport':f'{width}x{height}','overflow':False,'broken_images':[]})
        page.close()
    page=browser.new_page(viewport={'width':1280,'height':800})
    page.goto('http://127.0.0.1:4173/index.html',wait_until='networkidle')
    baseline=page.locator('#stateStatus').inner_text()
    page.locator('[data-scenario="alarm"]').click()
    alarm=page.locator('#stateStatus').inner_text()
    assert baseline != alarm and any(word in alarm.upper() for word in ('HOLD','ESCALATE'))
    assert page.locator('[data-scenario="alarm"]').get_attribute('aria-selected') == 'true'
    page.emulate_media(reduced_motion='reduce')
    animation=page.evaluate("getComputedStyle(document.querySelector('.bus.growth'),'::after').animationName")
    assert animation == 'none', animation
    browser.close()
Path('render-qa.json').write_text(json.dumps({'status':'passed','errors':[],'checks':checks,'interaction':{'baseline':baseline,'alarm':alarm},'reduced_motion_animation':animation},indent=2)+'\n',encoding='utf-8')
PY
kill "$server_pid"
trap - EXIT

touch .nojekyll
python - <<'PY'
import hashlib,json
from pathlib import Path

Path('campaign-audit.md').write_text('''# Candidate campaign audit

Status: verified package — the complete candidate-facing campaign has passed source integrity, company identity, responsive rendering, interaction, reduced motion, link, confidentiality and exact PDF page-count checks. Repository publication is complete; live GitHub Pages verification is the final gate.

## Verified publication payload
- official Serverfarm logo locally committed with authoritative provenance
- visible independent-candidate qualifier above the fold
- company-specific Campus Paralleling Board interaction and complete bus-path motion
- six routes checked at 1440×900, 1280×800, 768×1024 and 390×844
- keyboard-operable scenario state and reduced-motion behavior
- exactly two-page resume and exactly one-page cover letter
- three-page interview thesis brief
- four-page 120-day entry plan
- two-page Campus Paralleling Review
- verified contact information and reciprocal resume / cover-letter navigation
- zero forbidden private process names or recruiter-facing source-control invitations

## Live candidate vision target
https://russelldudek.github.io/serverfarm/
''',encoding='utf-8')

excluded_prefixes=('.git/','.github/','.payload/')
excluded_names={'.publisher-trigger','.publisher-status-trigger','.fast-publish-trigger'}
files=[]
for p in sorted(Path('.').rglob('*')):
    if not p.is_file():
        continue
    rel=p.as_posix()
    if rel in excluded_names or any(rel.startswith(prefix) for prefix in excluded_prefixes):
        continue
    files.append({'path':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
Path('artifact-manifest.json').write_text(json.dumps({'generated':'2026-07-15','status':'verified-package','files':files},indent=2)+'\n',encoding='utf-8')
PY

# Re-run source and PDF checks after the audit/manifest update.
python scripts/qa.py

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A
git diff --cached --quiet && exit 0
git commit -m 'Finalize verified Serverfarm campaign artifacts'
git push origin main
