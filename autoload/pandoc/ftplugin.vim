scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

function! pandoc#ftplugin#JumpToHeader(direction, count) abort  "{{{
    let l:startPos = getcurpos()
    let l:direction = a:direction == "" ? 1 : -1
    let l:count = a:count == 0 ? 6 : a:count
    let l:startLine = l:startPos[1]
    let l:endLine = a:direction == "" ? line("$") : 0
    for l:line in range(l:startLine + l:direction, l:endLine, l:direction)
        let l:matchLen = len(matchstr(getline(l:line)[0:l:count], '^#\{1,' . l:count . '} '))
        if map(synstack(l:line, 1), 'synIDattr(v:val, "name")') ==
                    \ ['pandocAtxHeader', 'pandocAtxHeaderMark', 'pandocAtxStart'] &&
                    \ 0 < l:matchLen && l:matchLen < l:count + 2
            " Found heading: jump there and exit
            call setpos("''", l:startPos)  " Add starting point to jumplist
            execute 'normal! ``' . l:line . 'G'
            return
        endif
    endfor
    " Can't find heading
    redraw | echohl Error
    if a:direction ==# 'b'
        echo 'No previous heading of level' l:count 'or below.'
    else
        echo 'No next heading of level' l:count 'or below.'
    endif
    echohl None
    call setpos('.', l:startPos)  " Restore initial position
endfunction
"}}}
"function! pandoc#ftplugin#JumpToHeaderOLD(direction, count) abort  "{{{
"    " The count indicates the level of heading to jump to
"    let l:startPos = getcurpos()
"    if getline(1) ==# "---"
"        let l:yamlEnd = search("^---$", "nW")
"        if a:direction == "" && l:yamlEnd > l:startPos[1]
"            execute 'keepjumps' l:yamlEnd + 1
"        endif
"    else
"        let l:yamlEnd = 0
"    endif
"    let l:count = a:count == 0 ? 6 : a:count
"    let l:found = search('^#\{1,' . l:count . '}\s', a:direction . 'nW')
"    if a:direction ==# "b" && l:yamlEnd > l:found
"        let l:found = l:yamlEnd + 1
"    endif
"    if (a:direction ==# "b" && l:found == l:yamlEnd + 1) || l:found == 0
"        redraw | echohl Error
"        if a:direction ==# 'b'
"            echo 'No previous heading of level' l:count 'or below.'
"        else
"            echo 'No next heading of level' l:count 'or below.'
"        endif
"        echohl None
"        call setpos('.', l:startPos)  " Restore initial position
"    else
"        " Jump to heading and add to jump list
"        execute 'normal!' l:found . 'G'
"    endif
"endfunction
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
    " TODO: 4. remove excess escaping
    let @/ = l:saveSearch
endfunction
"}}}
