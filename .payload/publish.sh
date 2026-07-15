#!/usr/bin/env bash
set -euo pipefail

archive=/tmp/serverfarm-v2.tar.gz
expected_sha='10697929f64f80eb81e2e8cca66c59d3c5a81a3f70437dfd29d6e2a1690f3b83'
cat .payload/v2.part*.b64 | base64 --decode > "$archive"
echo "$expected_sha  $archive" | sha256sum --check --status
tar -tzf "$archive" >/dev/null
rm -rf /tmp/serverfarm-campaign
mkdir -p /tmp/serverfarm-campaign
tar -xzf "$archive" -C /tmp/serverfarm-campaign

# Replace the incomplete root while preserving git metadata and the active bootstrap workflow.
find . -mindepth 1 -maxdepth 1 ! -name .git ! -name .github ! -name .payload -exec rm -rf {} +
rsync -a /tmp/serverfarm-campaign/ ./
mkdir -p assets/brand docs qa/screenshots

curl --fail --location --retry 4 --retry-delay 3 \
  'https://www.serverfarmllc.com/wp-content/uploads/elementor/thumbs/Serverfarm-Logo-qqtqcc9wnm4wrmbc39le0rosoixmpaf6v0v3ul7f8u.jpg' \
  --output assets/brand/serverfarm-logo.jpg
test "$(stat -c%s assets/brand/serverfarm-logo.jpg)" -ge 1000
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
python -m playwright install --with-deps chromium

weasyprint resume.html docs/russell-dudek-serverfarm-resume.pdf
weasyprint cover-letter.html docs/russell-dudek-serverfarm-cover-letter.pdf
weasyprint interview-brief.html docs/serverfarm-interview-thesis-brief.pdf
weasyprint 120-day-plan.html docs/serverfarm-120-day-entry-plan.pdf
weasyprint campus-paralleling-review.html docs/serverfarm-campus-paralleling-review.pdf
python scripts/qa.py

python -m http.server 4173 >/tmp/serverfarm-http.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
sleep 2
python - <<'PY'
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
base='http://127.0.0.1:4173/'
viewports=[(1440,900),(1280,800),(768,1024),(390,844)]
routes=['index.html','resume.html','cover-letter.html','interview-brief.html','120-day-plan.html','campus-paralleling-review.html']
results=[]
errors=[]
shots=Path('qa/screenshots'); shots.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch()
    for w,h in viewports:
        page=browser.new_page(viewport={'width':w,'height':h})
        console_errors=[]
        page.on('console', lambda msg, bucket=console_errors: bucket.append(msg.text) if msg.type=='error' else None)
        for route in routes:
            page.goto(base+route,wait_until='networkidle')
            overflow=page.evaluate('document.documentElement.scrollWidth > document.documentElement.clientWidth')
            broken=page.locator('img').evaluate_all("els => els.filter(i => !i.complete || i.naturalWidth === 0).map(i => i.getAttribute('src'))")
            if overflow: errors.append(f'horizontal overflow: {route} {w}x{h}')
            if broken: errors.append(f'broken images: {route} {w}x{h}: {broken}')
            safe=route.replace('.html','')
            page.screenshot(path=str(shots/f'{safe}-{w}x{h}.png'),full_page=True)
            results.append({'route':route,'viewport':f'{w}x{h}','horizontal_overflow':overflow,'broken_images':broken})
        if console_errors: errors.append(f'console errors at {w}x{h}: {console_errors}')
        page.close()

    page=browser.new_page(viewport={'width':1280,'height':800})
    page.goto(base+'index.html',wait_until='networkidle')
    baseline=page.locator('#stateStatus').inner_text()
    page.locator('[data-scenario="alarm"]').click()
    alarm=page.locator('#stateStatus').inner_text()
    selected=page.locator('[data-scenario="alarm"]').get_attribute('aria-selected')
    if alarm == baseline or not any(word in alarm for word in ('HOLD','Hold','ESCALATE','Escalate')):
        errors.append(f'interaction did not produce a hold/escalate state: baseline={baseline!r}, alarm={alarm!r}')
    if selected != 'true': errors.append('scenario ARIA state did not update')
    page.keyboard.press('Tab')
    page.emulate_media(reduced_motion='reduce')
    animation=page.evaluate("getComputedStyle(document.querySelector('.bus.growth'),'::after').animationName")
    if animation != 'none': errors.append(f'reduced-motion animation remains active: {animation}')
    page.screenshot(path=str(shots/'index-reduced-motion-1280x800.png'),full_page=True)
    page.close()
    browser.close()

report={'status':'passed' if not errors else 'failed','errors':errors,'checks':results,'interaction':{'baseline':baseline,'alarm':alarm,'aria_selected':selected},'reduced_motion_animation':animation}
Path('render-qa.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
if errors: raise SystemExit(1)
PY
kill "$server_pid"
trap - EXIT

touch .nojekyll
python - <<'PY'
import hashlib,json
from pathlib import Path
files=[]
for p in sorted(Path('.').rglob('*')):
    if p.is_file() and '.git' not in p.parts and '.payload' not in p.parts:
        files.append({'path':p.as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
Path('artifact-manifest.json').write_text(json.dumps({'generated':'2026-07-15','files':files},indent=2)+'\n',encoding='utf-8')
Path('campaign-audit.md').write_text('''# Candidate campaign audit

Status: building — the complete campaign is committed to `main`; source, documents, brand identity, responsive states, interaction, reduced motion, links, confidentiality and exact PDF page counts passed. Live Pages verification remains the final completion gate.

## Verified on the publication payload
- official Serverfarm logo locally committed with authoritative provenance
- visible independent-candidate qualifier above the fold
- company-specific Campus Paralleling Board interaction and complete bus-path motion
- six routes checked at 1440×900, 1280×800, 768×1024 and 390×844
- keyboard-operable scenario state and reduced-motion behavior
- exactly two-page resume and exactly one-page cover letter
- interview thesis brief, 120-day entry plan and Campus Paralleling Review PDFs
- verified contact information and reciprocal resume / cover-letter navigation
- zero forbidden private process names or recruiter-facing source-control invitations

## Live candidate vision target
https://russelldudek.github.io/serverfarm/
''',encoding='utf-8')
PY

# Retire the bootstrap payload and leave the stable Pages workflow from the campaign source.
rm -rf .payload .campaign-source.part*.b64 .build-trigger .github/workflows/publish.yml

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A
git commit -m 'Publish audited Serverfarm candidate campaign'
git push origin main
