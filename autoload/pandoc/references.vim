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
		" TODO: This is pretty slow, though very accurate. I wonder if I should use the bibliographic routines I've laid out in doing completion below to do this much faster.
		let l:biblio = system("echo '" . a:searchString . "' | pandoc --bibliography=/Users/bennett/Library/texmf/bibtex/bib/Bibdatabase-new.bib --bibliography=/Users/bennett/Library/texmf/bibtex/bib/Bibdatabase-helm-new.bib --filter=/usr/local/bin/pandoc-citeproc -t plain")
		if l:biblio !=# ''
			new +setlocal\ buftype=nofile\ bufhidden=wipe\ noswapfile\ nobuflisted\ nospell
			resize 5
			put! =l:biblio
			normal! Gddgg2ddvGJ0
			nnoremap <buffer> <CR> gx
			nnoremap <buffer> q ZQ
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
	return []
	let l:text = getline(0, '$')
	let l:completionList = []
	let l:matchHeaderPattern = '#\{1,6}\s\+\(.\{-}\)\s\+{#\([[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß\-_+:]\+\).\{-}}'
	let l:matchItemPattern = '^(\?@\zs[^.]\{-}\ze[).]\s'
	for l:line in l:text
		if match(l:line, '^#\{1,6}\s') == 0   " If line is a header
			if l:line =~ a:base
				let l:match = matchlist(l:line, l:matchHeaderPattern)
				if len(l:match) && l:line !~? '[ {]-[ }]\|\.unnumbered'
					" ID provided (and header is not unnumbered)
					let l:completionList += [{'word': l:match[2],
								\ 'abbr': l:match[2][:s:abbrLength],
								\ 'menu': l:match[1],
								\ 'icase': 1,
								\ 'info': l:line}]
				elseif l:line !~? '[ {]-[ }]\|\.unnumbered'
					" Line is a header, but no ID provided (and header is not
					" unnumbered); need to generate it.
					let l:headerID = <SID>GenerateHeaderID(l:line)
					let l:completionList += [{'word': l:headerID,
								\ 'abbr': l:headerID[:s:abbrLength],
								\ 'menu': l:line,
								\ 'icase': 1,
								\ 'info': l:line}]
				endif
			endif
		elseif match(l:line, '^(\?@[^.]\{1,20}[).]\s') == 0
			if l:line =~ a:base
				let l:match = matchstr(l:line, l:matchItemPattern)
				let l:completionList += [{'word': l:match,
							\ 'abbr': l:match[:s:abbrLength],
							\ 'menu': '(List ID)',
							\ 'icase': 1,
							\ 'info': l:line}]
			endif
		endif
	endfor
	return l:completionList
endfunction

function! pandoc#references#GetBibEntries(base)

python << endpython
from re import findall, match, search, sub, IGNORECASE
from vim import command, eval

def readFile(fileName):
	"""
	Read text from file on disk.
	"""
	with open(fileName, 'r') as f:
		text = f.read()
	return text

def getBibData():
	"""Read data from .bib files"""
	bibText = readFile('/Users/bennett/Library/texmf/bibtex/bib/' +
					   'Bibdatabase-new.bib')
	bibText += readFile('/Users/bennett/Library/texmf/bibtex/bib/' +
						'Bibdatabase-helm-new.bib')
	return bibText

def retrieveBibField(bibItem, fieldname):
	try:
		field = search(r'\b' + fieldname + r'\s*=\s*{(.*)}[,}]', bibItem,
						IGNORECASE).group(1)
	except AttributeError:
		field = ''
	return field

def constructBookEntry(bibItem):
	"""Create markdown bibliography entry for book"""
	author = retrieveBibField(bibItem, 'author')
	if author == '':
		editor = retrieveBibField(bibItem, 'editor')
		# entry = editor
		shortEntry = editor[:editor.find(',')]
	else:
		# entry = author
		shortEntry = author[:author.find(',')]
	year = retrieveBibField(bibItem, 'year')
	# entry += ' (' + year + ').'
	shortEntry += '(' + year + ').'
	booktitle = retrieveBibField(bibItem, 'booktitle')
	if booktitle != '':
		# entry += ' *' + booktitle + '*.'
		shortEntry += ' *' + booktitle + '*.'
	else:
		# entry += ' *' + retrieveBibField(bibItem, 'title') + '*.'
		shortEntry += ' *' + retrieveBibField(bibItem, 'title') + '*.'
	return shortEntry

def constructArticleEntry(bibItem):
	"""Create markdown bibliography entry for article"""
	author = retrieveBibField(bibItem, 'author')
	# entry = author + ' (' + retrieveBibField(bibItem, 'year') + '). "' + retrieveBibField(bibItem, 'title') + '". *' + retrieveBibField(bibItem, 'journal') + '*.'
	shortEntry = author[:author.find(',')] + '(' + \
				 retrieveBibField(bibItem, 'year') + '). "' + \
				 retrieveBibField(bibItem, 'title') + '". *' + \
				 retrieveBibField(bibItem, 'journal') + '*.'
	volume = retrieveBibField(bibItem, 'volume')
	# if volume != '':
		# entry += ' ' + volume + ':'
		# entry += retrieveBibField(bibItem, 'pages') + '.'
	return shortEntry

