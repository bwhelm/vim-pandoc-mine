" ============================================================================ }}}
" TOC Support {{{1
" ============================================================================
" Note: Much of this is copied (with modifications) from
" <https://github.com/vim-pandoc/vim-pandoc/blob/master/autoload/pandoc/toc.vim>

function! pandoc#toc#ShowTOC() abort
	" Show the TOC in location list, and allow user to jump to locations by
	" hitting `<CR>` (closing location list) or `<C-CR>` (leaving location
	" list open). Much of this is taken from vim-pandoc's TOC code.
	normal! mtj
	normal [[
	let l:currentSection = getline('.')
	silent lvimgrep /^#\{1,6}\s/ %
	if len(getloclist(0)) == 0
		return
	endif
	try
		lopen
	catch /E776/  " no location list
		echohl ErrorMsg
		echom 'No TOC to show!'
		echohl None
	endtry
	setlocal statusline=TOC modifiable
	silent %substitute/^\([^|]*|\)\{2,2} //e
	let l:currentLine = 0
	for l:line in range(1, line('$'))
		let l:heading = getloclist(0)[l:line - 1]
		if l:heading['text'] == l:currentSection
			let l:currentLine = l:line
		endif
		let l:level = len(matchstr(l:heading.text, '#*', '')) - 1
		let l:heading.text = '• ' . l:heading.text[l:level + 2:]
		let l:heading.text = matchstr(l:heading.text, '.\{-}\ze\({.\{-}}\)\?$')
		call setline(l:line, repeat(' ', 4 * l:level) . l:heading.text)
	endfor
	setlocal nomodified nomodifiable

	syn match TOCHeader /^.*\n/
	syn match TOCBullet /•/ contained containedin=TOCHeader
	highlight link TOCHeader Directory
	highlight link TOCBullet Delimiter

	setlocal linebreak foldmethod=indent shiftwidth=4
	execute "normal \<C-w>K"
	normal! zR
	call cursor(l:currentLine, 1)
	normal! zz

	noremap <buffer> q :lclose<CR>`t
	noremap <buffer> <CR> <CR>:lclose<CR>
	noremap <buffer> <C-CR> <CR>
endfunction
