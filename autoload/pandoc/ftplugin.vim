scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

function! pandoc#ftplugin#JumpToHeader(direction, count) abort  "{{{
    " The count indicates the level of heading to jump to
    let l:count = a:count == 0 ? 6 : a:count
    let l:found = search('^#\{1,' . l:count . '}\s', a:direction . 'W')
    if l:found == 0
        echohl Error
        if a:direction ==# 'b'
            redraw | echo 'No previous header of level' l:count 'or below.'
        else
            redraw | echo 'No next header of level' l:count 'or below.'
        endif
        echohl None
    endif
endfunction
"}}}
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
    " TODO: 4. remove excess escaping
    let @/ = l:saveSearch
endfunction
"}}}
