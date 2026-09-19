#!/usr/bin/env bash
# Watch Zotero storage for new/changed PDFs and auto-compress them.
# Uses polling (inotify doesn't work on WSL /mnt/c).
set -euo pipefail

ZOTERO_STORAGE="/mnt/c/Users/forte/Zotero/storage"
STATE_FILE="$HOME/.zotero-shrink-state"
POLL_INTERVAL=60         # seconds between scans
MIN_SIZE_KB=100
GS_PRESET="/ebook"
LOG_FILE="$HOME/.zotero-shrink-watcher.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"; }

command -v gs >/dev/null 2>&1 || { log "ERROR: ghostscript not found"; exit 1; }

touch "$STATE_FILE"
min_size_bytes=$((MIN_SIZE_KB * 1024))

compress_pdf() {
  local pdf="$1"
  local orig_size
  orig_size=$(stat -c%s "$pdf")

  if [[ $orig_size -lt $min_size_bytes ]]; then
    return 0
  fi

  local tmpfile
  tmpfile=$(mktemp /tmp/zotero_shrink_XXXXXX.pdf)

  if ! gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dPDFSETTINGS="$GS_PRESET" \
       -dNOPAUSE -dBATCH -dQUIET \
       -sOutputFile="$tmpfile" \
       "$pdf" 2>/dev/null; then
    rm -f "$tmpfile"
    log "FAIL: $(basename "$pdf")"
    return 1
  fi

  local new_size
  new_size=$(stat -c%s "$tmpfile")

  if [[ $new_size -lt 1024 || $new_size -ge $orig_size ]]; then
    rm -f "$tmpfile"
    return 0
  fi

  cp "$tmpfile" "$pdf"
  rm -f "$tmpfile"

  local pct=$((100 - (new_size * 100 / orig_size)))
  log "COMPRESSED: $(basename "$pdf" | head -c 60)  $(numfmt --to=iec $orig_size) -> $(numfmt --to=iec $new_size) (-${pct}%)"
}

log "Watcher started. Polling every ${POLL_INTERVAL}s."

while true; do
  # Build list of current PDFs with their modification times
  while IFS= read -r -d '' pdf; do
    mtime=$(stat -c%Y "$pdf" 2>/dev/null) || continue
    key="${pdf}|${mtime}"

    if ! grep -qxF "$key" "$STATE_FILE" 2>/dev/null; then
      # A gs failure must not take the watcher down with it (set -e).
      compress_pdf "$pdf" || true
      # Re-stat: compression rewrites the file, so the mtime recorded must be
      # the one AFTER the rewrite. Recording the pre-compression mtime makes
      # the next poll see a changed file and compress it all over again.
      mtime=$(stat -c%Y "$pdf" 2>/dev/null) || continue
      grep -v "^${pdf}|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
      echo "${pdf}|${mtime}" >> "${STATE_FILE}.tmp"
      mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  done < <(find "$ZOTERO_STORAGE" -name "*.pdf" -type f -print0 2>/dev/null)

  sleep "$POLL_INTERVAL"
done
