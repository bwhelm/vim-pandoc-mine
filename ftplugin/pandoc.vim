" vim: set fdm=marker foldlevel=1:
scriptencoding utf-8
" My settings that should apply only to files with filetype=pandoc.

if exists('g:pandoc_enabled')
	finish
endif
let g:pandoc_enabled=1


" =========================================================================== }}}
" Commands for Conversions {{{1
" ===========================================================================

let b:converting = 0  " Used to keep track of whether currently converting or not
let b:autoPDFEnabled = 0  " Turn autoPDF off by default...
let b:lastConversionMethod = 'markdown-to-PDF-LaTeX.py'  " Last method used for conversions

" ============================================================================ }}}
" Key mappings {{{1
" ============================================================================

"" FIXME: This deletes bad vim-pandoc mappings and restores my preferred mappings.
"" (Bad vim-pandoc!)
"if mapcheck(",o") != ""
"	unmap ,o
"endif
"if mapcheck(",O") != ""
"	unmap ,O
"endif
nnoremap <LocalLeader>o :only<CR>

" taken from vim-pandoc {{{2
" ---------------------
" FIXME: These work, but will wrap. Should I change this?
noremap <buffer> <silent> ]] /^#\{1,6}\s.*<CR>
noremap <buffer> <silent> [[ ?^#\{1,6}\s.*<CR>

" exiting insert mode {{{2
" -------------------
" The following will move the cursor one character to the right when
" exiting insert mode unless the cursor is in the rightmost column.
inoremap <buffer><silent> <LocalLeader>. <Esc>`^
inoremap <buffer><silent> <Esc> <Esc>`^

" for conversions {{{2
" ---------------
"  (For all of these, call the helper function with relevant command.)

" Note that the `cc` mapping is to repeat the last conversion
nnoremap <buffer><silent> <LocalLeader>cc :call pandoc#MyConvertMappingHelper("")<CR>
inoremap <buffer><silent> <LocalLeader>cc <C-o>:call pandoc#MyConvertMappingHelper("")<CR>
" PDF conversion
nnoremap <buffer><silent> <LocalLeader>cp :call pandoc#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
inoremap <buffer><silent> <LocalLeader>cp <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cP :call pandoc#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cP <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
" HTML conversion
nnoremap <buffer><silent> <LocalLeader>ch :call pandoc#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>ch <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
" RevealJS conversion
nnoremap <buffer><silent> <LocalLeader>cr :call pandoc#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cr <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
" LaTeX Beamer conversion
nnoremap <buffer><silent> <LocalLeader>cb :call pandoc#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cb <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
" Word .docx conversion
nnoremap <buffer><silent> <LocalLeader>cd :call pandoc#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cd <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
" Markdown conversion
nnoremap <buffer><silent> <LocalLeader>cm :call pandoc#MyConvertMappingHelper("convert-to-markdown.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cM :call pandoc#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cM <C-o>:call pandoc#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
" Kill current conversion
nnoremap <buffer><silent> <LocalLeader>ck :call KillProcess()<CR>
command! RemoveAuxFiles :execute '!' . fnamemodify('~/.vim/python-scripts/remove-aux-files.py', ':p') . ' ' . fnameescape(expand('%:p'))
nnoremap <buffer><silent> <LocalLeader>cK :RemoveAuxFiles<CR>

" Following sets up autogroup to call .pdf conversion script when leaving
" insert mode.
function! s:ToggleAutoPDF()
	if b:autoPDFEnabled
		let b:autoPDFEnabled = 0
		augroup AutoPDFConvert
			autocmd!
		augroup END
		echohl Comment
		echom 'Auto PDF Off...'
		echohl None
	else
		let b:autoPDFEnabled = 1
		augroup AutoPDFConvert
			autocmd!
			autocmd BufWritePost <buffer> :call <SID>MyConvertHelper("markdown-to-PDF-LaTeX.py")
		augroup END
		echohl Comment
		echom 'Auto PDF On...'
		echohl None
	endif
endfunction
nnoremap <buffer><silent> <LocalLeader>ca :call <SID>ToggleAutoPDF()<CR>
inoremap <buffer><silent> <LocalLeader>ca <C-o>:call <SID>ToggleAutoPDF()<CR>

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

function! s:GoToReference()
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
nnoremap <silent><buffer> <C-]> :call <SID>GoToReference()<CR>

" Find Comments {{{2
" -------------
" Note: allow remaps so that it works with vim-slash
nmap <buffer><silent> <LocalLeader>fc /\[.\{-}\]{\.[a-z]\{-}}/<CR>

" Citations {{{2
" ---------
" Make insertion of citations easier by automatically calling autocomplete
"inoremap <buffer> @ @<C-x><C-o>

" Find page references needing complete citations
noremap <buffer><silent> <LocalLeader>fr /(\(\d\+f\{0,2}\(, \d\+f\{0,2}\\|--\d\+\)\?\))<CR>

" To break undo sequence automatically {{{2
" ------------------------------------
" These interfere with abbreviations if `inoremap` is used, so I'm using
" simply `imap`.
imap <buffer><silent> . .<C-G>u
imap <buffer><silent> ! !<C-G>u
imap <buffer><silent> ? ?<C-G>u
imap <buffer><silent> ; ;<C-G>u
"imap <buffer><silent> ] ]<C-G>u
" The following interferes with listmode.
"imap <buffer><silent> <CR> <CR><C-G>u

" Spelling {{{2
" --------
nnoremap <buffer><silent> <LocalLeader>S a<C-X><C-S>
inoremap <buffer><silent> <LocalLeader>S <C-X><C-S>

" Display word count {{{2
" ------------------
noremap <buffer> <LocalLeader>w g<C-g>
inoremap <buffer> <LocalLeader>w <C-o>g<C-g>

" List mode {{{2
" ---------
" Start with listmode on by default ... but don't toggle list mode if the
" buffer has already been loaded.
if !exists('b:listmode')
	let b:listmode=1
	call listmode#ListModeOn(0)
endif

" Miscellaneous {{{2
" -------------
" In visual and normal modes, select text to be indexed and hit <ctrl-x> ("indeX")
vnoremap <buffer><silent> <C-x> c<i <Esc>pa><Esc>mip`i
nnoremap <buffer><silent> <C-x> ciw<i <Esc>pa><Esc>mip`i
" Jump to corresponding line in Skim.app
if has('nvim')
	command! JumpToPDF silent call jobstart("/usr/bin/env python3 " . fnamemodify("~/.vim/python-scripts/jump-to-line-in-Skim.py", ":p") . ' "' . expand('%:p') . '" ' . line("."), {"on_stdout": "DisplayMessages", "on_stderr": "DisplayError"})
else  " normal vim
	command! JumpToPDF silent call job_start("/usr/bin/env python3 " . fnamemodify("~/.vim/python-scripts/jump-to-line-in-Skim.py", ":p") . ' "' . expand('%:p') . '" ' . line("."), {"out_cb": "DisplayMessages", "err_cb": "DisplayError"})
endif
nnoremap <buffer><silent> <LocalLeader>j :JumpToPDF<CR>
" nnoremap <buffer><silent> <LocalLeader>j :call system('python ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
inoremap <buffer><silent> <LocalLeader>j <C-o>:call system('python ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
" Open Dictionary.app with word under cursor
nnoremap <buffer><silent> K :!open dict:///<cword><CR><CR>
" Faster mapping to bibliography/cross-reference completion
"inoremap <buffer> <C-c> <C-x><C-u>
" Italicize/boldface current word
nnoremap <buffer><silent> <D-e> "zciw*<Esc>"zpa*<Esc>
inoremap <buffer><silent> <D-e> <Esc>"zciw*<Esc>"zpa*
vnoremap <buffer><silent> <C-e> c*<C-r>"*<Esc>gvlol
nnoremap <buffer><silent> <D-b> "zciw**<Esc>"zpa**<Esc>
inoremap <buffer><silent> <D-b> <Esc>"zciw**<Esc>"zpa**
vnoremap <buffer><silent> <C-b> c**<C-r>"**<Esc>gvlloll

" Next mapping will delete the surrounding comment, leaving the inside text.
" Note that it doesn't do any checking to see if the cursor is actually in a
" comment.
nnoremap <buffer><silent> dsc mclT[dt]hPldf}`ch
" Next mappings allow for changing the comment type of next comment. Note that
" it doesn't do anything about checking to see where that comment is.
nnoremap <buffer><silent> cscc mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwcomment<Esc>`c
nnoremap <buffer><silent> cscm mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwmargin<Esc>`c
nnoremap <buffer><silent> cscf mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwfixme<Esc>`c
nnoremap <buffer><silent> csch mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwhighlight<Esc>`c
nnoremap <buffer><silent> cscs mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwsmcaps<Esc>`c
"}}}


" ============================================================================ }}}
" TextObjects {{{1
" ============================================================================
" Creates text object for deleting/changing/etc.
call textobj#user#plugin('pandoccomments', {
\	'comment': {
\		'pattern': ['\[', '\]{\.\(comment\|margin\|fixme\|highlight\|smcaps\)}'],
\		'select-a': 'ac',
\		'select-i': 'ic',
\	},
\ })

