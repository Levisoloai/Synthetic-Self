#!/usr/bin/env bash
# build_book.sh — automate Synthetic Self one-page-per-chapter workflow
# ---
# Run from project root (same level as index.html & book.html)
# Usage:  ./build_book.sh "Gemeni- SyS.docx"
# Dependencies: pandoc, sed, awk (gawk), bash ≥ 4

set -euo pipefail

DOCX="${1:-Gemeni- SyS.docx}"           # manuscript
BOOK_DIR="book"
CHAPTER_DIR="$BOOK_DIR/chapters"
CSS="../style.css"                      # rel-path from chapter files
PDF_OUT="$BOOK_DIR/SyntheticSelf.pdf"

[[ -f "$DOCX" ]]        || { echo "❌ DOCX not found: $DOCX"; exit 1; }
command -v pandoc >/dev/null || { echo "❌ pandoc is required"; exit 1; }

echo "▶️  Cleaning /$BOOK_DIR …"
rm -rf "$BOOK_DIR"
mkdir -p "$CHAPTER_DIR"

# echo "▶️  1. Exporting full PDF → $PDF_OUT"
# pandoc "$DOCX" -o "$PDF_OUT"

echo "▶️  2. Splitting DOCX into chapters …"
pandoc "$DOCX"                 \
  --from=docx --to=html5       \
  --split-level=1              \
  --css="$CSS"                 \
  --output="$CHAPTER_DIR/chapter.html"  # pandoc auto-suffixes -01, -02 …

# ---------------------------------------------------------------------
# Helper: inject navigation bar into each chapter file
cat > "$CHAPTER_DIR/chapter-nav.tmpl" <<'HTML'
<nav class="chapter-nav" style="margin-top:3rem;text-align:center;font-family:var(--sans-serif-family)">
  <a href="__PREV__">« Prev</a> | 
  <a href="../book.html">Table of Contents</a> | 
  <a href="__NEXT__">Next »</a>
</nav>
HTML
echo "▶️  3. Adding Prev/Next navigation …"
pushd "$CHAPTER_DIR" >/dev/null
chapters=($(printf '%s\n' chapter-*.html | sort))

for i in "${!chapters[@]}"; do
  file="${chapters[$i]}"
  prev=$( [[ $i -gt 0 ]] && echo "${chapters[$((i-1))]}" || echo "#" )
  next=$( [[ $i -lt $(( ${#chapters[@]} - 1 )) ]] && echo "${chapters[$((i+1))]}" || echo "#" )

  # Build nav block with real links
  nav=$(sed "s|__PREV__|$prev|; s|__NEXT__|$next|" chapter-nav.tmpl | tr '\n' '\n')
  # Insert nav right before </body>
  awk -v nav="$nav" 'BEGIN{added=0}
       /<\/body>/ && !added {print nav; added=1}
       {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done
popd >/dev/null
rm "$CHAPTER_DIR/chapter-nav.tmpl"

# ---------------------------------------------------------------------
echo "▶️  4. Updating book.html TOC links …"
cp book.html book.html.bak   # safety first

awk '
  BEGIN { chap = 1 }
  /<li>/ { in_li = 1 }
  in_li && /<h3>/ {
      fname = sprintf("book/chapters/chapter-%02d.html", chap)
      sub(/<h3>([^<]*)<\/h3>/, "<h3><a href=\"" fname "\">\\1</a></h3>")
      chap++; in_li = 0
  }
  { print }
' book.html > book.html.tmp && mv book.html.tmp book.html

echo "✅  Done!  Chapters live in $CHAPTER_DIR, PDF in $PDF_OUT"
echo "   • book.html original backed up as book.html.bak"
echo "   • Open book.html → click a chapter to verify."