def constructInCollEntry(bibItem, crossref):
	"""Create markdown bibliography entry for incollection"""
	year = retrieveBibField(bibItem, 'year')
	if year == '':
		try:
			year = search(r'\(([^)]*)\)', crossref).group(1)
		except AttributeError:
			pass
	author = retrieveBibField(bibItem, 'author')
	if author == '':
		try:
			author = search(r'[^(]*', crossref).group(0)
		except AttributeError:
			pass
	if crossref == '':
		crossref = '*' + retrieveBibField(bibItem, 'booktitle') + '*'
		# entry = author + ' (' + year + '). "' + retrieveBibField(bibItem, 'title') + '". In ' + crossref + retrieveBibField(bibItem, 'pages') + '.'
	shortEntry = author[:author.find(',')] + '(' + year + '). "' + \
	             retrieveBibField(bibItem, 'title') + '". In ' + crossref + '.'
	return shortEntry

def removeLatex(text):
	"""Quick substitution of markdown for common LaTeX"""
	text = sub(r'\\emph{([^}]*)}', r'*\1*', text)  # Swamp emphasis
	text = sub(r'\\mkbibquote{([^}]*)}', r'"\1"', text)  # Remove mkbibquote
	text = sub(r'{?\\ldots{?}?', '...', text)  # Replace `...`
	text = sub(r"{\\'\\(.)}", r'\1', text)  # Replace latex accents
	text = sub(r"\\['`\"^v]", '', text)  # Replace latex accents
	text = sub(r'{(.)}', r'\1', text)  # Remove braces around single letters
	text = text.replace('{}', '')  # Remove excess braces
	text = text.replace("\\v", "")  # Remove 'v' accent
	text = text.replace('\\&', '&')  # Don't escape `&`
	return text

def constructBibEntry(bibItem, bibDataList):
	"""Create markdown bibliography entry for .bib entry"""
	# First extract relevant bibtex fields...
	entryType = search(r'(?<=@)[^{]*', bibItem, IGNORECASE).group(0)
	#try:
	key = search(r'@[^{]*{([^,]*)', bibItem, IGNORECASE).group(1)
	#except AttributeError:
	#	return {}
	# Now construct rough markdown representations of citation
	if entryType == 'book':
		shortEntry = constructBookEntry(bibItem)
	elif entryType == 'article':
		shortEntry = constructArticleEntry(bibItem)
	elif entryType == 'incollection':
		try:
			crossref = search(r'(\s*crossref\s*=\s*{)(.*)}[,}]', bibItem,
							  IGNORECASE).group(2)
			for item in bibDataList:
				if item.startswith('@book{' + crossref):
					crossref = constructBibEntry(item, bibDataList)['abbr']
					break
		except AttributeError:
			crossref = ''
		shortEntry = constructInCollEntry(bibItem, crossref)
	else:  # Some other entry type; make it minimal....
		author = retrieveBibField(bibItem, 'author')
		# entry = author + ' (' + retrieveBibField(bibItem, 'year') + '). ' + retrieveBibField(bibItem, 'title') + '.'
		shortEntry = author[:author.find(',')] + '(' + \
		             retrieveBibField(bibItem, 'year') + '). ' + \
					 '"' + retrieveBibField(bibItem, 'title') + '".'
	# Construct dictionary entry to return
	entryDict = {'word': key}
	entryDict['abbr'] = removeLatex(shortEntry)
	#entryDict['abbr'] = key[:abbrLength]
	#entryDict['info'] = removeLatex(entry)
	#entryDict['menu'] = removeLatex(title)[:60]
	entryDict['icase'] = 1
	return entryDict

def createBibList(base):
	"""Create list of entries that match on every word in base"""
	bibText = getBibData()
	bibDataList = findall(r'@[^@]*', bibText)
	baseList = base.lower().split(' ')  # List of terms to match
	matchedList = []  # List of matched bibliography items
	for bibItem in bibDataList:
		if bibItem.startswith('@comment{'):
			pass
		else:
			keep = True
			for baseItem in baseList:
				if baseItem not in bibItem.lower():
					keep = False
					break
			if keep:
				matchedList.append(bibItem)
	# Sort matchedList by citation key (`AuthorDATETitle`)
	matchedList = sorted(matchedList, key=lambda item: match('@[^{]*{([^,]*)',
															 item).group(1))
	constructedList = [constructBibEntry(item, bibDataList) for item in
					   matchedList]
	return constructedList

abbrLength = int(eval('s:abbrLength'))  # Length of key abbreviations
base = eval('a:base')
matchedList = createBibList(base)
# Need to do the following replacement here to convert from python-style
# single quotes to vim-style single quotes.
command('let l:matchedList = ' + str(matchedList).replace("\\'", "''"))
endpython

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

