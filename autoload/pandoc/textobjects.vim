scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

" Text object for foontones
function! pandoc#textobjects#FindAroundFootnote()
    let l:curPos = getcurpos()
    let l:found = search('\^[', 'bcW', l:curPos[1])
    if l:found == 0
        let l:found = search('\^[', 'cW', l:curPos[1])
    endif
    if l:found > 0
        let l:beginPos = getcurpos()
        normal! l%
        let l:endPos = getcurpos()
        call setpos('.', l:curPos)
        if l:endPos != l:beginPos
            return ['v', l:beginPos, l:endPos]
        endif
    endif
    call setpos('.', l:curPos)
    echohl WarningMsg
    redraw | echo 'No footnote found.'
    echohl None
    return
endfunction

function! pandoc#textobjects#FindInsideFootnote()
    try
        let [l:type, l:begin, l:end] = pandoc#textobjects#FindAroundFootnote()
        let l:begin[2] += 2
        let l:end[2] -= 1
        return [l:type, l:begin, l:end]
    catch /E714/
        return
    endtry
endfunction

" Create text object for (sub)sections
function! pandoc#textobjects#FindAroundSection()
    let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
    return ['V', [0, l:startLine, 1, 0], [0, l:endLine, 1, 0]]
endfunction

function! pandoc#textobjects#FindInsideSection()
    let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
    let l:eof = line('$')
    while l:startLine < l:eof
        let l:startLine = l:startLine + 1
        if getline(l:startLine) =~# '\S'
            break
        endif
    endwhile
    while l:endLine > l:startLine
        if getline(l:endLine) =~# '\S'
            break
        endif
        let l:endLine = l:endLine - 1
    endwhile
    return ['V', [0, l:startLine, 1, 0], [0, l:endLine, 1, 0]]
endfunction