" TODO: Create text objects for section (`aS` includes section header; `iS`
" does not)

" ============================================================================ }}}
" Completion Function for Attributes/Bibliography {{{1
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

function! GetBibEntries(base)

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

function! MyCompletion(findstart, base)
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
		let l:bibMatches = GetBibEntries(a:base)
		let l:completionList += l:bibMatches
		return {'words': l:completionList}
	endif
endfunction

setlocal omnifunc=MyCompletion

" The following will close the preview window that is automatically opened by
" the completion function.
augroup Completion
	autocmd!
	autocmd CompleteDone * pclose
augroup END

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

function! InsertSnippet(key)
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

function! JumpOutOfSnippet(line, cursor)
	let [l:key, l:next] = b:recursiveSnippetList[-1]
	call remove(b:recursiveSnippetList, - 1)
	let [l:compLength, l:keyLength, l:left, l:right, l:next] =
				\ s:SimpleSnippetsList[l:key]
	let l:matchPos = match(a:line, escape(l:right, '$.*~\^['), a:cursor - 1)
	let l:typed = repeat("\<Right>", len(l:right) + l:matchPos - a:cursor + 1)
	if l:next !=# ''
		let l:typed .= repeat(' ', len(l:next)) . InsertSnippet(l:next)
	endif
	return l:typed
