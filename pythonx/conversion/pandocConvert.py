#!/usr/bin/env python3

"""
This script is designed to be called by another script in vim, providing the
information below to typeset the file in the given format.
Thus, the script should be called as follows:

    pandocConvert.py file TO_EXTENSION extraOptions bookOptions
         articleOptions filter, imageFormat

Here's what each of these are (read from stdin):
    * file: complete path to file to be converted
    * TO_EXTENSION: extension of file type to be converted to (e.g., '.html'
      or '.docx')
    * extraOptions: special options for this extension
    * bookOptions: options to send to pandoc if file is a book
    * articleOptions: options to send to pandoc if file is an article
    * addedFilter: a filter to call with the pandoc command
    * imageFormat: the format of any images to be produced
"""

from os import chdir, makedirs, listdir, environ, path, remove, rename
from ruamel.yaml import YAML
from ruamel.yaml.composer import ComposerError
from subprocess import run, check_output, call
from sys import stdout, stderr
from time import time


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
    # writeError(str(pandocCommandList))
    return run(pandocCommandList, shell=False).returncode


def removeAuxFiles(latexPath, baseFilename):
    # Remove aux files from LaTeX run
    for extension in ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk', 'fls', 'out',
                      'run.xml']:
        try:
            remove(path.join(latexPath, baseFilename + '.' + extension))
        except OSError:
            pass


def preprocessFile(baseFileName, fileExtension, text, yamlData):
    """
    Macros:

    Here I abuse math environments to create easy macros.

    1. In YAML header, specify macros as follows:

        macros:
        - first: this is the substituted text
          second: this is more substituted text

    2. Then in text, have users specify macros to be substituted as follows:

        This is my text and $first$. This is more text and $second$.

    As long as the macro labels are not identical to any actual math the user
    would use, there should be no problem.
    """
    try:
        macros = yamlData['macros'][0]
        for key in macros:
            text = text.replace('$' + str(key) + '$', str(macros[key]))
    except KeyError:
        pass  # No macros in file
    return text


def runLatex(latexPath, baseFileName, latexFormat, bookFlag):
    # Need to produce .pdf file, which will be opened by runLatex script...
    # chdir(latexPath)
    environ['PATH'] = '/Library/TeX/texbin:' + environ['PATH']
    # Note that `makeidx` is unhappy with my setting pandocTempDir outside the
    # document directory out of security concerns. According to documentation
    # for latexmk, 'One way of [getting around] this is to temporarily set an
    # operating system environment variable openout_any to "a" (as in "all"),
    # to override the default "paranoid" setting.' I'll turn it on only if a
    # book is being typeset.
    if bookFlag:
        environ['openout_any'] = 'a'
    latexFile = path.join(latexPath, baseFileName + '.tex')

    texCommand = ['latexmk', latexFormat, '-f', '-synctex=1',
                  '-auxdir=' + latexPath, '-outdir=' + latexPath,
                  latexFile]
    latexError = call(texCommand, stdout=stdout)
    if latexError:
        removeAuxFiles(latexPath, baseFileName)
        writeError('LaTeX Error!: ' + str(latexError))
        return True  # Error
    return False     # No error


