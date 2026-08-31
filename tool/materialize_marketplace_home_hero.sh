#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets_dir="$root_dir/assets/images"

validate_jpeg() {
  local variant="$1"
  local output="$assets_dir/marketplace_home_hero_${variant}.jpg"

  if [[ ! -s "$output" ]]; then
    echo "Missing tracked hero JPEG for ${variant}: $output" >&2
    exit 1
  fi

  local soi eoi
  soi="$(od -An -tx1 -N2 "$output" | tr -d ' \n')"
  eoi="$(tail -c 2 "$output" | od -An -tx1 | tr -d ' \n')"
  if [[ "$soi" != "ffd8" || "$eoi" != "ffd9" ]]; then
    echo "Tracked ${variant} hero image is not a complete JPEG (SOI=$soi EOI=$eoi)." >&2
    exit 1
  fi

  echo "Validated tracked $output ($(wc -c < "$output" | tr -d ' ') bytes)."
}

# Hero JPEGs are now committed directly and are the single source of truth.
# Historical base64 payload chunks were removed to prevent old artwork from
# silently overwriting newer approved photography during CI.
validate_jpeg desktop
validate_jpeg mobile
