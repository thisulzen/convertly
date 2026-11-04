#!/bin/bash
set -u
format="$(/usr/bin/osascript <<'APPLESCRIPT'
set choices to {"PNG", "JPEG", "PDF", "TXT", "HTML", "RTF"}
set picked to choose from list choices with title "Convert with Convertly" with prompt "Choose an output format:" OK button name "Convert" cancel button name "Cancel"
if picked is false then return ""
return item 1 of picked
APPLESCRIPT
)"
[[ -n "$format" ]] || exit 0
failures=0
for input in "$@"; do
  [[ -f "$input" ]] || continue
  dir="$(dirname "$input")"; name="$(basename "$input")"
  stem="${name%.*}"; ext="${name##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$format" in PNG) target=png;; JPEG) target=jpeg;; PDF) target=pdf;; TXT) target=txt;; HTML) target=html;; RTF) target=rtf;; esac
  out="$dir/$stem.$target"
  [[ "$out" == "$input" ]] && out="$dir/$stem-converted.$target"
  case "$ext:$target" in
    jpg:png|jpeg:png|png:jpeg|png:pdf|jpg:pdf|jpeg:pdf|heic:png|heic:jpeg|heif:png|heif:jpeg)
      /usr/bin/sips -s format "$target" "$input" --out "$out" >/dev/null 2>&1 || failures=$((failures+1)) ;;
    txt:rtf|txt:html|rtf:txt|rtf:html|html:txt|html:rtf|doc:txt|doc:rtf|docx:txt|docx:rtf|odt:txt|odt:rtf)
      /usr/bin/textutil -convert "$target" -output "$out" "$input" >/dev/null 2>&1 || failures=$((failures+1)) ;;
    *)
      /usr/bin/osascript - "$input" "$format" <<'APPLESCRIPT'
on run argv
 display dialog "This conversion is not supported by the lightweight Finder action yet. PDF text extraction, OCR and Excel conversion require an additional converter." buttons {"OK"} default button "OK" with title "Convertly"
end run
APPLESCRIPT
      failures=$((failures+1)) ;;
  esac
done
if [[ "$failures" -eq 0 ]]; then
 /usr/bin/osascript -e 'display notification "Converted files saved beside originals." with title "Convertly"'
else
 /usr/bin/osascript -e 'display dialog "Some files could not be converted. See the supported formats in the Convertly README." buttons {"OK"} default button "OK" with title "Convertly"'
fi
