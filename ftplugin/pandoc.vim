" vim: set fdm=marker foldlevel=1:
scriptencoding utf-8
" My settings that should apply only to files with filetype=pandoc.

if exists('b:loaded_pandoc_mine')
    finish
endif
let b:loaded_pandoc_mine=1

" ======================================================================= }}}
" Variables for Conversions {{{1
" ===========================================================================

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
    let b:pandoc_lastConversionMethod = 'markdown-to-PDF-LaTeX.py'
endif

" ======================================================================== }}}
" Key mappings {{{1
" ============================================================================

" Jump to Headers {{{2
" ---------------
function! s:JumpToHeader(direction, count)
    " The count indicates the level of heading to jump to
    let l:count = a:count == 0 ? 6 : a:count
    let l:cursorPos = getcurpos()
    let l:found = search('^#\{1,' . l:count . '}\s', a:direction . 'W')
    if l:found == 0
        echohl Error
        if a:direction ==# 'b'
            echo 'No previous header of level' l:count 'or below.'
        else
            echo 'No next header of level' l:count 'or below.'
        endif
        echohl None
    endif
endfunction
" Note: `<C-U>` below does away with the count. (See :h v:count.)
noremap <silent><buffer> ]] :<C-U>call <SID>JumpToHeader('', v:count)<CR>
noremap <silent><buffer> [[ :<C-U>call <SID>JumpToHeader('b', v:count)<CR>

" Fold Section {{{2
" ------------
nnoremap <buffer><silent> z3 :call pandoc#fold#foldSection(1)<CR>
nnoremap <buffer><silent> z# :call pandoc#fold#foldAllSections()<CR>
nnoremap <buffer><silent> zn# :call pandoc#fold#foldAllSectionsNested()<CR>

" for conversions {{{2
" ---------------
"  (For all of these, call the helper function with relevant command.)

" Note that the `cc` mapping is to repeat the last conversion
nnoremap <buffer><silent> <LocalLeader>cc :call pandoc#conversion#MyConvertMappingHelper("")<CR>
inoremap <buffer><silent> <LocalLeader>cc <C-o>:call pandoc#conversion#MyConvertMappingHelper("")<CR>
" PDF conversion
nnoremap <buffer><silent> <LocalLeader>cp :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
inoremap <buffer><silent> <LocalLeader>cp <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cP :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cP <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
" Diff conversion against git cache -- converts diff of current file to .pdf
nnoremap <buffer><silent> <LocalLeader>cd :call
        \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py')<CR>
inoremap <buffer><silent> <LocalLeader>cd <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py')<CR>
" Diff conversion against HEAD -- converts diff of current file to .pdf
nnoremap <buffer><silent> <LocalLeader>cD :call
        \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py',
        \ 'HEAD')<CR>
nnoremap <buffer><silent> <LocalLeader>cD <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py',
        \ 'HEAD')<CR>
" HTML conversion
nnoremap <buffer><silent> <LocalLeader>ch :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>ch <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
" RevealJS conversion
nnoremap <buffer><silent> <LocalLeader>cr :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cr <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
" LaTeX Beamer conversion
nnoremap <buffer><silent> <LocalLeader>cb :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cb <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
" Word .docx conversion
nnoremap <buffer><silent> <LocalLeader>cw :call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cw <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
" Markdown conversion
nnoremap <buffer><silent> <LocalLeader>cm :call
        \ pandoc#conversion#MyConvertMappingHelper("convert-to-markdown.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cM :call pandoc#conversion#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cM <C-o>:call
        \ pandoc#conversion#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
" Kill current conversion
nnoremap <buffer><silent> <LocalLeader>ck :call pandoc#conversion#KillProcess()<CR>

" Path to plugin's python conversion folder (e.g.,
" `~/.vim/plugged/vim-pandoc-mine/pythonx/conversion/`)
let s:pythonScriptDir = expand('<sfile>:p:h:h') . '/pythonx/conversion/'
command! RemoveAuxFiles :execute '!'
            \ . s:pythonScriptDir . 'remove-aux-files.py'
            \ . ' ' . fnameescape(expand('%:p'))
nnoremap <buffer><silent> <LocalLeader>cK :RemoveAuxFiles<CR>

nnoremap <buffer><silent> <LocalLeader>ca :call pandoc#conversion#ToggleAutoPDF()<CR>
inoremap <buffer><silent> <LocalLeader>ca <C-o>:call pandoc#conversion#ToggleAutoPDF()<CR>

nnoremap <silent><buffer> <C-]> :call pandoc#references#GoToReference()<CR>