def convertMd(pdfApp, pandocTempDir, myFile, toFormat, toExtension,
              extraOptions, bookOptions, articleOptions, addedFilter,
              imageFormat):
    writeMessage('Starting conversion to ' + toExtension)

    pandocTempDirImages = path.join(pandocTempDir, 'Figures')

    # Make sure temporary path exists for LaTeX compilation
    try:
        makedirs(pandocTempDirImages)
    except OSError:
        pass

    pandocVersion = check_output(['/usr/bin/env', 'pandoc', '--version']) \
        .decode('utf-8').split('\n')[0].split(' ')[1].split('.')
    if int(pandocVersion[0]) < 2 and int(pandocVersion[1]) < 19:
        platform = 'old'
    else:
        platform = 'new'

    # Remove old files in pandocTempDir folder...
    now = time()
    removeOldFiles(pandocTempDir, now)
    removeOldFiles(pandocTempDirImages, now)

    filePath, fileName = path.split(myFile)
    chdir(filePath)  # This is needed to be able to pick up relative paths
    baseFileName, fileExtension = path.splitext(fileName)
    mdText = readFile(myFile)

    # Figure out command to send to pandoc
    suppressPdfFlag = False
    if toFormat == 'latexraw':
        suppressPdfFlag = True
        toFormat = 'latex'

    pandocOptions = ['--standalone',
                     '--from=markdown-fancy_lists+smart',
                     '--mathml',
                     '--wrap=none',
                     # '--log=/Users/bennett/tmp/pandoc/log',
                     '--to=' + toFormat]
    pandocOptions += ['--lua-filter', 'fixYAML.lua']
    pandocOptions += ['--lua-filter', 'pandocCommentFilter.lua']
    pandocOptions += ['--lua-filter', 'internalreferences.lua']
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

    # Get YAML data
    mdTextSplit = mdText.splitlines()
    bookFlag = False
    yamlText = []
    yamlData = {}
    latexFormat = '-pdf'
    if mdTextSplit[0] == '---':  # Need to process YAML header
        for line in mdTextSplit[1:]:
            if line == "---":
                break
            yamlText.append(line)
        yaml = YAML(typ='safe')
        try:
            yamlData = yaml.load('\n'.join(yamlText))
        except ComposerError:
            writeError("ERROR: Cannot parse YAML header. If any of '%@*' " +
                       "are in yaml header, it needs to be enclosed " +
                       "in quotes.")
            exit(1)
        # Check to see if we need to use chapters or sections for 1st-level
        # heading
        if 'book' in yamlData:
            bookFlag = yamlData['book']
            if bookFlag is True:
                bookFlag = 'chapter'
        # Set how latexmk creates pdf file (whether using pdflatex, lualatex,
        # or xelatex). Default is pdflatex.
        if 'lualatex' in yamlData and yamlData['lualatex']:
            latexFormat = '-lualatex'
        elif 'xelatex' in yamlData and yamlData['xelatex']:
            latexFormat = '-xelatex'
        if toExtension == '.tex' and 'biblatex' in yamlData and \
                yamlData['biblatex']:
            pandocOptions.append('--biblatex')
        if toExtension == '.html' and 'htmltoc' in yamlData and \
                yamlData['htmltoc']:
            pandocOptions.append('--toc')

    # Preprocess markdown text, replacing macros
    mdText = preprocessFile(baseFileName, fileExtension, mdText,
                            yamlData)
    myFile = path.join(filePath, baseFileName + '-processed' + fileExtension)
    writeFile(myFile, mdText)

    if toFormat == 'latex' and toExtension == '.pdf':
        # Set `--pdf-engine` for pandoc conversion direct to .pdf
        latexEngine = {'-pdf': 'pdflatex',
                       '-lualatex': 'lualatex',
                       '-xelatex': 'xelatex'}
        pandocOptions.append('--pdf-engine=' + latexEngine[latexFormat])

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
    # Move file from directory of original .md doc to pandocTempDir
    writeMessage("Moving " + endFile + " to " + path.join(pandocTempDir,
                 endFile))
    rename(path.join(filePath, endFile), path.join(pandocTempDir, endFile))
    # Delete processed file
    remove(myFile)

    if (toFormat == 'latex' and toExtension == '.tex'
            and not suppressPdfFlag) or toFormat == 'beamer':
        writeMessage('Successfully created LaTeX file...')
        # Run LaTeX
        latexError = runLatex(pandocTempDir, baseFileName, latexFormat,
                              bookFlag)
        if latexError:
            writeError('Error running LaTeX.')
            exit(1)
        endFile = baseFileName + '.pdf'
        if path.exists('/Applications/Skim.app'):
            call(['/usr/bin/open', '-a', '/Applications/Skim.app', '-g',
                  path.join(pandocTempDir, endFile)])
    else:
        if toExtension == '.pdf':
            if path.exists('/Applications/Skim.app'):
                call(['/usr/bin/open', '-a', '/Applications/Skim.app', '-g',
                      path.join(pandocTempDir, endFile)])
        else:
            if path.exists('/usr/bin/open') and not suppressPdfFlag:
                call(['/usr/bin/open', path.join(pandocTempDir, endFile)])
    # If on raspberrypi, upload resulting file to dropbox.
    if platform == 'old':
        message = check_output(
            ['/home/bennett/Applications/dropbox-uploader/dropbox_uploader.sh',
             'upload', path.join(pandocTempDir, endFile),
             endFile]).decode('utf-8')[:-1]
        writeMessage(message)
    if path.exists('/System/Library/Sounds/Morse.aiff') \
            and not suppressPdfFlag:
        call(['/usr/bin/afplay', '/System/Library/Sounds/Morse.aiff'])
