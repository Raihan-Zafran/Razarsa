#!/usr/bin/env bash
# Gagal kalau ada file rahasia yang ter-commit atau pola kunci yang jelas ada di file terlacak.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

# 1. Nama file yang tidak boleh ada di repo.
if git ls-files | grep -iE '(\.jks$|\.keystore$|(^|/)key\.properties$|google-services\.json$|GoogleService-Info\.plist$|(^|/)\.env(\..*)?$|\.pem$|\.p12$|\.pfx$|keystore.*base64)' ; then
  echo "::error::File rahasia ter-commit (daftar di atas)."
  fail=1
fi

# 2. Pola kunci/token yang jelas. Nama variabel seperti RELEASE_STORE_PASSWORD tidak dihitung.
pattern='(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abp]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{32,})'
if git grep -InE "$pattern" -- . ':!pubspec.lock' ':!scripts/check-secrets.sh' ; then
  echo "::error::Ada pola kunci/token di file terlacak (daftar di atas)."
  fail=1
fi

exit $fail