endfunction

function! RecursiveSimpleSnippets()
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
			return InsertSnippet(l:key)
		endif
	endfor
	" No match, so check if need to jump to end of snippet
	if len(b:recursiveSnippetList) > 0
		return JumpOutOfSnippet(l:line, l:cursor)
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

inoremap <expr> <Tab> pumvisible() ? "\<C-N>" : RecursiveSimpleSnippets()
inoremap <expr> <S-Tab> pumvisible() ? "\<C-P>" : "\<S-Tab>"

" ============================================================================ }}}
" TOC Support {{{1
" ============================================================================

function! s:ShowTOC()
	" Show the TOC in location list, and allow user to jump to locations by
	" hitting `<CR>` (closing location list) or `<C-CR>` (leaving location
	" list open). Much of this is taken from vim-pandoc's TOC code.
	normal! mt
	silent lvimgrep /^#\{1,6}\s/ %
	if len(getloclist(0)) == 0
		return
	endif
	try
		topleft lopen
		lclose
		lopen
	catch /E776/  " no location list
		echohl ErrorMsg
		echom 'No TOC to show!'
		echohl None
	endtry
	setlocal statusline=TOC
	set modifiable
	silent %substitute/^\([^|]*|\)\{2,2} //e
	for l:line in range(1, line('$'))
		let l:heading = getloclist(0)[l:line - 1]
		let l:level = len(matchstr(l:heading.text, '#*', '')) - 1
		let l:heading.text = '• ' . l:heading.text[l:level + 2:]
		let l:heading.text = matchstr(l:heading.text, '.\{-}\ze\({.\{-}}\)\?$')
		call setline(l:line, repeat(' ', 4 * l:level) . l:heading.text)
	endfor
	set nomodified
	set nomodifiable

	syn match TOCHeader /^.*\n/
	syn match TOCBullet /•/ contained containedin=TOCHeader
	highlight link TOCHeader Directory
	highlight link TOCBullet Delimiter

	setlocal linebreak
	setlocal foldmethod=indent
	setlocal shiftwidth=4
	normal! zRgg

	noremap <buffer> q :lclose<CR>`t
	noremap <buffer> <CR> <CR>:lclose<CR>
	noremap <buffer> <C-CR> <CR>
endfunction

command! TOC call <SID>ShowTOC()


" ============================================================================ }}}
" Other {{{1
" ============================================================================
" Don't want numbers displayed for pandoc documents
"setlocal nonumber
"setlocal norelativenumber
" Turn on spell checking
setlocal spell spelllang=en_us
" Turn off checking for capitalization errors
"setlocal spellcapcheck=
setlocal equalprg=pandoc\ -t\ markdown+table_captions-simple_tables-multiline_tables-grid_tables+pipe_tables+line_blocks-fancy_lists+definition_lists+example_lists\ --wrap=none\ --from=markdown-fancy_lists\ --atx-headers\ --standalone\ --preserve-tabs\ --normalize
" Allow wrapping past BOL and EOL when using `h` and `l`
set whichwrap+=h,l


" ============================================================================ }}}
" Abbreviations {{{1
" ============================================================================
inoreabbr abotu about
inoreabbr Ccd Cognitive--conative divide
inoreabbr ccd cognitive--conative divide
inoreabbr cn communal norm
inoreabbr cns communal norms
inoreabbr Cor Community of respect
inoreabbr cor community of respect
inoreabbr Cors Communities of respect
inoreabbr cors communities of respect
inoreabbr Dof Direction of fit
inoreabbr dof direction of fit
inoreabbr Em Emotion
inoreabbr em emotion
inoreabbr Emo Emotion
inoreabbr emo emotion
inoreabbr Emos Emotions
inoreabbr emos emotions
inoreabbr Emotino Emotion
inoreabbr emotino emotion
inoreabbr Emotinos Emotions
inoreabbr emotinos emotions
inoreabbr Ems Emotions
inoreabbr ems emotions
inoreabbr fo of
inoreabbr ghp Greatest Happiness Principle
inoreabbr hte the
inoreabbr improtant important
inoreabbr Mtw Mind-to-world
inoreabbr mtw mind-to-world
inoreabbr nad and
inoreabbr nto not
inoreabbr ot to
inoreabbr phi philosophy
inoreabbr psy psychology
inoreabbr Ra Reactive attitude
inoreabbr ra reactive attitude
inoreabbr Ras Reactive attitudes
inoreabbr ras reactive attitudes
inoreabbr res responsible
inoreabbr Rr Recognition respect
inoreabbr rr recognition respect
inoreabbr si is
inoreabbr Taht That
inoreabbr taht that
inoreabbr Teh The
inoreabbr teh the
inoreabbr tehre there
inoreabbr Thta That
inoreabbr thta that
inoreabbr Wtm World-to-mind
inoreabbr wtm world-to-mind
