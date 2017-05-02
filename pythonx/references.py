from re import findall, match, search, sub, IGNORECASE
# from vim import eval


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
    bibDataList = findall(r'@[^@]*', bibText)
    return bibDataList


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
        entry = editor
        shortEntry = editor[:editor.find(',')]
    else:
        entry = author
        shortEntry = author[:author.find(',')]
    year = retrieveBibField(bibItem, 'year')
    entry += ' (' + year + ').'
    shortEntry += '(' + year + ').'
    booktitle = retrieveBibField(bibItem, 'booktitle')
    if booktitle != '':
        entry += ' *' + booktitle + '*.'
        shortEntry += ' *' + booktitle + '*.'
    else:
        entry += ' *' + retrieveBibField(bibItem, 'title') + '*.'
        shortEntry += ' *' + retrieveBibField(bibItem, 'title') + '*.'
    publisher = retrieveBibField(bibItem, 'publisher')
    if publisher != '':
        address = retrieveBibField(bibItem, 'address')
        if address:
            entry += ' ' + address + ': ' + publisher + '.'
        else:
            entry += ' ' + publisher + '.'
    doi = retrieveBibField(bibItem, 'Doi')
    if doi:
        entry += ' <http://doi.org/' + doi + '>'
    else:
        url = retrieveBibField(bibItem, 'Url')
        if url:
            entry += ' <' + url + '>'
    return entry, shortEntry


def constructArticleEntry(bibItem):
    """Create markdown bibliography entry for article"""
    author = retrieveBibField(bibItem, 'author')
    entry = author + ' (' + retrieveBibField(bibItem, 'year') + '). "' + \
        retrieveBibField(bibItem, 'title') + '". *' + \
        retrieveBibField(bibItem, 'journal') + '*.'
    shortEntry = author[:author.find(',')] + '(' + \
        retrieveBibField(bibItem, 'year') + '). "' + \
        retrieveBibField(bibItem, 'title') + '". *' + \
        retrieveBibField(bibItem, 'journal') + '*.'
    volume = retrieveBibField(bibItem, 'volume')
    if volume != '':
        entry += ' ' + volume + ':'
        entry += retrieveBibField(bibItem, 'pages') + '.'
    doi = retrieveBibField(bibItem, 'Doi')
    if doi:
        entry += ' <http://doi.org/' + doi + '>'
    else:
        url = retrieveBibField(bibItem, 'Url')
        if url:
            entry += ' <' + url + '>'
    return entry, shortEntry


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
    entry = author + ' (' + year + '). "' + \
        retrieveBibField(bibItem, 'title') + '". In ' + crossref + \
        retrieveBibField(bibItem, 'pages') + '.'
    doi = retrieveBibField(bibItem, 'Doi')
    if doi:
        entry += ' <http://doi.org/' + doi + '>'
    else:
        url = retrieveBibField(bibItem, 'Url')
        if url:
            entry += ' <' + url + '>'
    shortEntry = author[:author.find(',')] + '(' + year + '). "' + \
        retrieveBibField(bibItem, 'title') + '". In ' + crossref + '.'
    return entry, shortEntry


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
    key = search(r'@[^{]*{([^,]*)', bibItem, IGNORECASE).group(1)
    # Now construct rough markdown representations of citation
    if entryType == 'book':
        entry, shortEntry = constructBookEntry(bibItem)
    elif entryType == 'article':
        entry, shortEntry = constructArticleEntry(bibItem)
    elif entryType == 'incollection':
        try:
            crossref = search(r'(\s*crossref\s*=\s*{)(.*)}[,}]', bibItem,
                              IGNORECASE).group(2)
            for item in bibDataList:
                if item.startswith('@book{' + crossref):
                    nul1, nul2, crossref = constructBibEntry(item, bibDataList)
                    break
        except AttributeError:
            crossref = ''
        entry, shortEntry = constructInCollEntry(bibItem, crossref)
    else:  # Some other entry type; make it minimal....
        author = retrieveBibField(bibItem, 'author')
        year = retrieveBibField(bibItem, 'year')
        title = retrieveBibField(bibItem, 'title')
        entry = author + ' (' + year + '). "' + title + '".'
        shortEntry = author[:author.find(',')] + '(' + \
            year + '). ' + '"' + title + '".'
        book = retrieveBibField(bibItem, 'booktitle')
        if book:
            entry += ' In *' + book + '*.'
            shortEntry += ' In *' + book + '*.'
    entry = removeLatex(entry)
    shortEntry = removeLatex(shortEntry)
    return key, entry, shortEntry


def constructEntryDict(bibItem, bibDataList):
    # Construct dictionary entry from full/short entry
    key, entry, shortEntry = constructBibEntry(bibItem, bibDataList)
    entryDict = {'word': key}
    entryDict['abbr'] = removeLatex(shortEntry)
    # abbrLength = int(eval('s:abbrLength'))  # Length of key abbreviations
    # entryDict['abbr'] = key[:abbrLength]
    # entryDict['info'] = removeLatex(entry)
    # entryDict['menu'] = removeLatex(title)[:60]
    entryDict['icase'] = 1
    return entryDict


def constructOneEntry(bibKey):
    bibDataList = getBibData()
    bibItem = None
    for item in bibDataList:
        # Note: bibKey starts with '@', which needs to be removed
        if '{' + bibKey[1:] + ',' in item:
            bibItem = item
            break
    if bibItem:
        key, entry, shortentry = constructBibEntry(bibItem, bibDataList)
        return entry
    else:
        return ''


def createBibList(base):
    """Create list of entries that match on every word in base"""
    bibDataList = getBibData()
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
    matchedList = sorted(matchedList,
                         key=lambda item: match('@[^{]*{([^,]*)', item,
                                                IGNORECASE).group(1))
    constructedList = [constructEntryDict(item, bibDataList) for item in
                       matchedList]
    return constructedList
