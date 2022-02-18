" vim: set fdm=marker:
scriptencoding utf-8
" My settings that should apply only to files with filetype=pandoc.

if exists('b:loaded_pandoc_mine')
    finish
endif
let b:loaded_pandoc_mine=1

" ======================================================================= }}}
" Variables for Conversions {{{1
" ===========================================================================

if $USER !=# 'mobile'
    let b:pandoc_converting = 0  " keeps track of whether currently converting or not
    let b:pandoc_autoPDFEnabled = 0  " Turn autoPDF off by default...
    " Identify default (i.e., last) method for file conversions. If we can
    " identify the file as a presentation, initialize with beamer or revealjs;
    " otherwise initialize with pdflatex.
    let s:fileBegin = join(getline(0, 50), "\n")
    if s:fileBegin =~# '\ntransition:'
        let b:pandoc_lastConversionMethod = 'markdown-to-revealjs-pandoc-direct.py'
    elseif s:fileBegin =~# '\n- aspectratio' || s:fileBegin =~# '\ntheme'
        let b:pandoc_lastConversionMethod = 'markdown-to-beamer-pandoc-direct.py'
    else
        let b:pandoc_lastConversionMethod = 'markdown-to-PDF-pandoc-direct.py'
    endif
endif

" ======================================================================== }}}
" Key mappings {{{1
" ============================================================================

