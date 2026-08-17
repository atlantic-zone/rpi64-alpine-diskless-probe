#!/bin/sh
# Security & Confidentiality Pre-Commit Check Script
set -e

echo "🔍 Running pre-commit PII & Secrets heuristic scan..."

python3 -c "
import os, sys, re

REGEX_PATTERNS = [
    (r'BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY', 'Private Key detected'),
    (r'ssh-(ed25519|rsa)\s+AAAA[0-9A-Za-z+/=]+', 'Hardcoded SSH Public Key detected'),
    (r'(ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]+)', 'API Token/Key detected'),
    (r'\b(10\.255\.|192\.168\.)[0-9]{1,3}\.[0-9]{1,3}\b', 'Internal Private IP detected'),
]

EXCLUDE_DIRS = {'.git', 'dist', 'build', 'cache', '.cache'}

violations = []
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
    for file in files:
        filepath = os.path.join(root, file)
        if filepath.endswith(('.png', '.jpg', '.tar.gz', '.apkovl.tar.gz', '.ico', '.bin')):
            continue
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                for pattern, label in REGEX_PATTERNS:
                    if re.search(pattern, content, re.IGNORECASE):
                        violations.append(f'{filepath}: {label}')
        except Exception as e:
            pass

if violations:
    print('❌ Security/PII Scan Violations Found:')
    for v in violations:
        print(f'  - {v}')
    sys.exit(1)
else:
    print('✅ No secret or PII violations found.')
"
