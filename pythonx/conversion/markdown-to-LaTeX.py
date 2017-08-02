#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion. It repeats this with
the version of the file checked in to git, computes a diff between them, and
generates a .pdf of the result.
"""

from sys import argv
from os import chdir, path, remove
import pandocConvert
from subprocess import check_output, call

toFormat = 'latexraw'
toExtension = '.tex'
extraOptions = ''
bookOptions = ''
articleOptions = ''
addedFilter = ''
imageFormat = '.pdf'


# Get old file in git repository to diff with
currentFileName = argv[1].strip('"')
currentFilePath, currentFileShortName = path.split(currentFileName)
chdir(currentFilePath)
if len(argv) > 2:
    gitObject = argv[2]  # To identify the old commit to diff with....
else:
    gitObject = ''  # If empty, uses git cache
gitPrefix = check_output(['git', 'rev-parse',
                          '--show-prefix']).decode('utf-8')[:-2]
oldFileName = path.join(currentFilePath, 'gitdiff.md')
oldFileText = check_output(['git', 'show', gitObject + ':' +
                            path.join(gitPrefix, currentFileShortName)])\
                                .decode('utf-8')

# Create .tex file of file in git cache
pandocConvert.writeMessage('Retrieving from git cache...')
pandocConvert.writeFile(oldFileName, oldFileText)
pandocConvert.convertMd(oldFileName, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)
remove(oldFileName)  # No longer needed after conversion....

# Create .tex file of current working file
pandocConvert.writeMessage('Creating .tex of working file...')
pandocConvert.convertMd(currentFileName, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)

# Create texdiff file
pandocConvert.writeMessage('Creating latexdiff...')
tempDir = path.expanduser('~/tmp/pandoc')
oldFileBaseName, null = path.splitext(path.basename(oldFileName))
currentFileBaseName, null = path.splitext(currentFileShortName)
oldTexName = path.join(tempDir, oldFileBaseName + '.tex')
newTexName = path.join(tempDir, currentFileBaseName + '.tex')
diffContents = check_output(['latexdiff', '--type=FONTSTRIKE',
                             '--subtype=COLOR', oldTexName,
                             newTexName]).decode('utf-8')
pandocConvert.writeFile(newTexName, diffContents)

# Convert to PDF
pandocConvert.writeMessage('Converting to .pdf...')
latexError = pandocConvert.runLatex(tempDir, currentFileBaseName, '-pdf')
if latexError:
    pandocConvert.writeError('Error running LaTeX.')
    exit(1)
endFile = currentFileBaseName + '.pdf'
if path.exists('/Applications/Skim.app'):
    call(['open', '-a', '/Applications/Skim.app', '-g',
          path.join(tempDir, endFile)])
if path.exists('/System/Library/Sounds/Morse.aiff'):
    call(['afplay', '/System/Library/Sounds/Morse.aiff'])
pandocConvert.writeMessage('Conversion complete.')

exit(0)
