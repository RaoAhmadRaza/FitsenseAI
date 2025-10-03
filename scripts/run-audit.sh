#!/usr/bin/env bash
set -euo pipefail

echo "==> Flutter analyze"
flutter analyze || true

echo "==> Flutter tests"
flutter test --reporter=expanded || true

echo "==> OSV scan"
if ! command -v osv-scanner >/dev/null 2>&1; then
  echo "Installing osv-scanner locally..."
  curl -sSfL https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_$(uname -s)_$(uname -m).tar.gz | tar -xz
  chmod +x osv-scanner
  OSV=./osv-scanner
else
  OSV=osv-scanner
fi
$OSV -r . || true

echo "==> Semgrep"
python3 -m pip install --user semgrep >/dev/null 2>&1 || true
~/.local/bin/semgrep --version || semgrep --version || true
semgrep --config .semgrep/semgrep.yml --error || true

echo "==> Detect-Secrets"
python3 -m pip install --user detect-secrets >/dev/null 2>&1 || true
~/.local/bin/detect-secrets --version || detect-secrets --version || true
detect-secrets scan --all-files > .secrets.baseline.tmp || true
detect-secrets audit .secrets.baseline.tmp -n || true
echo "Baseline created at .secrets.baseline.tmp (not committed)."

echo "==> Done"