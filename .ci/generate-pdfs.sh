#!/usr/bin/env bash
set -euo pipefail

python -m pip install --disable-pip-version-check weasyprint pypdf pillow
sudo apt-get update -qq
sudo apt-get install -y -qq poppler-utils

mkdir -p docs /tmp/serverfarm-pdf-renders
weasyprint resume.html docs/russell-dudek-serverfarm-resume.pdf
weasyprint cover-letter.html docs/russell-dudek-serverfarm-cover-letter.pdf
weasyprint interview-brief.html docs/serverfarm-interview-thesis-brief.pdf
weasyprint 120-day-plan.html docs/serverfarm-120-day-entry-plan.pdf
weasyprint campus-paralleling-review.html docs/serverfarm-campus-paralleling-review.pdf

python scripts/qa.py

for pdf in docs/*.pdf; do
  stem="$(basename "$pdf" .pdf)"
  pdftoppm -png -r 144 "$pdf" "/tmp/serverfarm-pdf-renders/$stem" >/dev/null
  test -n "$(find /tmp/serverfarm-pdf-renders -maxdepth 1 -name "$stem-*.png" -print -quit)"
done

python - <<'PY'
from pathlib import Path
from PIL import Image, ImageStat

render_dir = Path('/tmp/serverfarm-pdf-renders')
images = sorted(render_dir.glob('*.png'))
assert len(images) == 12, f'expected 12 rendered PDF pages, found {len(images)}'
for image_path in images:
    with Image.open(image_path) as image:
        assert image.width > 500 and image.height > 700, (image_path.name, image.size)
        stat = ImageStat.Stat(image.convert('L'))
        assert stat.var[0] > 1.0, f'blank or near-blank render: {image_path.name}'
print(f'verified {len(images)} rendered PDF pages')
PY

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add docs qa-results.json
git commit -m 'Add verified Serverfarm campaign PDFs'
git push origin main
