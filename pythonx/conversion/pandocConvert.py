#!/usr/bin/env python3

"""
This script is designed to be called by another script in vim, providing the
information below to typeset the file in the given format.
Thus, the script should be called as follows:

    pandocConvert.py file TO_EXTENSION extraOptions bookOptions
         articleOptions filter, imageFormat

Here's what each of these are (read from stdin):
    * MARKDOWN_FILE: complete path to file to be converted
    * TO_EXTENSION: extension of file type to be converted to (e.g., '.html'
      or '.docx')
    * extraOptions: special options for this extension
    * bookOptions: options to send to pandoc if file is a book
    * articleOptions: options to send to pandoc if file is an article
    * addedFilter: a filter to call with the pandoc command
    * imageFormat: the format of any images to be produced
"""

from distutils.spawn import find_executable
from os import makedirs, listdir, environ, path, remove, rename
from subprocess import run, check_output, call
from sys import stdout, stderr
from time import time


TEMP_PATH = path.expanduser('~/tmp/pandoc/')
IMAGE_PATH = path.join(TEMP_PATH, 'Figures')


"""
Note: latexmk sends messages to stderr by default. I don't want that. So in
autoload/pandoc/conversion.vim, I'm sending stderr to vim messages and
stdout to the quickfix list. That means in defining writeError and
writeMessage, I'm sending errors to stdout and messages to stderr. That's
on purpose.
"""


def writeError(errorMsg):
    """
    Writes errorMsg to stderr
    """
    stdout.write(errorMsg + '\n')
    stdout.flush()
    return


def writeMessage(message):
    """
    Writes message to stdout
    """
    stderr.write(message + '\n')
    stderr.flush()
    return


def writeFile(fileName, text):
    """
    Write text to file on disk.
    """
    with open(fileName, 'w', encoding='utf-8') as f:
        f.write(text)


def removeOldFiles(directory, time):
    """
    Remove old files from `directory`, but not `reveal.js` symlink
    """
    modTime = 60 * 60 * 24 * 4  # max number of seconds to keep aux files
    for file in listdir(directory):
        if time - path.getmtime(path.join(directory, file)) > modTime and\
           file != 'reveal.js':
            try:
                remove(path.join(directory, file))
            except OSError:
                pass


def readFile(fileName):
    """
    Read text from file on disk.
    """
    with open(fileName, 'r', encoding='utf-8') as f:
        text = f.read()
    return text


def runPandoc(pandocCommandList):
    # writeError(str(pandocOptions))
    return run(pandocCommandList, shell=False).returncode


def removeAuxFiles(latexPath, baseFilename):
    # Remove aux files from LaTeX run
    for extension in ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk', 'fls', 'out',
                      'run.xml']:
        try:
            remove(path.join(latexPath, baseFilename + '.' + extension))
        except OSError:
            pass


def runLatex(latexPath, baseFileName, latexFormat, bookFlag):
    # Need to produce .pdf file, which will be opened by runLatex script...
    # chdir(latexPath)
    environ['PATH'] = '/Library/TeX/texbin:' + environ['PATH']
    # Note that `makeidx` is unhappy with my setting TEMP_PATH outside the
    # document directory out of security concerns. According to documentation
    # for latexmk, 'One way of [getting around] this is to temporarily set an
    # operating system environment variable openout_any to "a" (as in "all"),
    # to override the default "paranoid" setting.' I'll turn it on only if a
    # book is being typeset.
    if bookFlag:
        environ['openout_any'] = 'a'
    latexFile = path.join(latexPath, baseFileName + '.tex')

    texCommand = ['latexmk', latexFormat, '-f', '-synctex=1',
                  '-auxdir=' + TEMP_PATH, '-outdir=' + TEMP_PATH,
                  latexFile]
    latexError = call(texCommand, stdout=stdout)
    if latexError:
        removeAuxFiles(latexPath, baseFileName)
        writeError('LaTeX Error!: ' + str(latexError))
        return True  # Error
    return False     # No error


