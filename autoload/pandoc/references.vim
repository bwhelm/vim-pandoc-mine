scriptencoding utf-8

" Following creates tag-like jumps for cross-references
function! s:JumpToReference(searchString) abort
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
        silent execute l:commandString
        " Visually select matched string, switch to front end, and return to
        " normal mode. (Note: this must be in double-quotes!)
        silent execute "normal! gno\<Esc>"
        return
    catch /E486/  " If search string not found ...
        " ... Need to find all headers in document, create header IDs for
        " them, checking to see if that's what we're looking for.
        let l:text = getline(0, '$')
        for l:line in l:text
            if l:line =~# '^#\{1,6}\s'
                if a:searchString[1:] ==# <SID>GenerateHeaderID(l:line)
                    let l:line = substitute(l:line, '/', '\\/', 'g')
                    silent execute '/' . l:line
                    silent execute "normal! gno\<Esc>"
                    return
                endif
            endif
        endfor
        " The pandoc method is pretty slow, though very accurate. Using my
        " citation is much faster, and probably accurate enough for most
        " purposes.
        "let l:biblio = system("echo '" . a:searchString . "' | pandoc --bibliography=/Users/bennett/Library/texmf/bibtex/bib/bibdatabase-new.bib --bibliography=/Users/bennett/Library/texmf/bibtex/bib/bibdatabase-helm-new.bib --filter=/usr/local/bin/pandoc-citeproc -t plain")
        if b:system ==# 'ios'  " if on iPad, need to use vim rather than python
            let l:biblio = s:constructOneEntry(a:searchString)
        else  " if not on iPad, python is faster
            if has('nvim')
                python3 import references
                let l:biblio = py3eval("references.constructOneEntry('" . a:searchString . "')")
            else
                pythonx import references
                let l:biblio = pyxeval("references.constructOneEntry('" . a:searchString . "')")
            endif
        endif
        if l:biblio !=# ''
            new +setlocal\ buftype=nofile\ bufhidden=wipe\ noswapfile\ nobuflisted\ nospell\ modifiable\ statusline=Reference
            resize 5
            put! =l:biblio
            " Set filetype *after* adading content so as not to trigger
            " template prompt.
            setlocal filetype=pandoc
            $delete_
            " Move to URL (if there is one; fail silently if not)
            call search('<\zs.', 'W')
            " Use next line only with pandoc method
            nmap <buffer> <CR> <Plug>NetrwBrowseX
            nnoremap <silent><buffer> q :quit<CR>
            nnoremap <silent><buffer> <Esc> :quit<CR>
        else
            echohl WarningMsg
            echom 'Cannot find ID.'
            echohl None
        endif
    endtry
endfunction

function! pandoc#references#GoToReference() abort
    " Need ignorecase and smartcase turned off ... but save values to restore
    " later
    let l:ignorecaseSave = &ignorecase
    let l:smartcaseSave = &smartcase
    set noignorecase nosmartcase
    mark x
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

function! s:GenerateHeaderID(header) abort
    " Generates pandoc-style identifiers for headers. Assumes headers are
    " relatively well behaved (without much formatting, for example), and so
    " is somewhat fragile.
    let l:header = tolower(a:header)
    let l:header = matchstr(l:header, '#\{1,6}[^A-z]\+\zs.\{-}\ze\s*$')
    let l:header = substitute(l:header, ' ', '-', 'g')
    let l:header = substitute(l:header, '[^A-Za-z0-9_\-.]', '', 'g')
    let l:header = substitute(l:header, '---', '', 'g')
    let l:header = substitute(l:header, '--', '', 'g')
    if empty(l:header)
        let l:header = 'section'
    endif
    return l:header
endfunction

