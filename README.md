Some quick notes on my setup, which might need to be modified when moving to a
different computer.

1. The `pandoc` executable is assumed to be at `/usr/local/bin/pandoc`. LaTeX
   installation is assumed to be MacTeX, and so located at
   `/Library/TeX/texbin/`. And vim is assumed to be MacVim.app.

2. In converting `.md` files, pandoc conversions are done in the document
   directory. The product is copied to `g:pandocTempDir`, which by default is
   assumed to be `~/tmp/pandoc/`; subsequent processing (e.g., of LaTeX into
   PDF) is done from `g:pandocTempDir`. (This requires copying image files to
   the `Figures/` subdirectory of `g:pandocTempDir`, and modifying the `.md`
   file accordingly.) Once typesetting is complete via LaTeX, a sound is
   played; this is `/System/Library/Sounds/Morse.aiff`, a standard Mac system
   sound.

3. When .pdf conversion is called, the conversion scripts will automatically
   open the resulting .pdf file in the app specified by `g:pandocPdfApp`, which
   by default is `/Applications/Skim.app`.

4. I assume two pandoc filters are available: <bwhelm/pandoc-reference-filter>
   and <bwhelm/Pandoc-Comment-Filter>. These are assumed to be at
   `~/Applications/pandoc/pandoc-reference-filter/internalreferences.lua` and at
   `~/Applications/pandoc/Comment-Filter/pandocCommentFilter.lua`, respectively.

    - Keybindings and textobjects are provided for working with
      Pandoc-Comment-Filter's various comments.
    - Note that the section text-object takes a count, which is the depth of
      the desired section.

5. I assume some CSL files are available:
   `~/.pandoc/chicago-fullnote-bibliography.csl` and
   `~/.pandoc/chicago-manual-of-style-16th-edition-full-in-text.csl`.
