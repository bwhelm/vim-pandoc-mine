scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================ }}}
" TOC Support {{{1
" ============================================================================
" Note: Much of this is copied (with modifications) from
" <https://github.com/vim-pandoc/vim-pandoc/blob/master/autoload/pandoc/toc.vim>

function! pandoc#toc#ShowTOC() abort
    let l:saveSearch = @/
    " Show the TOC in location list, and allow user to jump to locations by
    " hitting `<CR>` (closing location list) or `<C-CR>` (leaving location
    " list open). Much of this is taken from vim-pandoc's TOC code.
    let l:winID = winnr()
    let l:pos = search('^#\{1,6}\s', 'bnW')
    let l:currentSection = getline(l:pos)
    try
        silent lvimgrep /^#\{1,6}\s/j %
    catch /E480/
        echohl WarningMsg
        echo'No section headings found.'
        echohl None
        return
    endtry
    if len(getloclist(l:winID)) == 0
        return
    endif
    try
        " Must specify `botright` to put cursor in it when there are other
        " windows around!
        botright lopen
    catch /E776/  " no location list
        echohl ErrorMsg
        redraw | echo 'No TOC to show!'
        echohl None
        return
    endtry
    setlocal statusline=TOC modifiable
    silent %substitute/^\([^|]*|\)\{2,2} //e
    let l:currentLine = 1
    for l:line in range(1, len(getloclist(l:winID)))
        let l:heading = getloclist(l:winID)[l:line - 1]
        if l:heading['text'] ==# l:currentSection
            let l:currentLine = l:line
        endif
        let l:level = len(matchstr(l:heading.text, '#*', '')) - 1
        let l:heading.text = '•' l:heading.text[l:level + 2:]
        let l:heading.text = matchstr(l:heading.text, '.\{-}\ze\({.\{-}}\)\?$')
        call setline(l:line, repeat(' ', 4 * l:level) . l:heading.text)
    endfor
    setlocal nomodified nomodifiable

    syn match TOCHeader /^.*\n/
    syn match TOCBullet /•/ contained containedin=TOCHeader
    highlight link TOCHeader Directory
    highlight link TOCBullet Delimiter

    setlocal linebreak foldmethod=indent shiftwidth=4
    wincmd K
    silent! 0,$foldopen!
    call cursor(l:currentLine, 1)
    normal! zz

    noremap <buffer> q :lclose<CR>
    noremap <buffer> <Esc> :lclose<CR>
    noremap <buffer> <CR> <CR>:lclose<CR>
    noremap <buffer> <C-CR> <CR>
    let @/ = l:saveSearch
endfunction