" Find Comments and Notes {{{2
" -----------------------
nnoremap <buffer><silent> <LocalLeader>fc /\\\@<!\(\[[^[]*\]{\.[a-z]\{-}}\\|<\(!\?comment\\|highlight\\|fixme\\|margin\\|smcaps\)>\)/<CR>
nnoremap <buffer><silent> <LocalLeader>fC ?\\\@<!\(\[[^[]*\]{\.[a-z]\{-}}\\|<\(!\?comment\\|highlight\\|fixme\\|margin\\|smcaps\)>\)?<CR>
nnoremap <buffer><silent> <LocalLeader>ff /\^\[<CR>m<l%m>`<
nnoremap <buffer><silent> <LocalLeader>fF ?\^\[<CR>m<l%m>`<

" Citations {{{2
" ---------
" Find page references needing complete citations
noremap <buffer><silent> <LocalLeader>fr /(\(\d\+f\{0,2}\(, \d\+f\{0,2}\\|--\d\+\)\?\))<CR>
" Copy citation into `r` register
inoremap <buffer> <LocalLeader>y <Esc>mz?@[A-z]<CR>"ryf `za
nnoremap <buffer> <LocalLeader>y mz?@[A-z]<CR>"ryf `z

" To break undo sequence automatically {{{2
" ------------------------------------
" These interfere with abbreviations if `inoremap` is used, so I'm using
" simply `imap`.
imap <buffer><silent> . .<C-G>u
imap <buffer><silent> ! !<C-G>u
imap <buffer><silent> ? ?<C-G>u
imap <buffer><silent> ; ;<C-G>u
"imap <buffer><silent> ] ]<C-G>u
" The following interferes with listmode.
"imap <buffer><silent> <CR> <CR><C-G>u

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
if has('nvim')
    command! JumpToPDF silent call jobstart("/usr/bin/env python3 " .
                \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                \ ' "' . expand('%:p') . '" ' . line(".") . " pdf", {"on_stdout":
                \ "pandoc#conversion#DisplayMessages", "on_stderr": "pandoc#conversion#DisplayError"})
else  " normal vim
    command! JumpToPDF silent call job_start("/usr/bin/env python3 " .
                \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                \ ' "' . expand('%:p') . '" ' . line(".") . " pdf", {"out_cb":
                \ "pandoc#conversion#DisplayMessages", "err_cb": "pandoc#conversion#DisplayError"})
endif
nnoremap <buffer><silent> <LocalLeader>j :JumpToPDF<CR>
" nnoremap <buffer><silent> <LocalLeader>j :call system('/usr/bin/env python3 ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
" FIXME: Should the next line be mapped to :JumpToPDF?
inoremap <buffer><silent> <LocalLeader>j <C-o>:call system('/usr/bin/env python3 ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
" Open Dictionary.app with word under cursor
nnoremap <buffer><silent> K :!open dict:///<cword><CR><CR>
" Faster mapping to bibliography/cross-reference completion
"inoremap <buffer> <C-c> <C-x><C-u>
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
nnoremap <buffer><silent> dsc mclT[dt]hPldf}`ch
" Next mappings allow for changing the comment type of next comment. Note that
" it doesn't do anything about checking to see where that comment is.
nnoremap <buffer><silent> cscc mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwcomment<Esc>`c
nnoremap <buffer><silent> cscm mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwmargin<Esc>`c
nnoremap <buffer><silent> cscf mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwfixme<Esc>`c
nnoremap <buffer><silent> csch mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwhighlight<Esc>`c
nnoremap <buffer><silent> cscs mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwsmcaps<Esc>`c
" Jump to .tex file in tmp dir
function! s:JumpToTex(filetype) abort
    let l:fileroot = expand('%:t:r')
    if l:fileroot ==# ''
        let l:fileroot = 'temp'
    endif
    let l:filename = fnamemodify('~/tmp/pandoc/' . l:fileroot . a:filetype, ':p')
    if filereadable(l:filename)
        let l:linenum = '0'
        if a:filetype ==# '\.tex'
            let l:linenum = system('/usr/bin/env python3 ' .
                        \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                        \ ' "' . expand('%:p') . '" ' . line('.') . ' ' . a:filetype)
        endif
        execute 'tabedit ' . l:filename
        execute l:linenum
    else
        echohl Error
        echo 'Corresponding ' . a:filetype . ' file does not exist.'
        echohl None
    endif
endfunction
nnoremap <silent><buffer> <LocalLeader>ft :call <SID>JumpToTex(".tex")<CR>
nnoremap <silent><buffer> <LocalLeader>fl :call <SID>JumpToTex(".log")<CR>
"}}}

" ======================================================================== }}}
" TextObjects {{{1
" ============================================================================
" If textobj-user plugin is loaded, ...
if exists('*textobj#user#plugin')
    " Create text object for deleting/changing/etc. comments of various types
        " For tag-style inline comments:
        " \         'pattern': ['<\(comment\|margin\|fixme\|highlight\|smcaps\)>',
        " \                   '</\(comment\|margin\|fixme\|highlight\|smcaps\)>'],
        " For tag-style block Comments:
        " \         'pattern': ['<!comment>\n\n',
        " \                   '\n\n<\/!comment>'],

    let s:innerCitationPattern = '-\?@[[:alnum:]_][[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß_:.#$%&\-+?<>~/]*'
    let s:aroundCitationPattern = s:innerCitationPattern . '\( \[[^]]\+\]\)\?' . '\|' .
                \ '\[[^[]\{-}' . s:innerCitationPattern . '[^]]\{-}\]'
    let s:pageRangePattern = '\m\(\<p\{1,2}\.\\\? \)\?\d\+\-\{1,2}\d\+'

    call textobj#user#plugin('pandoc', {
        \ 'section': {
        \        'select-a': 'a#',
        \        'select-a-function': 'pandoc#textobjects#FindAroundSection',
        \        'select-i': 'i#',
        \        'select-i-function': 'pandoc#textobjects#FindInsideSection',
        \    },
        \ 'innerCitation': {
        \        'pattern': s:innerCitationPattern,
        \        'select': 'ic',
        \        'scan': 'nearest',
        \    },
        \ 'aroundCitation': {
        \        'pattern': s:aroundCitationPattern,
        \        'select': 'ac',
        \        'scan': 'nearest',
        \    },
        \ 'pageRange': {
        \        'pattern': s:pageRangePattern,
        \        'select': 'pr',
        \        'scan': 'nearest',
        \    },
        \    'inlineNote': {
        \        'pattern': ['\[',
                    \ '\]{\.\(comment\|margin\|fixme\|highlight\|smcaps\)}'],
        \        'select-a': 'an',
        \        'select-i': 'in',
        \    },
        \    'blockNote': {
        \         'pattern': ['^::: comment\n',
        \                   '\n:::$'],
        \        'select-a': 'aN',
        \        'select-i': 'iN',
        \    },
        \    'footnote': {
        \        'select-a': 'af',
        \        'select-a-function': 'pandoc#textobjects#FindAroundFootnote',
        \        'select-i': 'if',
        \        'select-i-function': 'pandoc#textobjects#FindInsideFootnote',
        \        'scan': 'nearest',
        \    },
        \ })
endif

" ======================================================================== }}}
" Completion Function for References/Bibliography {{{1
" ============================================================================
setlocal omnifunc=pandoc#references#MyCompletion

" ======================================================================== }}}
" TOC Support {{{1
" ============================================================================
command! TOC call pandoc#toc#ShowTOC()

" ======================================================================== }}}
" AutoNameFile {{{1
" ============================================================================
function! s:RemoveDiacritics(text)
    " This function returns text without diacritics. Modified from
    " <http://vim.wikia.com/wiki/Remove_diacritical_signs_from_characters>.
    let l:diacs = 'áâãàäÇçéèêëíîìïñóôõòöüúûù'  " lowercase diacritical signs
    let l:repls = 'aaaaaCceeeeiiiinooooouuuu'  " corresponding replacements
    let l:diacs .= toupper(l:diacs)
    let l:repls .= toupper(l:repls)
    return tr(a:text, l:diacs, l:repls)
endfunction
try
    function! s:AutoNameFile( ... )
        " For pandoc files, this function will generate a filename from the title
        " field of the YAML header, replacing diacritics, stripping out
        " non-alphabetic characters and short words, converting ',' to '-', and
        " converting spaces to `_`.
        try
            update
        catch
        endtry
        let l:suffix = join(a:000, ' ')
        let l:fileBegin = join(getline(0, 200), "\n")
        if &filetype ==# 'pandoc'
            let l:title = matchstr(l:fileBegin,
                \ '\ntitle:\s\+\zs.\{-}\ze\s*\(\^\[\|\n\)')
            let l:extension = '.md'
        elseif &filetype ==# 'tex'
            let l:title = matchstr(l:fileBegin,
                \ '\ntitle:\s\+\zs.\{-}\ze\s*\(\^\[\|\n\)')
            let l:extension = '.tex'
        endif
        if l:title ==# ''
            echohl WarningMsg
            echom 'Could not find title.'
            echohl None
            return
        endif
        if !empty(l:suffix)  " Add suffix if there is one
            let l:title = l:title . '-' . l:suffix
        else
            " Try to guess a suffix: if presentation, name it that!
            if l:fileBegin =~# '\n- aspectratio' || l:fileBegin =~# '\ntheme' ||
                        \ l:fileBegin =~# '\nbeamerarticle'
                let l:title .= '-Presentation'
                echo 'Identified as presentation.'
            endif
        endif
        let l:title = substitute(l:title, '[.!?,:;] ', '-', 'g')
        let l:title = substitute(l:title, '/', '-', 'g')
        let l:title = substitute(l:title, ' ', '_', 'g')
        let l:title = <SID>RemoveDiacritics(l:title)
        let l:title = substitute(l:title, '[^A-Za-z0-9 _-]', '', 'g')
        let l:title = substitute(l:title, '\c\<\(A\|An\|The\)_', '', 'g')
        let l:title = substitute(l:title, '__', '_', 'g')
        let l:newName = fnameescape(expand('%:p:h') . '/' . l:title . l:extension)
        let l:currentName = expand('%:p')
        if l:newName !=? l:currentName && findfile(l:newName) !=# ''
            " Note: if l:newName merely modifies the case of l:currentName, this
            " will not throw up a warning. In most cases this is what I want,
            " but if there is another file that is a case variant of the
            " current file, this could be problematic. I won't worry about
            " this possibility.
            echohl WarningMsg
            echom 'Destination file (' . fnamemodify(l:newName, ':t') . ') already exists. Overwrite? (y/N)'
            if getchar() != 121  " ('y')
                echom 'Aborting...'
                echohl None
                return
            endif
            echom 'Overwriting...'
            echohl None
        endif
        if l:currentName !=# ''  "File already has a name
            if findfile(l:currentName, '.') ==# ''  " No existing file
                execute 'write ' . l:newName
            elseif l:currentName ==# l:newName  " Existing file with same name
                update
                echohl Comment
                echom 'Updated existing file w/o renaming.'
                echohl None
            else  " Existing file with different name
                try
                    " Try using fugitive's Gmove. In case of error, write and
                    " delete manually. This happens (a) if fugitive is not loaded
                    " or the file is not in a git repository or (b) if the file is
                    " already saved but not yet added to git repository.
                    execute 'Gmove! ' . l:newName
                    execute 'bwipeout ' . l:currentName
                        " Next line is needed when l:newName only modifies the
                        " case of l:currentName: bwipeout will kill the
                        " current buffer, and so it needs to be reloaded. (In
                        " other cases, `edit` will do nothing.)
                        execute 'edit ' . l:newName
                catch
                    if rename(l:currentName, l:newName)
                        echohl Error
                        echom 'Error renaming file ' . fnamemodify(l:currentName, ':t') . ' to ' . fnamemodify(l:newName, ':t')
                        echohl None
                    else
                        echom 'File renamed to: ' . fnamemodify(l:newName, ':t')
                        execute 'bwipeout ' . l:currentName
                        " Next line is needed when l:newName only modifies the
                        " case of l:currentName: bwipeout will kill the
                        " current buffer, and so it needs to be reloaded. (In
                        " other cases, `edit` will do nothing.)
                        execute 'edit ' . l:newName
                    endif
                endtry
            endif
        else  " File does not already have a name
            execute 'write! ' . l:newName
        endif
    endfunction
catch /E127/  " Can't redefine function, it's already in use.
"     " This will happen when the new filename only modifies the case of the old
"     " filename. Only in this case is the file actually reloaded, causing this
"     " file to be sourced and so this function redefined.
endtry
command! -nargs=* AutoNameFile call <SID>AutoNameFile(<q-args>)
cnoreabbr <buffer> anf AutoNameFile

" ======================================================================== }}}
" Folding {{{1
" ============================================================================
setlocal foldtext=pandoc#fold#FoldText()
setlocal fillchars=vert:│
setlocal fillchars+=fold:·

" ======================================================================== }}}
" Tidy Up Pandoc Documents {{{1
" ============================================================================
function! s:TidyPandoc() abort
    let l:saveSearch = @/
    " Tidy up pandoc documents
    " 1. Convert tabs to spaces at beginnings of lines
    setlocal tabstop=4
    retab
    " 2. Remove extra blank lines between list items
    silent! global/\(^\s*\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s[^\n]*$\n\)\@<=\n\ze\s\+\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s\+/d
    " 3. removing extra spaces after list identifiers
    silent! %substitute /^\(\s*\)\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s\s\+/\1\2 /
    " TODO: 4. remove excess escaping
    let @/ = l:saveSearch
endfunction
command! TidyPandoc call <SID>TidyPandoc()

" ======================================================================== }}}
" Other {{{1
" ============================================================================
setlocal equalprg=pandoc\ -t\ markdown+table_captions-simple_tables-multiline_tables-grid_tables+pipe_tables+line_blocks-fancy_lists+definition_lists+example_lists\ --wrap=none\ --from=markdown-fancy_lists\ --atx-headers\ --standalone\ --preserve-tabs
" Allow wrapping past BOL and EOL when using `h` and `l`
setlocal whichwrap+=h,l
" List of characters that can cause a line break; don't want breaking at '@',
" since this marks citations/cross-references.
setlocal breakat-=@
" }}}
