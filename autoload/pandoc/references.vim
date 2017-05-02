" Following creates tag-like jumps for cross-references
function! s:JumpToReference(searchString)
	" Construct string to search for relevant label (whether a
	" pandoc-style heading identifier or a pandocCommentFilter-style
	" cross-reference)
	if a:searchString =~# '^@'  " If pandoc-style heading identifier
		let l:commandString = '/#' . a:searchString[1:]
	else  " pandocCommentFilter-style label
		let l:commandString = '/<l ' . a:searchString
	endif
	" Search for it. (This puts cursor at beginning of line.)
	try
		call execute(l:commandString)
		" Visually select matched string, switch to front end, and return to
		" normal mode. (Note: this must be in double-quotes!)
		execute "normal! gno\<Esc>"
		return
	catch /E486/  " If search string not found ...
		" ... Need to find all headers in document, create header IDs for
		" them, checking to see if that's what we're looking for.
		let l:text = getline(0, '$')
		for l:line in l:text
			if l:line =~# '^#\{1,6}\s'
				if a:searchString[1:] ==# <SID>GenerateHeaderID(l:line)
					let l:line = substitute(l:line, '/', '\\/', 'g')
					call execute('/' . l:line)
					execute "normal! gno\<Esc>"
					return
				endif
			endif
		endfor
		" The pandoc method is pretty slow, though very accurate. Using my
		" citation is much faster, and probably accurate enough for most
		" purposes.
		"let l:biblio = system("echo '" . a:searchString . "' | pandoc --bibliography=/Users/bennett/Library/texmf/bibtex/bib/Bibdatabase-new.bib --bibliography=/Users/bennett/Library/texmf/bibtex/bib/Bibdatabase-helm-new.bib --filter=/usr/local/bin/pandoc-citeproc -t plain")
		python import references
		let l:biblio = pyeval("references.constructOneEntry('" . a:searchString . "')")
		if l:biblio !=# ''
			new +setlocal\ buftype=nofile\ bufhidden=wipe\ noswapfile\ nobuflisted\ nospell\ modifiable
			resize 5
			put! =l:biblio
			$d
            " Move to URL (if there is one; fail silently if not)
            silent! normal! f<
			" Use next line only with pandoc method
			"normal! gg2ddvGJ0
			nmap <buffer> <CR> <Plug>NetrwBrowseX
			nnoremap <buffer> q ZQ
			nnoremap <buffer> <Esc> ZQ
		else
			echohl WarningMsg
			echom 'Cannot find ID.'
			echohl None
		endif
	endtry
endfunction

function! pandoc#references#GoToReference()
	" Need ignorecase and smartcase turned off ... but save values to restore
	" later
	let l:ignorecaseSave = &ignorecase
	let l:smartcaseSave = &smartcase
	set noignorecase
	set nosmartcase
	normal! mx
	let l:line = getline('.')
	let [l:bufnum, l:lnum, l:col, l:off] = getpos('.')
	let l:col -= 1
	if l:col > 0 && l:line[l:col-1] !=# ' '
		" If not already at beginning of line or beginning of word, jump back
		" to start of Word
		normal! B
		let [l:bufnum, l:lnum, l:col, l:off] = getpos('.')
		let l:col -= 1
	endif
	" The following searches for pandoc-style heading identifiers or for
	" pandocCommentFilter-style cross-references -- whichever comes first.
	let l:searchString = matchstr(l:line, '@[A-z][[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß_:.#$%&\-+?<>~/]*\|<rp\? \zs[^>]*>', l:col)
	if !empty(l:searchString)
		" If found, return to original position (to put it in jumplist)
		normal! `x
		call <SID>JumpToReference(l:searchString)
	else
		" Not found ... so try searching for last match in line, even if
		" before cursor position. This doesn't quite work, since it will find
		" a pandoc-style heading identifier that occurs earlier than a
		" pandocCommentFilter-style cross-reference. I'm not sure I care to
		" fix this.
		let l:searchString = matchstr(l:line, '^.*\(\zs@[A-z][[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß_:.#$%&\-+?<>~/]*\|^.*<rp\? \zs[^>]*>.\{-}\)')
		if !empty(l:searchString)
			normal! `x
			silent call <SID>JumpToReference(l:searchString)
		else
			echohl WarningMsg
			echom 'No cross-reference found.'
			echohl None
		endif
	endif
	" Restore settings
	let &ignorecase = l:ignorecaseSave
	let &smartcase = l:smartcaseSave
