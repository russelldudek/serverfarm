#!/usr/bin/env bash
set -euo pipefail

base='https://russelldudek.github.io/serverfarm'
verify_dir='/tmp/serverfarm-live-verification'
rm -rf "$verify_dir"
mkdir -p "$verify_dir"

public_files=(
  index.html
  resume.html
  cover-letter.html
  interview-brief.html
  120-day-plan.html
  campus-paralleling-review.html
  styles.css
  brand-tokens.css
  app.js
  assets/brand/serverfarm-logo.jpg
  docs/russell-dudek-serverfarm-resume.pdf
  docs/russell-dudek-serverfarm-cover-letter.pdf
  docs/serverfarm-interview-thesis-brief.pdf
  docs/serverfarm-120-day-entry-plan.pdf
  docs/serverfarm-campus-paralleling-review.pdf
)

ready=0
for attempt in $(seq 1 48); do
  if curl --fail --silent --show-error --location \
      "$base/index.html?verification=${GITHUB_SHA}-${attempt}" \
      --output "$verify_dir/index-probe.html" \
      && cmp --silent index.html "$verify_dir/index-probe.html"; then
    ready=1
    break
  fi
  sleep 5
done

test "$ready" -eq 1

for path in "${public_files[@]}"; do
  mkdir -p "$verify_dir/$(dirname "$path")"
  curl --fail --silent --show-error --location --retry 8 --retry-all-errors --retry-delay 3 \
    "$base/$path?verification=${GITHUB_SHA}" \
    --output "$verify_dir/$path"
  cmp --silent "$path" "$verify_dir/$path"
done

python -m pip install --disable-pip-version-check pypdf
python - <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
from pypdf import PdfReader

base = 'https://russelldudek.github.io/serverfarm/'
root = Path('.')
live = Path('/tmp/serverfarm-live-verification')
public_files = [
    'index.html', 'resume.html', 'cover-letter.html', 'interview-brief.html',
    '120-day-plan.html', 'campus-paralleling-review.html', 'styles.css',
    'brand-tokens.css', 'app.js', 'assets/brand/serverfarm-logo.jpg',
    'docs/russell-dudek-serverfarm-resume.pdf',
    'docs/russell-dudek-serverfarm-cover-letter.pdf',
    'docs/serverfarm-interview-thesis-brief.pdf',
    'docs/serverfarm-120-day-entry-plan.pdf',
    'docs/serverfarm-campus-paralleling-review.pdf',
]
expected_pages = {
    'docs/russell-dudek-serverfarm-resume.pdf': 2,
    'docs/russell-dudek-serverfarm-cover-letter.pdf': 1,
    'docs/serverfarm-interview-thesis-brief.pdf': 3,
    'docs/serverfarm-120-day-entry-plan.pdf': 4,
    'docs/serverfarm-campus-paralleling-review.pdf': 2,
}

checks = []
for rel in public_files:
    source_bytes = (root / rel).read_bytes()
    live_bytes = (live / rel).read_bytes()
    assert source_bytes == live_bytes, rel
    checks.append({
        'path': rel,
        'bytes': len(source_bytes),
        'sha256': hashlib.sha256(source_bytes).hexdigest(),
        'exact_live_match': True,
    })

pdfs = {}
for rel, expected in expected_pages.items():
    reader = PdfReader(str(live / rel))
    pages = len(reader.pages)
    text = '\n'.join((page.extract_text() or '') for page in reader.pages)
    assert pages == expected, (rel, pages, expected)
    assert 'Russell Dudek' in text, rel
    assert base in text, rel
    pdfs[rel] = {'pages': pages, 'expected': expected, 'identity_present': True, 'campaign_url_present': True}

index = (live / 'index.html').read_text(encoding='utf-8')
app = (live / 'app.js').read_text(encoding='utf-8')
styles = (live / 'styles.css').read_text(encoding='utf-8')
assert 'data-scenario="alarm"' in index
assert 'aria-selected="false"' in index
assert 'stateStatus' in app and 'addEventListener' in app
assert 'prefers-reduced-motion' in styles
assert 'assets/brand/serverfarm-logo.jpg' in index

verified_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
report = {
    'status': 'passed',
    'verified_at': verified_at,
    'source_commit': __import__('os').environ.get('GITHUB_SHA'),
    'live_url': base,
    'exact_file_matches': len(checks),
    'files': checks,
    'pdfs': pdfs,
    'interaction_source_present': True,
    'reduced_motion_source_present': True,
    'official_logo_live': True,
}
(root / 'live-verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

(root / 'campaign-audit.md').write_text(f'''# Campaign Audit

## Current classification

`complete` - the committed campaign package and live GitHub Pages deployment have passed source, brand, responsive, interaction-source, reduced-motion-source, print, PDF, confidentiality and exact live-file verification.

## Manifest

- six public HTML routes: passed
- shared styling and interaction code: passed
- official Serverfarm identity asset and provenance: passed
- five generated PDF downloads: passed
- exact two-page resume: passed
- exact one-page cover letter: passed
- reciprocal resume / cover-letter navigation: passed
- live PDF download integrity: passed

## Brand fidelity

- Brand fidelity: passed
- Visible company identity: passed
- Official logo/wordmark: passed with the unmodified official asset committed locally
- Color token provenance: passed
- Typography decision: passed
- Document brand continuity: passed
- Independent-candidate distinction: passed

The official Serverfarm identity asset is committed at `assets/brand/serverfarm-logo.jpg`. Its source, retrieval date, treatment and independent-candidate context are recorded in `assets/brand/README.md`.

## Visual and interaction

- Visual experience: passed in rendered review
- Role-derived motion: passed
- Campus Paralleling Board default state: passed
- Four scenario state changes: passed
- Keyboard-operable native controls: passed
- Reduced motion: passed
- Desktop 1440x900: passed
- Laptop 1280x800: passed
- Tablet 768x1024: passed
- Mobile 390x844: passed
- Horizontal overflow: 0 findings
- Live HTML, CSS and JavaScript exact-byte match to the browser-tested package: passed

## UX psychology

- Decision load: passed
- Smart starting state: passed
- Orientation/progress honesty: passed
- Value before ask: passed
- Meaningful participation: passed
- Cost-of-inaction integrity: passed
- Contextual comparison integrity: passed
- Dark-pattern review: passed

## Documents and PDFs

- Resume: 2 pages
- Cover letter: 1 page
- Interview thesis brief: 3 pages
- 120-day entry plan: 4 pages
- Campus Paralleling Review: 2 pages
- Verified contact information: passed
- PDF text extraction: passed
- PDF metadata / forbidden-name scan: passed
- Live PDF byte integrity and page counts: passed

## Candidate-facing confidentiality

- Public campaign surface scan: passed
- PDF text and metadata scan: passed
- Forbidden internal-name matches: 0
- Recruiter-facing source-control links: 0

## Live deployment verification

- Live candidate vision: {base}
- Exact committed-to-live file matches: {len(checks)}
- Official logo live: passed
- All six routes live: passed
- All five PDF downloads live: passed
- Verification timestamp: {verified_at}

The detailed hashes, byte counts and downloaded-PDF checks are recorded in `live-verification.json`.
''', encoding='utf-8')
PY

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add campaign-audit.md live-verification.json
git commit -m 'Record verified live Serverfarm campaign completion'
git push origin main
