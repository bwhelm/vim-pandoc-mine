" ============================================================================ }}}
" My Tab Completion {{{1
" ============================================================================
" Note: format of entries in this list is 'key': [length of characters to
" compare, length of key in chars, 'lhs', 'rhs', 'next']. Keys can be regex,
" so need to specify the numbers. (The regex should always end in `$` so that
" matches with longer numbers of characters aren't made.) If 'rhs' is empty,
" there is no need to hit `<Tab>` to get out of snippet. Finally, 'next' is
" there to jump to a next snippet automatically.
let s:SimpleSnippetsList = {
			\ '88': [2, 2, '**', '**', ''],
			\ '8': [1, 1, '*', '*', ''],
			\ '9': [1, 1, '(', ')', ''],
			\ "'": [1, 1, '"', '"', ''],
			\ '[': [1, 1, '{', '}', ''],
			\ '4': [1, 1, '$', '$', ''],
			\ '-': [1, 1, '---', '---', ''],
			\ 'cm': [2, 2, '[', ']{.comment}', ''],
			\ 'mg': [2, 2, '[', ']{.margin}', ''],
			\ 'fm': [2, 2, '[', ']{.fixme}', ''],
			\ 'sc': [2, 2, '[', ']{.smcaps}', ''],
			\ 'hl': [2, 2, '[', ']{.highlight}', ''],
			\ 'fn': [2, 2, '^[', ']', ''],
			\ '.*\<l$': [2, 1, '<l ', '>', ''],
			\ '.*\<r$': [2, 1, '<r ', '>', ''],
			\ '.*\<rp$': [3, 2, '<rp ', '>', ''],
			\ '.*\<i$': [2, 1, '<i ', '>', ''],
			\ '.*\<li$': [3, 2, '[',']', 'li-1'],
			\ 'li-1': [4, 4, '(', ')', 'li-2'],
			\ 'li-2': [4, 4, '{', '}', ''],
			\ '.*\<im$': [3, 2, '![',']', 'li-1'],
			\ '.*\<hr$': [3, 2, '----------------------------------------------------------------------------',
						\ '', ''],
			\ '`': [1, 1, '~', '~', ''],
			\ }

function! s:InsertSnippet(key)
	let [l:compLength, l:keyLength, l:left, l:right, l:next] =
				\ s:SimpleSnippetsList[a:key]
	if l:right !=# ''
		let b:recursiveSnippetList += [[a:key, l:next]]
	endif
	let l:typed = repeat("\<BS>", l:keyLength)
	let l:typed .= l:left . l:right
	let l:typed .= repeat("\<Left>", len(l:right))
	return l:typed
endfunction

function! s:JumpOutOfSnippet(line, cursor)
	let [l:key, l:next] = b:recursiveSnippetList[-1]
	call remove(b:recursiveSnippetList, - 1)
	let [l:compLength, l:keyLength, l:left, l:right, l:next] =
				\ s:SimpleSnippetsList[l:key]
	let l:matchPos = match(a:line, escape(l:right, '$.*~\^['), a:cursor - 1)
	let l:typed = repeat("\<Right>", len(l:right) + l:matchPos - a:cursor + 1)
	if l:next !=# ''
		let l:typed .= repeat(' ', len(l:next)) . <SID>InsertSnippet(l:next)
	endif
	return l:typed
endfunction

function! pandoc#completion#RecursiveSimpleSnippets()
	if !exists('b:recursiveSnippetList')
		let b:recursiveSnippetList = []
	endif
	let l:line = getline('.')
	let l:cursor = getpos('.')[2]
	let l:previous = l:line[l:cursor - 2]
	if l:previous =~# '\s' || l:previous ==# ':' || l:previous ==# ''
		return "\<Tab>"
	endif
	" Check for match of simple snippets
	for l:key in keys(s:SimpleSnippetsList)
		let [l:compLength, l:keyLength, l:left, l:right, l:next] =
					\ s:SimpleSnippetsList[l:key]
		if l:cursor - l:compLength < 1
			let l:compLength -= 1
		endif
		let l:possMatch = l:line[l:cursor - l:compLength - 1:l:cursor - 2]
		if l:possMatch =~# l:key
			return <SID>InsertSnippet(l:key)
		endif
	endfor
	" No match, so check if need to jump to end of snippet
	if len(b:recursiveSnippetList) > 0
		return <SID>JumpOutOfSnippet(l:line, l:cursor)
	else  " Not finding shortcut, no nested snippet, so try omni-completion
		return "\<C-X>\<C-O>"
	endif
endfunction

augroup RecursiveSimpleSnippets
	" I don't want b:recursiveSnippetList to get too big if it's not being
	" consumed. This zeros it out on save.
	autocmd!
	autocmd BufWrite * let b:recursiveSnippetList = []
augroup END
