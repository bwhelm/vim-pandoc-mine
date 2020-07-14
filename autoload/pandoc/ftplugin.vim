scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

function! pandoc#ftplugin#JumpToHeader(direction, count) abort  "{{{
    " The count indicates the level of heading to jump to
    let l:startPos = getcurpos()
    if a:direction == 'b'
        -
    else
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
            let l:linenum = system('/usr/bin/env python3 ' .
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
