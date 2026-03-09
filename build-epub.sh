#!/bin/bash
# Build EPUB from the Netti LaTeX source
set -e

OUTDIR="$(mktemp -d)"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SRCDIR"

echo "=== Preparing source for EPUB conversion ==="

# Create a combined LaTeX file with all chapters in order
cat > "$OUTDIR/combined.tex" << 'PREAMBLE'
\documentclass{book}
\usepackage{enumitem}
\newenvironment{versebox}{\begin{quote}\itshape}{\end{quote}}
\newcommand{\stanza}{\par\medskip}
\newcommand{\ornamentbreak}{\par\begin{center}* * *\end{center}\par}
\newcommand{\pali}[1]{\textit{#1}}
\newcommand{\term}[1]{\textbf{\textit{#1}}}
\newcommand{\suttaref}[1]{(#1)}
\newcommand{\booktitle}{The Netti}
\newcommand{\booksubtitle}{How to Read What the Buddha Taught}
\newcommand{\booksubsubtitle}{A Modern Translation of the Nettippakaraṇa}
\newcommand{\seriesname}{Read the Buddha's Original Words in Modern English}
\newcommand{\authorname}{L. Lopin}
\newcommand{\translatorname}{L. Lopin}
\newcommand{\publisher}{Theravada Tipitaka Press}
\newcommand{\editionyear}{2026}
\begin{document}
PREAMBLE

# Frontmatter: preface only (skip halftitle, titlepage, copyright, dedication for epub - metadata handles that)
echo '\chapter*{Before We Begin}' >> "$OUTDIR/combined.tex"
# Strip \chapter line from preface and append the rest
sed '1d' frontmatter/preface.tex | sed '/\\cleardoublepage/d' >> "$OUTDIR/combined.tex"

# Parts and chapters in order
declare -a PARTS=(
    "PART_The Framework"
    "content/ch01-the-big-picture.tex"
    "content/ch02-the-toolkit.tex"
    "content/ch03-each-tool-in-brief.tex"
    "PART_The Sixteen Modes of Reading"
    "content/ch04-teaching.tex"
    "content/ch05-investigation.tex"
    "content/ch06-fitness.tex"
    "content/ch07-basis.tex"
    "content/ch08-four-ways.tex"
    "content/ch09-turning-back.tex"
    "content/ch10-sorting.tex"
    "content/ch11-synonyms.tex"
    "content/ch12-designation.tex"
    "content/ch13-entry.tex"
    "content/ch14-clearing.tex"
    "content/ch15-requisites.tex"
    "content/ch16-integration.tex"
    "PART_The Sixteen Modes Applied"
    "content/ch17-modes-applied.tex"
    "PART_The Five Methods"
    "content/ch18-five-methods.tex"
    "PART_Putting It All Together"
    "content/ch19-foundation.tex"
)

for item in "${PARTS[@]}"; do
    if [[ "$item" == PART_* ]]; then
        partname="${item#PART_}"
        echo "" >> "$OUTDIR/combined.tex"
        echo "\\part{$partname}" >> "$OUTDIR/combined.tex"
    else
        cat "$item" >> "$OUTDIR/combined.tex"
        echo "" >> "$OUTDIR/combined.tex"
    fi
done

# Backmatter
cat backmatter/glossary.tex >> "$OUTDIR/combined.tex"
echo "" >> "$OUTDIR/combined.tex"
cat backmatter/bibliography.tex >> "$OUTDIR/combined.tex"

echo '\end{document}' >> "$OUTDIR/combined.tex"

# Preprocess: convert \footnote to pandoc-friendly footnotes
# Also strip \index{} commands, \label{}, \ornament, \cleardoublepage
cd "$OUTDIR"

# Clean up LaTeX commands that pandoc can't handle
# First pass: remove \index with nested braces (see{...})
python3 -c "
import re
with open('combined.tex','r') as f: t=f.read()
t = re.sub(r'\\\\index\{[^{}]*(\{[^{}]*\}[^{}]*)?\}', '', t)
with open('combined.tex','w') as f: f.write(t)
"

sed -i '' \
    -e 's/\\index{[^}]*}//g' \
    -e 's/\\label{[^}]*}//g' \
    -e 's/\\ornament/\\ornamentbreak/g' \
    -e 's/\\cleardoublepage//g' \
    -e 's/\\printendnotes//g' \
    -e 's/\\printindex//g' \
    -e 's/\\addfontfeature{[^}]*}//g' \
    -e 's/\\adforn{[^}]*}//g' \
    -e 's/\\bigskip//g' \
    -e 's/\\vspace{[^}]*}//g' \
    -e 's/\\hfill//g' \
    -e 's/\\noindent//g' \
    combined.tex

echo "=== Converting to EPUB ==="

pandoc combined.tex \
    -f latex \
    -t epub3 \
    --toc \
    --toc-depth=2 \
    --split-level=2 \
    --metadata title="The Netti: How to Read What the Buddha Taught" \
    --metadata subtitle="A Modern Translation of the Nettippakaraṇa" \
    --metadata author="L. Lopin" \
    --metadata contributor="Maha Kaccayana" \
    --metadata publisher="Theravada Tipitaka Press" \
    --metadata date="2026" \
    --metadata lang="en" \
    --metadata rights="Copyright © 2026 L. Lopin. All rights reserved." \
    --metadata identifier="ISBN:9798251331912" \
    --css="$SRCDIR/epub.css" \
    -o "$SRCDIR/the-netti.epub" \
    2>&1

echo "=== Done ==="
echo "Output: $SRCDIR/the-netti.epub"

# Cleanup
rm -rf "$OUTDIR"