function! s:FindHeaderID(base) abort
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
        elseif match(l:line, '^\s*!\[\(.*\)\]([^)]*){#\([[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß\-_+:]\+\).\{-}}') == 0
            " Figure header
            if l:line =~ '#' . a:base
                let l:match = matchlist(l:line, '^\s*!\[\(.*\)\]([^)]*){#\([[:alnum:]äëïöüáéíóúàèìòùłßÄËÏÖÜÁÉÍÓÚÀÈÌÒÙŁß\-_+:]\+\).\{-}}')
                let l:completionList += [{'word': l:match[2],
                            \ 'abbr': 'Figure: ' . l:match[1],
                            \ 'icase': 1}]
            endif
        elseif match(l:line, '^(\?@[^.]\{1,20}[).]\s') == 0
            " Named list item
            if l:line =~ a:base
                let l:match = matchstr(l:line, l:matchItemPattern)
                let l:completionList += [{'word': l:match,
                            \ 'abbr': l:match . ' (List ID)',
                            \ 'icase': 1}]
                            "\ 'menu': '(List ID)',
                            "\ 'info': l:line}]
            endif
        endif
    endfor
    return l:completionList
endfunction

function! s:GetBibEntries(base) abort
    if b:system ==# 'ios'  " if on iPad, need to use vim rather than python
        return s:createBibList(a:base)
    else  " if not on iPad, python is faster
        if has('nvim')
            python3 import references
            return py3eval("references.createBibList('" . a:base . "')")
        else
            pythonx import references
            return pyxeval("references.createBibList('" . a:base . "')")
        endif
    endif
endfunction

function! pandoc#references#MyCompletion(findstart, base) abort
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
        let l:bibMatches = <SID>GetBibEntries(a:base)
        if len(l:bibMatches) == 1 && a:base == l:bibMatches[0]['word']
            " If it's the only match and it's already complete in the text,
            " don't pop-up a menu.
            return ''
        endif
        let l:completionList += l:bibMatches
        return {'words': l:completionList}
    endif
endfunction


" " The following will close the preview window that is automatically opened by
" " the completion function.
" augroup Completion
"     autocmd!
"     autocmd CompleteDone * pclose
" augroup END


function! s:GetBibData() abort
    " Read data from .bib files
    if b:system ==# 'ios'
        let l:file = fnamemodify('~/Documents/research/+texmf/bibtex/bib/bibdatabase-new.bib', ':p')
    else
        let l:file = system('kpsewhich bibdatabase-new.bib')[:-2]
    endif
    let l:bibText = join(readfile(l:file), "\n")
    if b:system ==# 'ios'
        let l:file = fnamemodify('~/Documents/research/+texmf/bibtex/bib/bibdatabase-helm-new.bib', ':p')
    else
        let l:file = system('kpsewhich bibdatabase-helm-new.bib')[:-2]
    endif
    let l:bibText .= join(readfile(l:file), "\n")
    return l:bibText
endfunction


function! s:retrieveBibField(bibItem, fieldname) abort
    try
        let l:field = matchstr(a:bibItem, '\c\n\s*' . a:fieldname . '\s*=\s*{\zs.\{-}\ze}[,}]\{0,2}\n')
    catch
        let l:field = ''
    endtry
    return l:field
endfunction


function! s:getAuthorLast(author) abort
    if a:author =~# ','
        let l:authorLast = matchstr(a:author, '^[^,]*')
    else
        let l:authorLast = matchstr(a:author, '\s\S\+$')
    endif
    return l:authorLast
endfunction


function! s:constructBookEntry(bibItem, desired) abort
    " Create markdown bibliography entry for book
    let l:author = s:retrieveBibField(a:bibItem, 'author')
    if l:author ==# ''
        let l:editor = s:retrieveBibField(a:bibItem, 'editor')
        let l:entry = l:editor
        let l:shortEntry = s:getAuthorLast(l:editor)
    else
        let l:entry = l:author
        let l:shortEntry = s:getAuthorLast(l:author)
    endif
    let l:year = s:retrieveBibField(a:bibItem, 'year')
    let l:entry .= ' (' . l:year . ').'
    let l:shortEntry .= '(' . l:year . ').'
    let booktitle = s:retrieveBibField(a:bibItem, 'booktitle')
    if l:booktitle !=# ''
        let l:entry .= ' *' . l:booktitle . '*.'
        let l:shortEntry .= ' *' . l:booktitle . '*.'
    else
        let l:entry .= ' *' . s:retrieveBibField(a:bibItem, 'title') . '*.'
        let l:shortEntry .= ' *' . s:retrieveBibField(a:bibItem, 'title') . '*.'
    endif
    let l:publisher = s:retrieveBibField(a:bibItem, 'publisher')
    if l:publisher !=# ''
        let address = s:retrieveBibField(a:bibItem, 'address')
        if address
            let l:entry .= ' ' . address . ': ' . l:publisher . '.'
        else
            let l:entry .= ' ' . l:publisher . '.'
        endif
    endif
    let l:doi = s:retrieveBibField(a:bibItem, 'Doi')
    if l:doi
        let l:entry .= ' <http://doi.org/' . l:doi . '>'
    else
        let l:url = s:retrieveBibField(a:bibItem, 'Url')
        if l:url
            let l:entry .= ' <' . l:url . '>'
        endif
    endif
    if a:desired ==# 'entry'
        return l:entry
    else
        return l:shortEntry
    endif
