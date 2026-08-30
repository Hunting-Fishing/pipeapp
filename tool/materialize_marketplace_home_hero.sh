#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets_dir="$root_dir/assets/images"

materialize() {
  local variant="$1"
  local output="$assets_dir/marketplace_home_hero_${variant}.jpg"
  local parts=("$assets_dir/marketplace_home_hero_${variant}.b64."*)

  if [[ ! -e "${parts[0]}" ]]; then
    echo "Missing bundled hero payload chunks for ${variant}." >&2
    exit 1
  fi

  cat "${parts[@]}" | tr -d '\r\n' | base64 --decode > "$output"

  if [[ ! -s "$output" ]]; then
    echo "Failed to materialize ${variant} hero image." >&2
    exit 1
  fi

  # JPEG SOI/EOI guards catch truncated or misordered chunk payloads before Flutter.
  local soi eoi
  soi="$(od -An -tx1 -N2 "$output" | tr -d ' \n')"
  eoi="$(tail -c 2 "$output" | od -An -tx1 | tr -d ' \n')"
  if [[ "$soi" != "ffd8" || "$eoi" != "ffd9" ]]; then
    echo "Materialized ${variant} payload is not a complete JPEG (SOI=$soi EOI=$eoi)." >&2
    exit 1
  fi

  echo "Materialized $output ($(wc -c < "$output" | tr -d ' ') bytes)."
}

materialize desktop
materialize mobile
