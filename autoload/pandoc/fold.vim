scriptencoding utf-8
" vim: set fdm=marker foldlevel=0:
" ============================================================================

function! pandoc#fold#FoldText()
	if getline(v:foldstart) == '---'
		return getline(v:foldstart + 1)
	else
		return getline(v:foldstart)
	endif
endfunction