endfunction


function! s:constructArticleEntry(bibItem, desired) abort
    " Create markdown bibliography entry for article
    let l:author = s:retrieveBibField(a:bibItem, 'author')
    if a:desired ==# 'entry'
        let l:entry = l:author . ' (' . s:retrieveBibField(a:bibItem, 'year') . '). "'
                \ . s:retrieveBibField(a:bibItem, 'title') . '". *'
                \ . s:retrieveBibField(a:bibItem, 'journal') . '*.'
        let l:volume = s:retrieveBibField(a:bibItem, 'volume')
        if l:volume !=# ''
            let l:entry .= ' ' . l:volume . ':'
            let l:entry .= s:retrieveBibField(a:bibItem, 'pages') . '.'
        endif
        let l:doi = s:retrieveBibField(a:bibItem, 'Doi')
        if l:doi
            let l:entry .= ' <http://doi.org/' . l:doi . '>'
        else
            let l:url = s:retrieveBibField(a:bibItem, 'Url')
            if l:url
                let l:entry .= ' <' . l:url . '>'
            endif
        endif
        return l:entry
    elseif a:desired ==# 'short'
        let shortEntry = s:getAuthorLast(l:author) . '('
                \ . s:retrieveBibField(a:bibItem, 'year') . '). "'
                \ . s:retrieveBibField(a:bibItem, 'title') . '". *'
                \ . s:retrieveBibField(a:bibItem, 'journal') . '*.'
        return shortEntry
    endif
endfunction


function! s:constructInCollEntry(bibItem, crossref, desired) abort
    let l:crossref = a:crossref
    """Create markdown bibliography entry for incollection"""
    let l:year = s:retrieveBibField(a:bibItem, 'year')
    if l:year ==# ''
        try
            let l:year = matchstr(l:crossref, '(\zs[^)]*\ze)')
            " year = search(r'\(([^)]*)\)', crossref).group(1)
        catch
        endtry
    endif
    let l:author = s:retrieveBibField(a:bibItem, 'author')
    if l:author ==# ''
        try
            let l:author = matchstr(l:crossref, '[^(]*')
            " author = search(r'[^(]*', l:crossref).group(0)
        catch
        endtry
    endif
    if l:crossref ==# ''
        let l:crossref = '*' . s:retrieveBibField(a:bibItem, 'booktitle') . '*'
    endif
    if a:desired ==# 'entry'
        let l:entry = l:author . ' (' . year . '). "'
                \ . s:retrieveBibField(a:bibItem, 'title') . '". In ' . l:crossref
                \ . ' ' . s:retrieveBibField(a:bibItem, 'pages') . '.'
        let l:doi = s:retrieveBibField(a:bibItem, 'Doi')
        if l:doi
            let l:entry .= ' <http://doi.org/' . l:doi . '>'
        else
            let l:url = s:retrieveBibField(a:bibItem, 'Url')
            if l:url
                let l:entry .= ' <' . l:url . '>'
            endif
        endif
        return l:entry
    else
        let l:authorLast = s:getAuthorLast(l:author)
        let l:shortEntry = l:authorLast . '(' . l:year . '). "'
                \ . s:retrieveBibField(a:bibItem, 'title') . '". In ' . l:crossref
                \ . '.'
        return l:shortEntry
    endif
endfunction