def convertMd(myFile, toFormat, toExtension, extraOptions, bookOptions,
              articleOptions, addedFilter, imageFormat):
    writeMessage('Starting conversion to ' + toExtension)

    # Make sure temporary path exists for LaTeX compilation
    try:
        makedirs(path.join(TEMP_PATH, 'Figures'))
    except OSError:
        pass

    pandocVersion = check_output(['/usr/bin/env', 'pandoc', '--version']) \
        .decode('utf-8').split('\n')[0].split(' ')[1].split('.')
    if int(pandocVersion[0]) < 2 and int(pandocVersion[1]) < 19:
        platform = 'old'
    else:
        platform = 'new'

    # Remove old files in TEMP_PATH folder...
    now = time()
    removeOldFiles(TEMP_PATH, now)
    removeOldFiles(path.join(TEMP_PATH, 'Figures'), now)

    filePath, fileName = path.split(myFile)
    baseFileName, fileExtension = path.splitext(fileName)
    if fileExtension != '.md':
        writeError('Need to provide a .md file!')
        exit(1)
    mdText = readFile(myFile)

    # Figure out command to send to pandoc
    suppressPdfFlag = False
    if toFormat == 'latexraw':
        suppressPdfFlag = True
        toFormat = 'latex'

    pandocOptions = ['--standalone',
                     '--from=markdown-fancy_lists',
                     '--mathml',
                     '--wrap=none',
                     '--to=' + toFormat + '+smart']
    pandocOptions += ['--lua-filter',
                      find_executable('fixYAML.lua')]
    pandocOptions += ['--lua-filter',
                      find_executable('pandocCommentFilter.lua')]
    pandocOptions += ['--lua-filter',
                      find_executable('internalreferences.lua')]
    pandocOptions += extraOptions.split()

    # addedFilter might be a String, a List, or None. This will add all to
    # pandocOptions.
    if addedFilter:
        if isinstance(addedFilter, str):
            addedFilter = [addedFilter]
        for myFilter in addedFilter:
            if myFilter[-3:] == 'lua':
                pandocOptions = pandocOptions + ['--lua-filter', myFilter]
            else:
                pandocOptions = pandocOptions + ['--filter', myFilter]

    # Check to see if we need to use chapters or sections for 1st-level heading
    bookFlag = False

    # When toExtension == '.tex', latexFormat determines how latexmk creates a
    # pdf file (whether using pdflatex, lualatex, or xelatex). Default is
    # pdflatex (= '-pdf').
    latexFormat = '-pdf'

    mdTextSplit = mdText.splitlines()
    for lineIndex in range(len(mdTextSplit)):
        line = mdTextSplit[lineIndex].lower()
        if lineIndex == 0 and line != "---":
            break
        elif line.startswith('book: ') and line[6:] != 'false':
            # bookFlag can be "true", "section", "chapter", or "part"
            bookFlag = line[6:]
            if bookFlag == "true":  # Default to "chapter"
                bookFlag = "chapter"
        elif line.startswith('biblatex: true') and toExtension == '.tex':
            pandocOptions.append('--biblatex')
        elif line.startswith('htmltoc: true') and toExtension == '.html':
            pandocOptions.append('--toc')
        elif line.startswith('lualatex: true'):
            latexFormat = '-lualatex'
        elif line.startswith('xelatex: true'):
            latexFormat = '-xelatex'
        elif line[:3] in ('...', '---') and lineIndex != 0:
            break

    if bookFlag:
        pandocOptions.append('--top-level-division=' + bookFlag)
        pandocOptions = pandocOptions + bookOptions.split()
    else:
        pandocOptions = pandocOptions + articleOptions.split()

    outFile = path.join(filePath, baseFileName + toExtension)
    pandocCommandList = ['/usr/bin/env', 'pandoc', myFile, '-o',
                         outFile] + pandocOptions

    # Run pandoc
    if platform == 'old':
        # If on raspberrypi, sync the bibliographical database.
        writeMessage('Synchronizing bibTeX databases...')
        run(['/home/bennett/coding/sync-bib.py'])
    pandocError = runPandoc(pandocCommandList)
    if pandocError:
        writeError('Error creating ' + toExtension + ' file: ' +
                   str(pandocError))
        exit(1)

    endFile = baseFileName + toExtension
    # Move file from directory of original .md doc to TEMP_PATH
    writeMessage("Moving " + endFile + " to " + path.join(TEMP_PATH,
                 endFile))
    rename(path.join(filePath, endFile), path.join(TEMP_PATH, endFile))

    if (toFormat == 'latex' and toExtension == '.tex'
            and not suppressPdfFlag) or toFormat == 'beamer':
        writeMessage('Successfully created LaTeX file...')
        # Run LaTeX
        latexError = runLatex(TEMP_PATH, baseFileName, latexFormat, bookFlag)
        if latexError:
            writeError('Error running LaTeX.')
            exit(1)
        endFile = baseFileName + '.pdf'
        if path.exists('/Applications/Skim.app'):
            call(['/usr/bin/open', '-a', '/Applications/Skim.app', '-g',
                  path.join(TEMP_PATH, endFile)])
    else:
        if toExtension == '.pdf':
            if path.exists('/Applications/Skim.app'):
                call(['/usr/bin/open', '-a', '/Applications/Skim.app', '-g',
                      path.join(TEMP_PATH, endFile)])
        else:
            if path.exists('/usr/bin/open') and not suppressPdfFlag:
                call(['/usr/bin/open', path.join(TEMP_PATH, endFile)])
    # If on raspberrypi, upload resulting file to dropbox.
    if platform == 'old':
        message = check_output(
            ['/home/bennett/Applications/dropbox-uploader/dropbox_uploader.sh',
             'upload', endFile, endFile]).decode('utf-8')[:-1]
        writeMessage(message)
    if path.exists('/System/Library/Sounds/Morse.aiff') \
            and not suppressPdfFlag:
        call(['/usr/bin/afplay', '/System/Library/Sounds/Morse.aiff'])
