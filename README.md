Some quick notes on my setup, which might need to be modified when moving to a different computer.

1. The `pandoc` executable is assumed to be at `/usr/local/bin/pandoc`. LaTeX installation is assumed to be MacTeX, and so located at `/Library/TeX/texbin/`. And vim is assumed to be MacVim.app.

2. In converting `.md` files, I copy them first to `~/tmp/pandoc/`, and do the conversion from there. (This requires copying image files to `~/tmp/pandoc/Figures/`, and modifying the `.md` file accordingly.) Once typesetting is complete via LaTeX, a sound is played; this is `/System/Library/Sounds/Morse.aiff`, a standard Mac system sound.

3. I assume `Skim.app` is used for viewing `.pdfs`. Its location is assumed to be `/Applications/Skim.app`.

4. I assume two pandoc filters are available: <bwhelm/pandoc-reference-filter> and <bwhelm/Pandoc-Comment-Filter>. These are assumed to be at `~/Applications/pandoc/pandoc-reference-filter/internalreferences.py` and at `~/Applications/pandoc/Comment-Filter/pandocCommentFilter.py`, respectively.
    - Keybindings/textobjects are provided for working with Pandoc-Comment-Filter's various comments.

5. I assume some CSL files are available: `~/.pandoc/chicago-fullnote-bibliography.csl` and `~/.pandoc/chicago-manual-of-style-16th-edition-full-in-text.csl`.
