scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

" Text object for footnotes  {{{
function! pandoc#textobjects#FindAroundFootnote()
    let l:curPos = getcurpos()
    let l:found = search('\^[', 'cW', l:curPos[1])  " try ahead on current line
    if l:found == 0  " ... otherwise try behind on current line ...
        let l:found = search('\^[', 'bcW', l:curPos[1])
    endif
    if l:found == 0  " ... otherwise try ahead on screen ...
        let l:found = search('\^[', 'cW', line("w$"))
    endif
    if l:found == 0  " ... otherwise try behind on screen ...
        let l:found = search('\^[', 'bcW', line("w0"))
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
"}}}
" Text object for (sub)sections  {{{
function! pandoc#textobjects#FindAroundSection()
    let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
    return ['V', [0, l:startLine, 1, 0], [0, l:endLine, 1, 0]]
endfunction

function! pandoc#textobjects#FindInsideSection()
    let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
    while l:startLine < line('$')
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
"}}}
" Text object for notes  {{{
function! pandoc#textobjects#FindInsideNote()
    let l:currentPos = getpos('.')
    let l:line = l:currentPos[1]
    let l:stopLine = l:line  " Initially search only in current line
    let l:initial = l:currentPos[2]
    let l:direction = ''  " Start searching forward
    while 1
        if search('\]{\.[a-z]\{2,}}', l:direction . 'W', l:stopLine)
            if searchpair('\[', '', '\]', 'bW')
                break
            endif
        else  " No match
            if l:direction == ''  " Try searching backwards
                let l:direction = 'b'
                if l:stopLine == line('$') && l:line != line('$')
                    let l:stopLine = 1
                endif
            elseif l:stopLine == l:line && l:line != 1  " Try searching forwards to end
                let l:stopLine = line('$')
                let l:direction = ''
            else  " Failed to find a Note: return to original position
                call setpos('.', l:currentPos)
                return
            endif
        endif
    endwhile
    let l:startPos = getpos('.')
    call searchpair('\[', '', '\]', 'W')
    let l:endPos = getpos('.')
    return ['v', [0, l:startPos[1], l:startPos[2] + 1, 0], [0, l:endPos[1], l:endPos[2] - 1, 0]]
endfunction
function! pandoc#textobjects#FindAroundNote()
    let l:currentPos = getpos('.')
    try
        let [l:type, l:startPos, l:endPos] = pandoc#textobjects#FindInsideNote()
    catch /E714/  " No Note found; return to original position
        call setpos('.', l:currentPos)
        return
    endtry
    call search('{\.[a-z]\{2,}\zs}', '', line('.'))
    let l:endPos[2] = getpos('.')[2]
    return [l:type, [0, l:startPos[1], l:startPos[2] - 1, 0],
                \   [0, l:endPos[1], l:endPos[2], 0]]
endfunction
