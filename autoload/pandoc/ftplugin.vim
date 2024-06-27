scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

function! pandoc#ftplugin#JumpToHeader(mode, direction, count) abort  "{{{
    " `a:count` indicates the level of heading to jump to; `a:direction` is ''
    " for forward or 'b' for backward search; `a:mode` is 'o' for operator
    " pending, or 'n' for normal.
    if a:mode ==# 'v'  " if in visual mode
        " force motion to be linewise
        let l:startPos = a:direction == 'b' ? getpos("'>") : getpos("'<")
        let l:endPos = a:direction == 'b' ? getpos("'<") : getpos("'>")
        normal! V
        normal! V
    else
        if a:mode ==# 'o'  "if in operator pending mode
            call setpos("'<", getpos("."))
            call setpos("'>", getpos("."))
            normal! V
        endif
        let l:startPos = getpos(".")
        let l:endPos = l:startPos
    endif

    if a:direction == 'b'  " Avoid finding current line
        -
    else
        call setpos('.', l:endPos)
        +
    endif
    let l:count = a:count == 0 ? 6 : a:count
    let l:found = search('^#\{1,' . l:count . '}\s', a:direction . 'nW')
    if l:found
        if a:direction == 'b'
            +
        else
            -
        endif
        " Jump to heading and add to jump list
        execute 'normal!' l:found . 'G_'
        if 'ov' =~# a:mode
            if a:direction == ''  " Forward ... need to move 1 line short
                call setpos("'<", l:startPos)
                -
                call setpos("'>", getpos('.'))
            else  " Backward
                call setpos("'<", getpos('.'))
                call setpos("'>", l:startPos)
            endif
            normal! gv
        endif
    else
        if 'ov' =~# a:mode
            if a:direction == ''  " Forward: set end to end of doc
                call setpos("'>", [0, line('$'), 1, 0])
            else                  " Backward: set start to beg of doc
                call setpos("'<", [0, 1, 1, 0])
                call setpos("'>", l:startPos)
            endif
            normal! gv
        else
            redraw | echohl Error
            if a:direction ==# 'b'
                echo 'No previous heading of level' l:count 'or below.'
            else
                echo 'No next heading of level' l:count 'or below.'
            endif
            echohl None
            call setpos('.', l:startPos)  " Restore initial position
        endif
    endif
endfunction
""}}}
function! pandoc#ftplugin#JumpToTex(filetype) abort  "{{{
    let l:fileroot = expand('%:t:r')
    if l:fileroot ==# ''
        let l:fileroot = 'temp'
    endif
    let l:filename = fnamemodify('~/tmp/pandoc/' . l:fileroot . a:filetype, ':p')
    if filereadable(l:filename)
        let l:linenum = '0'
        if a:filetype ==# '\.tex'
            let l:pipenv = executable('pipenv') ? "pipenv run" : ""
            let l:linenum = system('/usr/bin/env ' . l:pipenv . ' python3 ' .
                        \ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
                        \ ' "' . expand('%:p') . '" ' . line('.') . ' ' . a:filetype)
        endif
        execute 'tabedit' l:filename
        execute l:linenum
    else
        echohl Error
        redraw | echo 'Corresponding' a:filetype 'file does not exist.'
        echohl None
    endif
endfunction
"}}}
function! pandoc#ftplugin#TidyPandoc() abort  "{{{
    let l:saveSearch = @/
    " Tidy up pandoc documents
    " 1. Convert tabs to spaces at beginnings of lines
    setlocal tabstop=4
    retab
    " 2. Remove extra blank lines between list items
    silent! global/\(^\s*\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s[^\n]*$\n\)\@<=\n\ze\s\+\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s\+/d
    " 3. removing extra spaces after list identifiers
    silent! %substitute /^\(\s*\)\((\?\d\+[.)]\|[-*+]\|(\?#[.)]\|(\?@[A-z0-9\-_]*[.)]\)\s\s\+/\1\2 /
    " 4. remove excess escaping
    silent! %substitute/\\"/"/g
    silent! %substitute/\\\.\.\./.../g
    " 5. Fix m-dashes and ellipses
    silent! %substitute/\s*---\s*/---/g
    silent! %substitute/\s*\.\.\.\s*/ ... /g
    " Cleanup
    let @/ = l:saveSearch
endfunction
"}}}
