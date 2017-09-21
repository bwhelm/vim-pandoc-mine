scriptencoding utf-8
" vim: set fdm=marker foldlevel=0:
" ============================================================================

function! pandoc#fold#FoldText()
    let l:text = getline(v:foldstart)
    let l:numLines = ' (' . string(v:foldend - v:foldstart + 1) . ' lines)'
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

function! pandoc#fold#FindSectionBoundaries()
    if getline('.') =~# '^#\{1,6}\s'
        let l:startLine = line('.')
    else
        let l:startLine = search('^#\{1,6}\s', 'bnW')
        if l:startLine == 0
            if getline(1) ==# '---'
                call cursor(2, 0)
                let l:startLine = search('^---$', 'nW')  " At end of YAML header
            endif
            let l:startLine = l:startLine + 1  " This is either start of file or after YAML header
        endif
    endif
    let l:endLine = search('^#\{1,6}\s', 'nW')
    if l:endLine == 0
        let l:endLine = line('$')
    else
        let l:endLine = l:endLine - 1
    endif
    return [l:startLine, l:endLine]
endfunction

function! pandoc#fold#foldSection(exclusive)
    if foldlevel('.') > 0 && a:exclusive == 1
        echohl WarningMsg
        echo 'Already in a fold.'
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

function! pandoc#fold#foldAllSections()
    " Delete all folds
    normal! zE
    let l:origCursor = getpos('.')
    1
    let l:cursor = 1
    while l:cursor < line('$')
        let l:cursor = pandoc#fold#foldSection(0) + 1
        if l:cursor == 0
            break
        endif
        call setpos('.', [0, l:cursor, 1, 0])
    endwhile
    call setpos('.', l:origCursor)
endfunction

function! pandoc#fold#foldAllSectionsNested()
    " Delete all folds
    normal! zE
    let l:origCursor = getpos('.')
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
    call setpos('.', l:origCursor)
endfunction
