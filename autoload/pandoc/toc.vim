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
    let l:bufID = bufnr('')
    let l:startPos = getpos('.')  " Save cursor position
    let l:currentSectionLine = search('^#\{1,6}\s', 'bcnW')
    let l:headingList = []
    let l:currentHeading = ''
    keepjumps 1
    while 1
        keepjumps let [l:line, l:col] = searchpos('^#\{1,6}\s', 'W')
        if l:line
            let l:text = getline(l:line)
            let l:level = len(matchstr(l:text, '^#\{1,6}', '')) - 1
            let l:headingText = repeat(' ', 2 * l:level) . '• ' . l:text[l:level + 2:]
            let l:headingText = matchstr(l:headingText, '.\{-}\ze\({.\{-}}\)\?$')
            call add(l:headingList, {'bufnr': l:bufID,
                                   \ 'lnum': l:line,
                                   \ 'col': 1,
                                   \ 'text': '|' . l:headingText
                                   \ })
            if l:line == l:currentSectionLine
                let l:currentHeading = l:headingText
            endif
        else
            break
        endif
    endwhile
    keepjumps call setpos('.', l:startPos)  " Restore cursor position
    if len(l:headingList) > 0
        call setloclist(0, l:headingList)
    else
        echohl WarningMsg
        echo'No section headings found.'
        echohl None
        return
    endif

    let l:qfedit_enable = get(g:, 'qfedit_enable', 1)  " If qfedit plugin is used
    let g:qfedit_enable = 0                            " Turn it off for now
    botright lopen
    setlocal statusline=TOC cursorline modifiable nolinebreak foldmethod=indent
    keepjumps silent %substitute/^.\{-}|\ze *•//e
    setlocal nomodified nomodifiable

    syntax match TOCHeader /• .*/
    syntax match TOCBullet /•/ contained containedin=TOCHeader
    highlight link TOCHeader Directory
    highlight link TOCBullet Delimiter

    let g:qfedit_enable = l:qfedit_enable              " Now re-enable qfedit plugin
    wincmd K
    silent! 0,$foldopen!
    keepjumps 1
    keepjumps call search(l:currentHeading)
    normal! zz

    noremap <silent><buffer> q :lclose<CR>zz
    noremap <silent><buffer> <Esc> :lclose<CR>zz
    noremap <silent><buffer> <CR> <CR>:lclose<CR>zz
    noremap <silent><buffer> <C-CR> <CR>zz
    let @/ = l:saveSearch
endfunction
