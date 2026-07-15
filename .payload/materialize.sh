#!/usr/bin/env bash
set -euo pipefail
cat .payload/v2.part*.b64 | base64 --decode > /tmp/serverfarm-v2.tar.gz
echo '10697929f64f80eb81e2e8cca66c59d3c5a81a3f70437dfd29d6e2a1690f3b83  /tmp/serverfarm-v2.tar.gz' | sha256sum --check --status
rm -rf /tmp/campaign
mkdir -p /tmp/campaign
tar -xzf /tmp/serverfarm-v2.tar.gz -C /tmp/campaign
mkdir -p /tmp/campaign/assets/brand
base64 --decode official-serverfarm-logo.b64 > /tmp/campaign/assets/brand/serverfarm-logo.jpg
test "$(stat -c%s /tmp/campaign/assets/brand/serverfarm-logo.jpg)" -eq 4156
cat > /tmp/campaign/assets/brand/README.md <<'EOF'
# Serverfarm brand asset

- File: `serverfarm-logo.jpg`
- Source: official Serverfarm website asset
- Source URL: `https://www.serverfarmllc.com/wp-content/uploads/elementor/thumbs/Serverfarm-Logo-qqtqcc9wnm4wrmbc39le0rosoixmpaf6v0v3ul7f8u.jpg`
- Retrieval date: 2026-07-15
- Treatment: unmodified local copy used only for nominative employer identification
- Context: independent candidate vision by Russell Dudek; not affiliated with or endorsed by Serverfarm
EOF
touch /tmp/campaign/.nojekyll
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /tmp/campaign/. ./
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A
git commit -m 'Publish audited Serverfarm candidate campaign'
git push origin main