function! s:removeLatex(text) abort
    """Quick substitution of markdown for common LaTeX"""
    let l:text = substitute(a:text, '\\emph{\([^}]*\)}', '*\1*', 'g')  " Swap emphasis
    let l:text = substitute(l:text, '\\mkbibquote{\([^}]*\)}', '"\1"', 'g')  " Remove mkbibquote
    let l:text = substitute(l:text, '{\?\\ldots{\?}\?', '...', 'g')  " Replace `...`
    let l:text = substitute(l:text, '{\\''\\\(.\)}', '\1', 'g')  " Replace latex accents
    " text = sub(r"{\\'\\(.)}", r'\1', text)  # Replace latex accents
    let l:text = substitute(l:text, '\\[''`"^v]', '', 'g')  " Replace latex accents
    " text = sub(r"\\['`\"^v]", '', text)  # Replace latex accents
    let l:text = substitute(l:text, '{\(.\)}', '\1', 'g')  " Remove braces around single letters
    " text = sub(r'{(.)}', r'\1', text)  # Remove braces around single letters
    let l:text = substitute(l:text, '{}', '', 'g')  " Remove excess braces
    " text = text.replace('{}', '')  # Remove excess braces
    let l:text = substitute(l:text, '\\v', '', 'g')  " Remove 'v' accent
    " text = text.replace("\\v", "")  # Remove 'v' accent
    let l:text = substitute(l:text, '\\&', '&', 'g')  " Don't escape `&`
    " text = text.replace('\\&', '&')  # Don't escape `&`
    return l:text
endfunction


function! s:constructBibEntry(bibItem, bibDataText, desired) abort
    " Create markdown bibliography entry for .bib entry. a:desired can be
    " either 'key', 'entry', or 'short', depending on the desired return
    " value.
    let l:bibDataList = split(a:bibDataText, '@')[1:]
    " First extract relevant bibtex fields...
    let l:entryType = matchstr(a:bibItem, '^.\{-}\ze{')
    let l:key = matchstr(a:bibItem, '^[^{]*{\zs[^,]\+')
    if a:desired ==# 'key'
        return l:key
    endif
    " Now construct rough markdown representations of citation
    if a:desired ==# 'entry'
        if l:entryType ==# 'book'
            let l:entry = s:constructBookEntry(a:bibItem, 'entry')
        elseif l:entryType ==# 'article'
            let l:entry = s:constructArticleEntry(a:bibItem, 'entry')
        elseif l:entryType ==# 'incollection'
            " ==========
            try
                let l:crossref = matchstr(a:bibItem, '\c\n\s*crossref\s*=\s*{\zs.\{-}\ze}[,}]*\n')
                " let l:crossref = search(r'(\s*crossref\s*=\s*{)(.*)}[,}]', bibItem,
                "                   IGNORECASE).group(2)
                for l:item in l:bibDataList
                    if l:item =~ 'book{' . l:crossref
                        let l:crossref = s:constructBibEntry(l:item, a:bibDataText, 'short')
                        break
                    endif
                endfor
            catch
                let l:crossref = ''
            endtry
            let l:entry = s:constructInCollEntry(a:bibItem, l:crossref, 'entry')
            " ================
        else  " Some other entry type; make it minimal....
            let l:author = s:retrieveBibField(a:bibItem, 'author')
            let l:year = s:retrieveBibField(a:bibItem, 'year')
            let l:title = s:retrieveBibField(a:bibItem, 'title')
            let l:entry = l:author . ' (' . l:year . '). "' . l:title . '".'
            " let l:short = l:author[:l:author.find(',')] . '(' . l:year . '). ' . '"' . l:title . '".'
            let l:book = s:retrieveBibField(a:bibItem, 'booktitle')
            if l:book !=# ''
                let l:entry .= ' In *' . book . '*.'
                " let l:short .= ' In *' . book . '*.'
            endif
        endif
        return s:removeLatex(l:entry)
    elseif a:desired ==# 'short'
        if l:entryType ==# 'book'
            let l:short = s:constructBookEntry(a:bibItem, 'short')
        elseif l:entryType ==# 'article'
            let l:short = s:constructArticleEntry(a:bibItem, 'short')
        elseif l:entryType ==# 'incollection'
            try
                let l:crossref = matchstr(a:bibItem, '\c\n\s*crossref\s*=\s*{\zs.\{-}\ze}[,}]*\n')
                " let l:crossref = search(r'(\s*crossref\s*=\s*{)(.*)}[,}]', bibItem,
                "                   IGNORECASE).group(2)
                for l:item in l:bibDataList
                    if l:item =~ 'book{' . l:crossref
                        let l:crossref = s:constructBibEntry(l:item, a:bibDataText, 'short')
                        break
                    endif
                endfor
            catch
                let l:crossref = ''
            endtry
            let l:short = s:constructInCollEntry(a:bibItem, l:crossref, 'short')
        else  " Some other entry type; make it minimal....
            let l:author = s:retrieveBibField(a:bibItem, 'author')
            let l:year = s:retrieveBibField(a:bibItem, 'year')
            let l:title = s:retrieveBibField(a:bibItem, 'title')
            let l:authorLast = s:getAuthorLast(l:author)
            let l:short = l:authorLast . '(' . l:year . '). ' . '"' . l:title . '".'
            let l:book = s:retrieveBibField(a:bibItem, 'booktitle')
            if l:book !=# ''
                let l:short .= ' In *' . book . '*.'
            endif
        endif
        return s:removeLatex(l:short)
    endif
endfunction


function! s:constructEntryDict(bibItem, bibDataText) abort
    " Construct dictionary entry from full/short entry
    let l:bibDataList = split(a:bibDataText, '@')[1:]
    let l:key = s:constructBibEntry(a:bibItem, a:bibDataText, 'key')
    let l:shortEntry = s:constructBibEntry(a:bibItem, a:bibDataText, 'short')
    let l:entryDict = {'word': l:key}
    let l:entryDict['abbr'] = s:removeLatex(l:shortEntry)
    " abbrLength = int(eval('s:abbrLength'))  # Length of key abbreviations
    " entryDict['abbr'] = key[:abbrLength]
    " entryDict['info'] = s:removeLatex(entry)
    " entryDict['menu'] = s:removeLatex(title)[:60]
    let l:entryDict['icase'] = 1
    return l:entryDict
endfunction


function! s:constructOneEntry(bibKey) abort
    let l:bibDataText = s:GetBibData()
    let l:bibDataList = split(l:bibDataText, '@')[1:]
    let l:bibItem = ''
    for l:item in l:bibDataList
        if l:item =~ '{' . a:bibKey[1:] . ','
            let l:bibItem = l:item
            break
        endif
    endfor
    if l:bibItem !=# ''
        let l:entry = s:constructBibEntry(l:bibItem, l:bibDataText, 'entry')
        return l:entry
    else
        return ''
    endif
endfunction


function! s:sortByKey(i1, i2) abort
    let l:i1 = matchstr(a:i1, '^[^{]*{\zs[^,]*')
    let l:i2 = matchstr(a:i2, '^[^{]*{\zs[^,]*')
    return l:i1 ==# l:i2 ? 0 : l:i1 > l:i2 ? 1 : -1
endfunction


function! s:createBibList(base) abort
    """Create list of entries that match on every word in base"""
    let l:bibDataText = s:GetBibData()
    let l:bibDataList = split(l:bibDataText, '@')[1:]
    let l:baseList = split(tolower(a:base), ' ')  " List of terms to match
    let l:matchedList = []  " List of matched bibliography items
    for l:bibItem in l:bibDataList
        if l:bibItem !~# '^comment{'
            let l:keep = 1
            for l:baseItem in l:baseList
                if tolower(l:bibItem) !~ l:baseItem
                    let l:keep = 0
                    break
                endif
            endfor
            if l:keep
                call add(l:matchedList, l:bibItem)
            endif
        endif
    endfor
    " Sort matchedList by citation key (`AuthorDATETitle`)
    call sort(l:matchedList, 's:sortByKey')
    let l:constructedList = []
    for l:item in l:matchedList
        call add(l:constructedList, s:constructEntryDict(l:item, l:bibDataText))
    endfor
    return l:constructedList
    " matchedList = sorted(matchedList,
    "                      key=lambda item: match('@[^{]*{([^,]*)', item,
    "                                             IGNORECASE).group(1))
    " constructedList = [constructEntryDict(item, bibDataText) for item in
    "                    matchedList]
    " return constructedList
endfunction
