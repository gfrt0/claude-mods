#!/usr/bin/env bash
# Batch-compress all PDFs in Zotero storage using Ghostscript.
# Preserves PDF annotations. Only replaces if compressed file is smaller and valid.
set -euo pipefail

ZOTERO_STORAGE="/mnt/c/Users/forte/Zotero/storage"
MIN_SIZE_KB=100          # skip PDFs smaller than this
GS_PRESET="/ebook"       # /screen (smallest), /ebook (good balance), /printer (higher quality)
DRY_RUN=false
VERBOSE=false

usage() {
  echo "Usage: $0 [--dry-run] [--verbose] [--preset /screen|/ebook|/printer] [--min-size KB]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --verbose)   VERBOSE=true; shift ;;
    --preset)    GS_PRESET="$2"; shift 2 ;;
    --min-size)  MIN_SIZE_KB="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *)           echo "Unknown option: $1"; usage ;;
  esac
done

command -v gs >/dev/null 2>&1 || { echo "ERROR: ghostscript (gs) not found"; exit 1; }

STATE_FILE="$HOME/.zotero-shrink-state"
touch "$STATE_FILE"

total=0
compressed=0
skipped_small=0
skipped_bigger=0
skipped_invalid=0
skipped_known=0
saved_bytes=0

min_size_bytes=$((MIN_SIZE_KB * 1024))

while IFS= read -r -d '' pdf; do
  total=$((total + 1))
  mtime=$(stat -c%Y "$pdf" 2>/dev/null) || continue
  key="${pdf}|${mtime}"

  if grep -qxF "$key" "$STATE_FILE" 2>/dev/null; then
    skipped_known=$((skipped_known + 1))
    continue
  fi

  orig_size=$(stat -c%s "$pdf")

  if [[ $orig_size -lt $min_size_bytes ]]; then
    skipped_small=$((skipped_small + 1))
    $VERBOSE && echo "SKIP (small): $(basename "$pdf")"
    grep -v "^${pdf}|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
    echo "$key" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    continue
  fi

  if $DRY_RUN; then
    echo "WOULD COMPRESS: $pdf ($(numfmt --to=iec $orig_size))"
    continue
  fi

  tmpfile=$(mktemp /tmp/zotero_shrink_XXXXXX.pdf)
  trap "rm -f '$tmpfile'" EXIT

  if ! gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dPDFSETTINGS="$GS_PRESET" \
       -dNOPAUSE -dBATCH -dQUIET \
       -sOutputFile="$tmpfile" \
       "$pdf" 2>/dev/null; then
    skipped_invalid=$((skipped_invalid + 1))
    $VERBOSE && echo "FAIL (gs error): $(basename "$pdf")"
    rm -f "$tmpfile"
    continue
  fi

  new_size=$(stat -c%s "$tmpfile")

  if [[ $new_size -lt 1024 ]]; then
    skipped_invalid=$((skipped_invalid + 1))
    $VERBOSE && echo "FAIL (too small output): $(basename "$pdf")"
    rm -f "$tmpfile"
    continue
  fi

  if [[ $new_size -ge $orig_size ]]; then
    skipped_bigger=$((skipped_bigger + 1))
    $VERBOSE && echo "SKIP (no gain): $(basename "$pdf") $(numfmt --to=iec $orig_size) -> $(numfmt --to=iec $new_size)"
    rm -f "$tmpfile"
    # Record so we don't retry next run
    grep -v "^${pdf}|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
    echo "$key" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    continue
  fi

  saved=$((orig_size - new_size))
  saved_bytes=$((saved_bytes + saved))
  compressed=$((compressed + 1))

  cp "$tmpfile" "$pdf"
  rm -f "$tmpfile"

  # Record new mtime after compression
  new_mtime=$(stat -c%Y "$pdf" 2>/dev/null) || true
  grep -v "^${pdf}|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
  echo "${pdf}|${new_mtime}" >> "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"

  pct=$((100 - (new_size * 100 / orig_size)))
  $VERBOSE && echo "OK: $(basename "$pdf" | head -c 60)  $(numfmt --to=iec $orig_size) -> $(numfmt --to=iec $new_size)  (-${pct}%)"

  if [[ $((compressed % 50)) -eq 0 ]]; then
    echo "Progress: $total files scanned, $compressed compressed, $(numfmt --to=iec $saved_bytes) saved"
  fi
done < <(find "$ZOTERO_STORAGE" -name "*.pdf" -type f -print0)

echo ""
echo "=== Summary ==="
echo "Total PDFs:        $total"
echo "Already processed: $skipped_known"
echo "Compressed:        $compressed"
echo "Skipped (small):   $skipped_small"
echo "Skipped (no gain): $skipped_bigger"
echo "Skipped (invalid): $skipped_invalid"
echo "Space saved:       $(numfmt --to=iec $saved_bytes)"
