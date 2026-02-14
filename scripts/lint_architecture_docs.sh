#!/usr/bin/env bash

set -euo pipefail

DOCS=(
  "README.md"
  "CMS_Platform_Overview.md"
  "CMS_SDK_Architecture_Blueprint.md"
  "CMS_Technical_Architecture_Deep_Dive.md"
  "CMS_Feature_Based_System_Design_Blueprint.md"
  "CMS_Enterprise_SaaS_Architecture_Blueprint.md"
  "CMS_Architecture_Decision_Matrix.md"
)

DOCS_FORBIDDEN_CHECK=(
  "README.md"
  "CMS_Platform_Overview.md"
  "CMS_SDK_Architecture_Blueprint.md"
  "CMS_Technical_Architecture_Deep_Dive.md"
  "CMS_Feature_Based_System_Design_Blueprint.md"
  "CMS_Enterprise_SaaS_Architecture_Blueprint.md"
)

FORBIDDEN_PHRASES=(
  "Signed URL upload flow"
  "Direct object storage integration"
  "PostgreSQL Object Storage"
  "Backend: Serverless API functions"
  "Storage: Managed object storage"
  "## 7.1 Serverless-First"
)

errors=0

for doc in "${DOCS[@]}"; do
  if [[ ! -f "$doc" ]]; then
    echo "ERROR: missing required architecture doc: $doc"
    errors=1
  fi
done

for phrase in "${FORBIDDEN_PHRASES[@]}"; do
  if rg -n --fixed-strings "$phrase" "${DOCS_FORBIDDEN_CHECK[@]}" >/tmp/arch_lint_hits.txt; then
    echo "ERROR: forbidden phrase found: $phrase"
    cat /tmp/arch_lint_hits.txt
    errors=1
  fi
done

check_doc_markers() {
  local doc="$1"
  shift
  for marker in "$@"; do
    if ! rg -q --fixed-strings "$marker" "$doc"; then
      echo "ERROR: required marker missing in $doc: $marker"
      errors=1
    fi
  done
}

check_doc_markers "README.md" \
  "Next.js 15" \
  "Node.js/Express" \
  "Supabase Auth" \
  "RLS" \
  "Cloudinary/UploadThing" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_Platform_Overview.md" \
  "Next.js 15" \
  "Node.js/Express" \
  "Supabase" \
  "RLS" \
  "Cloudinary/UploadThing" \
  "tsvector" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_SDK_Architecture_Blueprint.md" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_Technical_Architecture_Deep_Dive.md" \
  "Supabase Auth" \
  "RLS" \
  "Cloudinary/UploadThing" \
  "tsvector" \
  "/health" \
  "cron" \
  "SLI windows" \
  "Alert trigger baseline" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_Feature_Based_System_Design_Blueprint.md" \
  "Supabase Auth" \
  "RLS" \
  "Cloudinary/UploadThing" \
  "tsvector" \
  "SLI windows" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_Enterprise_SaaS_Architecture_Blueprint.md" \
  "RLS" \
  "Cloudinary/UploadThing" \
  "tsvector" \
  "SLI windows" \
  "Alert trigger baseline" \
  "CMS_Architecture_Decision_Matrix.md"

check_doc_markers "CMS_Architecture_Decision_Matrix.md" \
  "Next.js 15" \
  "Node.js + Express" \
  "Cloudinary/UploadThing" \
  "tsvector" \
  "/health"

if [[ "$errors" -ne 0 ]]; then
  echo "Architecture documentation lint failed."
  exit 1
fi

echo "Architecture documentation lint passed."