endfunction


" ============================================================================ }}}
" Completion Function for References/Bibliography {{{1
" ============================================================================

let s:abbrLength = 10  " Length of citation key abbreviation

function! s:GenerateHeaderID(header)
	" Generates pandoc-style identifiers for headers. Assumes headers are
	" relatively well behaved (without much formatting, for example), and so
	" is somewhat fragile.
	let l:header = tolower(a:header)
	let l:header = matchstr(l:header, '#\{1,6}[^A-z]\+\zs.\{-}\ze\s*$')
	let l:header = substitute(l:header, ' ', '-', 'g')
	let l:header = substitute(l:header, '[^A-Za-z0-9_\-.]', '', 'g')
	if empty(l:header)
		let l:header = 'section'
	endif
	return l:header
endfunction

function! s:FindHeaderID(base)
	let l:text = getline(0, '$')
	let l:completionList = []
	let l:matchHeaderPattern = '\(#\{1,6}\s\+.\{-}\)\s\+{#\([[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß\-_+:]\+\).\{-}}'
	let l:matchItemPattern = '^(\?@\zs[^.]\{-}\ze[).]\s'
	for l:line in l:text
		if match(l:line, '^#\{1,6}\s') == 0   " If line is a header
			if l:line =~ a:base
				let l:match = matchlist(l:line, l:matchHeaderPattern)
				if len(l:match) && l:line !~? '[ {]-[ }]\|\.unnumbered'
					" ID provided (and header is not unnumbered)
					let l:completionList += [{'word': l:match[2],
								\ 'abbr': l:match[1],
								\ 'icase': 1}]
								"\ 'info': l:line}]
								"\ 'menu': l:match[1],
				elseif l:line !~? '[ {]-[ }]\|\.unnumbered'
					" Line is a header, but no ID provided (and header is not
					" unnumbered); need to generate it.
					let l:headerID = <SID>GenerateHeaderID(l:line)
					let l:completionList += [{'word': l:headerID,
								\ 'abbr': l:line,
								\ 'icase': 1}]
								"\ 'menu': l:line,
								"\ 'info': l:line}]
				endif
			endif
		elseif match(l:line, '^(\?@[^.]\{1,20}[).]\s') == 0
			" Named list item
			if l:line =~ a:base
				let l:match = matchstr(l:line, l:matchItemPattern)
				let l:completionList += [{'word': l:match,
							\ 'abbr': l:match ' (List ID)',
							\ 'icase': 1}]
							"\ 'menu': '(List ID)',
							"\ 'info': l:line}]
			endif
		endif
	endfor
	return l:completionList
endfunction

function! pandoc#references#GetBibEntries(base)
	python import references
	let l:matchedList = pyeval("references.createBibList('" . a:base . "')")
	return l:matchedList
endfunction

function! pandoc#references#MyCompletion(findstart, base)
	if a:findstart
		" locate the start of the partial ID but only if within 30 chars of
		" cursor
		let l:line = getline('.')
		let l:cursorPos = getpos('.')[2]
		if l:line[:col('.') - 1] =~# '@'
			let l:pos = searchpos('@', 'Wncb')
			if l:pos != [0,0] && l:cursorPos > l:pos[1] && l:pos[1] > l:cursorPos - 25
				return l:pos[1]
			else
				return -3
			endif
		else
			return -3
		endif
	else
		" Find matching header IDs...
		let l:completionList = <SID>FindHeaderID(a:base)
		" Add in bibliographic matches...
		let l:bibMatches = pandoc#references#GetBibEntries(a:base)
		let l:completionList += l:bibMatches
		return {'words': l:completionList}
	endif
endfunction


" The following will close the preview window that is automatically opened by
" the completion function.
augroup Completion
	autocmd!
	autocmd CompleteDone * pclose
augroup END

