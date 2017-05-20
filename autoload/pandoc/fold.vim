scriptencoding utf-8
" vim: set fdm=marker foldlevel=0:
" ============================================================================

function! pandoc#fold#FoldText()
	let l:text = getline(v:foldstart)
	let l:numLines = ' (' . string(v:foldend - v:foldstart + 1) . ' lines)'
	if l:text == '---'
		let l:cursor = getpos('.')
		call cursor(v:foldstart, 1)
		let l:titleLine = search('^title:\s', '')
		if l:titleLine > 0
			let l:text = getline(l:titleLine)
		endif
		call cursor(l:cursor[1], l:cursor[2])
	endif
	return l:text . l:numLines
endfunction