" Jump to Headers {{{2
" ---------------
" Note: `<C-U>` below does away with the count. (See :h v:count.)
noremap <buffer><silent> ]] :<C-U>call pandoc#ftplugin#JumpToHeader('n', '', v:count)<CR>
onoremap <buffer><silent> ]] :<C-U>call pandoc#ftplugin#JumpToHeader('o', '', v:count)<CR>
vnoremap <buffer><silent> ]] :<C-U>call pandoc#ftplugin#JumpToHeader('v', '', v:count)<CR>
noremap <buffer><silent> [[ :<C-U>call pandoc#ftplugin#JumpToHeader('n', 'b', v:count)<CR>
onoremap <buffer><silent> [[ :<C-U>call pandoc#ftplugin#JumpToHeader('o', 'b', v:count)<CR>
vnoremap <buffer><silent> [[ :<C-U>call pandoc#ftplugin#JumpToHeader('v', 'b', v:count)<CR>

" Fold Section {{{2
" ------------
nnoremap <buffer><silent> z3 :call pandoc#fold#foldSection(1)<CR>
nnoremap <buffer><silent> z# :call pandoc#fold#foldAllSections()<CR>
nnoremap <buffer><silent> zn# :call pandoc#fold#foldAllSectionsNested()<CR>

" for conversions {{{2
" ---------------
"  (For all of these, call the helper function with relevant command.)

if $USER !=# 'mobile'
    " Note that the `cc` mapping is to repeat the last conversion
    nnoremap <buffer><silent> <LocalLeader>cc :call pandoc#conversion#MyConvertMappingHelper("")<CR>
    inoremap <buffer><silent> <LocalLeader>cc <C-o>:call pandoc#conversion#MyConvertMappingHelper("")<CR>
    " PDF conversion
    nnoremap <buffer><silent> <LocalLeader>cP :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-PDF-LaTeX.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cP <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-PDF-LaTeX.py')<CR>
    nnoremap <buffer><silent> <LocalLeader>cp :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-PDF-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cp <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-PDF-pandoc-direct.py')<CR>
    " Diff conversion against git cache -- converts diff of current file to .pdf
    nnoremap <buffer><silent> <LocalLeader>cd :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX-diff.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cd <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX-diff.py')<CR>
    " Diff conversion against HEAD -- converts diff of current file to .pdf
    nnoremap <buffer> <LocalLeader>cD :call pandoc#conversion#MarkdownGitDiff()<CR>
    inoremap <buffer> <LocalLeader>cD :call pandoc#conversion#MarkdownGitDiff()<CR>
    " HTML conversion
    nnoremap <buffer><silent> <LocalLeader>ch :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-html-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>ch <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-html-pandoc-direct.py')<CR>
    " RevealJS conversion
    nnoremap <buffer><silent> <LocalLeader>cr :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-revealjs-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cr <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-revealjs-pandoc-direct.py')<CR>
    " LaTeX conversion
    nnoremap <buffer><silent> <LocalLeader>cl :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py')<CR>
    " LaTeX Beamer conversion
    nnoremap <buffer><silent> <LocalLeader>cb :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-beamer-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cb <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-beamer-pandoc-direct.py')<CR>
    " Word .docx conversion
    nnoremap <buffer><silent> <LocalLeader>cw :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-docx-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cw <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-docx-pandoc-direct.py')<CR>
    " Markdown conversion
    nnoremap <buffer><silent> <LocalLeader>cm :call
            \ pandoc#conversion#MyConvertMappingHelper('convert-to-markdown.py')<CR>
    nnoremap <buffer><silent> <LocalLeader>cM :call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-markdown-pandoc-direct.py')<CR>
    inoremap <buffer><silent> <LocalLeader>cM <C-o>:call
            \ pandoc#conversion#MyConvertMappingHelper('markdown-to-markdown-pandoc-direct.py')<CR>
    " Kill current conversion
    nnoremap <buffer><silent> <LocalLeader>ck :call pandoc#conversion#KillProcess()<CR>

    " Path to plugin's python conversion folder (e.g.,
    " `~/.vim/plugged/vim-pandoc-mine/pythonx/conversion/`)
    let s:pythonScriptDir = expand('<sfile>:p:h:h') . '/pythonx/conversion/'
    command! -buffer RemoveAuxFiles :execute '!'
                \ . s:pythonScriptDir . 'remove-aux-files.py'
                \ . ' ' . fnameescape(expand('%:p'))
    nnoremap <buffer><silent> <LocalLeader>cK :RemoveAuxFiles<CR>

    nnoremap <buffer><silent> <LocalLeader>ca :call pandoc#conversion#ToggleAutoPDF()<CR>
    inoremap <buffer><silent> <LocalLeader>ca <C-o>:call pandoc#conversion#ToggleAutoPDF()<CR>
endif

" Find Notes and Footnotes {{{2
" ------------------------
nnoremap <buffer><silent> <LocalLeader>fn /\]{\.\(comment\\|margin\\|fixme\\|highlight\)}/e<CR>m>F]%m<
nnoremap <buffer><silent> <LocalLeader>fN ?\]{\.[a-z]\{-}}?e<CR>m>F]%m<
nnoremap <buffer><silent> <LocalLeader>ff /\^\[<CR>m<l%m>`<
nnoremap <buffer><silent> <LocalLeader>fF ?\^\[<CR>m<l%m>`<

" Citations and Cross-References {{{2
" ------------------------------
" Find page references needing complete citations
noremap <buffer><silent> <LocalLeader>fr /(\(\d\+f\{0,2}\(, \d\+f\{0,2}\\|--\d\+\)\?\))<CR>
" Copy citation into `r` register
inoremap <buffer><silent> <LocalLeader>r <Esc>mz?@[A-z]<CR>"ryf `za
nnoremap <buffer><silent> <LocalLeader>r mz?@[A-z]<CR>"ryf `z

nnoremap <buffer><silent> <C-]> :call pandoc#references#GoToReference()<CR>

"" To break undo sequence automatically {{{2
"" ------------------------------------
"" These interfere with abbreviations if `inoremap` is used, so I'm using
"" simply `imap`.
"imap <buffer><silent> . .<C-G>u
"imap <buffer><silent> ! !<C-G>u
"imap <buffer><silent> ? ?<C-G>u
"imap <buffer><silent> ; ;<C-G>u
""imap <buffer><silent> ] ]<C-G>u
"" The following interferes with listmode.
""imap <buffer><silent> <CR> <CR><C-G>u

" List mode {{{2
" ---------
" Start with listmode on by default ... but don't toggle list mode if the
" buffer has already been loaded.
if !exists('b:listmode')
    let b:listmode=1
    call listmode#ListModeOn(0)
endif

" Miscellaneous {{{2
" -------------
" In visual and normal modes, select text to be indexed and hit <ctrl-x> ("indeX")
" vnoremap <buffer><silent> <C-x> c<i <Esc>pa><Esc>mip`i
" nnoremap <buffer><silent> <C-x> ciw<i <Esc>pa><Esc>mip`i

" Jump to corresponding line in Skim.app
if $USER !=# 'mobile'
    if has('nvim')
        command! -buffer JumpToPDF call jobstart("/usr/bin/env python3 " .
                    \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                    \ ' "' . expand('%:p') . '" ' . line(".") . " pdf", {"on_stdout":
                    \ "pandoc#conversion#DisplayMessages", "on_stderr": "pandoc#conversion#DisplayError"})
    else  " normal vim
        command! -buffer JumpToPDF call job_start("/usr/bin/env python3 " .
                    \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                    \ ' "' . expand('%:p') . '" ' . line(".") . " pdf", {"out_cb":
                    \ "pandoc#conversion#DisplayMessages", "err_cb": "pandoc#conversion#DisplayError"})
    endif
    nnoremap <buffer><silent> <LocalLeader>j :JumpToPDF<CR>
    inoremap <buffer><silent> <LocalLeader>j <C-o>:JumpToPDF<CR>
    " Open Dictionary.app with word under cursor
    nnoremap <buffer><silent> K :!open dict:///<cword><CR><CR>
endif

" Italicize/boldface current word
nnoremap <buffer><silent> <D-e> "zciw*<Esc>"zpa*<Esc>
inoremap <buffer><silent> <D-e> <Esc>"zciw*<Esc>"zpa*
vnoremap <buffer><silent> <C-e> c*<C-r>"*<Esc>gvlol
nnoremap <buffer><silent> <D-b> "zciw**<Esc>"zpa**<Esc>
inoremap <buffer><silent> <D-b> <Esc>"zciw**<Esc>"zpa**
vnoremap <buffer><silent> <C-b> c**<C-r>"**<Esc>gvlloll

" Next mapping will delete the surrounding comment, leaving the inside text.
" Note that it doesn't do any checking to see if the cursor is actually in a
" comment.
nnoremap <buffer><silent> dsn mzlT[mdh%d`dhPldf}`zh
" Next mappings allow for changing the comment type of next comment. Note that
" it doesn't do anything about checking to see where that comment is.
nnoremap <buffer><silent> csnc mz/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwcomment<Esc>`z
nnoremap <buffer><silent> csnm mz/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwmargin<Esc>`z
nnoremap <buffer><silent> csnf mz/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwfixme<Esc>`z
nnoremap <buffer><silent> csnh mz/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwhighlight<Esc>`z
nnoremap <buffer><silent> csns mz/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwsmcaps<Esc>`z

" Jump to .tex file in tmp dir
if $USER !=# 'mobile'
    nnoremap <buffer><silent> <LocalLeader>ft :call pandoc#ftplugin#JumpToTex(".tex")<CR>
    nnoremap <buffer><silent> <LocalLeader>fl :call pandoc#ftplugin#JumpToTex(".log")<CR>
endif
"}}}

" ======================================================================== }}}
" TextObjects {{{1
" ============================================================================
" If textobj-user plugin is loaded, ...
if exists('*textobj#user#plugin')
    let s:innerCitationPattern = '-\?@[[:alnum:]_][[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß_:.#$%&\-+?<>~/]*'
    let s:aroundCitationPattern = s:innerCitationPattern . '\( \[[^]]\+\]\)\?' . '\|' .
                \ '\[[^[]\{-}' . s:innerCitationPattern . '[^]]\{-}\]'
    let s:pageRangePattern = '\m\(\<p\{1,2}\.\\\? \)\?\d\+\-\{1,2}\d\+'

    call textobj#user#plugin('pandoc', {
        \   'section': {
        \       'select-a': 'a#',
        \       'select-a-function': 'pandoc#textobjects#FindAroundSection',
        \       'select-i': 'i#',
        \       'select-i-function': 'pandoc#textobjects#FindInsideSection',
        \   },
        \   'innerCitation': {
        \       'pattern': s:innerCitationPattern,
        \       'select': 'ic',
        \       'scan': 'nearest',
        \   },
        \   'aroundCitation': {
        \       'pattern': s:aroundCitationPattern,
        \       'select': 'ac',
        \       'scan': 'nearest',
        \   },
        \   'pageRange': {
        \       'pattern': s:pageRangePattern,
        \       'select': 'pr',
        \       'scan': 'nearest',
        \   },
        \   'inlineNote': {
        \       'select-a': 'an',
        \       'select-a-function': 'pandoc#textobjects#FindAroundNote',
        \       'select-i': 'in',
        \       'select-i-function': 'pandoc#textobjects#FindInsideNote',
        \   },
        \   'insideBlockNote': {
        \       'pattern': '^:\{3,} [a-z]\{2,}\n\zs\_.*\ze\n:\{3,}$',
        \       'select': 'iN',
        \       'scan': 'nearest',
        \   },
        \   'aroundBlockNote': {
        \       'pattern': '^:\{3,} [a-z]\{2,}\n\_.*\n:\{3,}$',
        \       'select': 'aN',
        \       'scan': 'nearest',
        \   },
        \   'footnote': {
        \       'select-a': 'af',
        \       'select-a-function': 'pandoc#textobjects#FindAroundFootnote',
        \       'select-i': 'if',
        \       'select-i-function': 'pandoc#textobjects#FindInsideFootnote',
        \   },
        \})
endif

" ======================================================================== }}}
" Completion Function for References/Bibliography {{{1
" ============================================================================
setlocal omnifunc=pandoc#references#MyCompletion
augroup pandoc
    autocmd!
    autocmd BufEnter *.md setlocal omnifunc=pandoc#references#MyCompletion
augroup END
" Remap ` ` so that it abbreviations are completed only when not in pop-up
" windows.
inoremap <expr><buffer><silent> <Space> pumvisible() ? " " : " "

" ======================================================================== }}}
" TOC Support {{{1
" ============================================================================
command! -buffer -nargs=* TOC call pandoc#toc#ShowTOC("<args>")

" ======================================================================== }}}
" " AutoNameFile {{{1
" " ============================================================================
" command! -buffer -nargs=* AutoNameFile call pandoc#AutoNameFile(<q-args>)

" " ======================================================================== }}}
" Folding {{{1
" ============================================================================
setlocal foldtext=pandoc#fold#FoldText()
setlocal fillchars=vert:│
setlocal fillchars+=fold:·

" ======================================================================== }}}
" Tidy Up Pandoc Documents {{{1
" ============================================================================
command! -buffer TidyPandoc call pandoc#ftplugin#TidyPandoc()

" ======================================================================== }}}
" Other {{{1
" ============================================================================
if $USER !=# 'mobile'
    setlocal equalprg=pandoc\ -t\ markdown+table_captions-simple_tables-multiline_tables-grid_tables+pipe_tables+line_blocks-fancy_lists+definition_lists+example_lists\ --wrap=none\ --from=markdown-fancy_lists\ --standalone\ --preserve-tabs
endif
" Allow wrapping past BOL and EOL when using `h` and `l`
setlocal whichwrap+=h,l
" List of characters that can cause a line break; don't want breaking at '@',
" since this marks citations/cross-references.
setlocal breakat-=@
" }}}
