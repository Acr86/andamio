#!/usr/bin/env bash
# Local mirror of the terraform.yml CI gates: fmt, validate per cloud/env,
# plus tflint and checkov when installed. CI is authoritative; this exists so
# nobody discovers a red gate after pushing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/infra/terraform"
export TF_PLUGIN_CACHE_DIR="${ROOT}/.tfcache"
mkdir -p "${TF_PLUGIN_CACHE_DIR}"

command -v terraform >/dev/null 2>&1 || { echo "terraform is required" >&2; exit 1; }

echo "==> terraform fmt"
terraform fmt -check -recursive "${TF_DIR}"

for env_dir in "${TF_DIR}"/envs/*/*/; do
  rel="${env_dir#"${ROOT}"/}"
  echo "==> validate ${rel}"
  terraform -chdir="${env_dir}" init -backend=false -input=false >/dev/null
  terraform -chdir="${env_dir}" validate
done

if command -v tflint >/dev/null 2>&1; then
  echo "==> tflint"
  tflint --init --config "${TF_DIR}/.tflint.hcl" >/dev/null
  for dir in "${TF_DIR}"/modules/*/*/ "${TF_DIR}"/envs/*/*/; do
    tflint --config "${TF_DIR}/.tflint.hcl" --chdir "${dir}"
  done
else
  echo "tflint not installed — skipped (CI runs it)"
fi

if command -v checkov >/dev/null 2>&1; then
  echo "==> checkov"
  checkov --directory "${TF_DIR}" --quiet --compact
else
  echo "checkov not installed — skipped (CI runs it)"
fi

echo "==> all terraform gates green"
