scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

function! pandoc#fold#FoldText() abort
    let l:text = getline(v:foldstart)
    let l:numLines = ' [' . string(v:foldend - v:foldstart + 1) . ' ℓ]'
    if l:text ==# '---'
        " There seems to be a weird interaction between using the `search()`
        " function and `incsearch`: the latter won't work if I use the former
        " here. So rather than finding the title line, I'm just assuming that
        " the title line will be the second line of the document -- the first
        " in the YAML header. Won't always work, but it's better than borking
        " `incsearch`.
        let l:text = getline(2)
        " let l:cursor = getpos('.')
        " call cursor(v:foldstart, 1)
        " let l:searchEnd = search('^---$', 'nW')
        " if l:searchEnd > 0
        "     let l:titleLine = search('^title:\s', 'nW', l:searchEnd)
        "     let l:titleLine = 3
        "     if l:titleLine > 0
        "         let l:text = getline(l:titleLine)
        "     endif
        " endif
        " call cursor(l:cursor[1], l:cursor[2])
    endif
    return l:text . l:numLines
endfunction

function! pandoc#fold#FindSectionBoundaries() abort
    " Set l:count to be v:count if set, otherwise v:prevcount if set,
    " otherwise 6. When this function is called by the `a#` or `i#` mappings,
    " it takes an optional count indicating the level of section to operate
    " on. Thus, `1va#` = `v1a#` will select around the current top-level
    " section. `3v1a#` will select around the current first-level section,
    " with the "1" taking precedence over the "3".
    let l:startPos = getpos('.')
    let l:count = v:count > 0 ? v:count : v:prevcount > 0 ? v:prevcount : 6
    if getline('.') =~# '^#\{1,' . l:count . '}\s'
        let l:startLine = line('.')
    else
        let l:startLine = search('^#\{1,' . l:count . '}\s', 'bnW')
        if l:startLine == 0
            if getline(1) ==# '---'
                call cursor(2, 0)
                let l:startLine = search('^---$', 'nW')  " At end of YAML header
            endif
            let l:startLine = l:startLine + 1  " This is either start of file or after YAML header
        endif
    endif
    call cursor(l:startLine, 1)
    let l:endLine = search('^#\{1,' . l:count . '}\s', 'nW')
    call setpos('.', l:startPos)
    if l:endLine == 0
        let l:endLine = line('$')
    else
        let l:endLine = l:endLine - 1
    endif
    return [l:startLine, l:endLine]
endfunction

function! pandoc#fold#foldSection(exclusive) abort
    if foldlevel('.') > 0 && a:exclusive == 1
        echohl WarningMsg
        redraw | echo 'Already in a fold.'
        echohl None
        let l:endLine = 0
    else
        let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
        if l:startLine > line('.')  " If we're in YAML header
            execute '1,' . string(l:startLine - 1) . 'fold'
            execute l:startLine . ',' . l:endLine . 'fold'
        else
            execute l:startLine . ',' . l:endLine . 'fold'
        endif
    endif
    return l:endLine
endfunction

function! pandoc#fold#foldAllSections() abort
    " Delete all folds
    normal! zE
    let l:startPos = getpos('.')
    1
    let l:cursor = 1
    while l:cursor < line('$')
        let l:cursor = pandoc#fold#foldSection(0) + 1
        if l:cursor == 0
            break
        endif
        call cursor(l:cursor, 1)
    endwhile
    call setpos('.', l:startPos)
endfunction

function! pandoc#fold#foldAllSectionsNested() abort
    " Delete all folds
    normal! zE
    let l:startPos = getpos('.')
    call setpos('.', [0, 1, 1, 0])
    let l:cursorStart = 1
    if getline('.') ==# '---'
        let l:cursorStart = pandoc#fold#foldSection(0) + 1
    endif
    for l:i in range(6, 1, -1)
        execute l:cursorStart
        let l:cursor = l:cursorStart
        while l:cursor < line('$')
            let l:startPos = search('^#\{' . l:i . '}\s', 'cW')
            if l:startPos < 1
                break
            endif
            let l:endPos = search('^#\{1,' . l:i . '}\s', 'W') - 1
            if l:endPos < 1
                let l:endPos = line('$')
            endif
            execute l:startPos . ',' . l:endPos . 'fold'
            let l:cursor = l:endPos + 1
        endwhile
    endfor
    call setpos('.', l:startPos)
endfunction
