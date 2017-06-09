#!/usr/bin/env python3

'''
This script is designed to run LaTeX on the provided file within TextMate.
It should be called with:
    runLatex.py /path/to/filename.tex latexFormat &
The point of the script is that it can be called from another script, which
then returns control back to TextMate while the LaTeX typesetting proceeds
in this script. `latexFormat` determines how output is generated, whether
by pdf (= pdflatex), lualatex, or xelatex.
'''

from os import environ, system, path, remove, makedirs, chdir
from sys import argv

ERROR_FILE = path.expanduser('~/tmp/pandoc/error.log')


def writeError(errorMsg):
    with open(ERROR_FILE, 'a') as errorFile:
        errorFile.write(errorMsg)
    system('/usr/bin/open -a MacVim.app ' + ERROR_FILE)
    return


# Remove aux files from LaTeX run
def removeAuxFiles(baseFilename):
    for extension in ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk', 'fls', 'out',
                      'run.xml', 'dvi', 'idx', 'ind', 'lof',
                      'synctex.gz(busy)', 'toc']:
        try:
            remove(path.join(LATEX_PATH, baseFilename + '.' + extension))
        except OSError:
            pass


null, temp, latexFormat = argv

LATEX_PATH, FILENAME = path.split(temp)
FILENAME, FILE_EXTENSION = path.splitext(FILENAME)
if FILE_EXTENSION != '.tex':
    writeError('Need to provide a .tex file!')
    exit(1)

try:
    makedirs(LATEX_PATH)
except OSError:
    pass
chdir(LATEX_PATH)

environ['PATH'] = environ['PATH'] + ':/Library/TeX/texbin'

texCommand = 'latexmk {} -synctex=1 "{}" &>/dev/null'.format(
        latexFormat,
        path.join(LATEX_PATH, FILENAME + FILE_EXTENSION))
latexError = system(texCommand)
if latexError:
    system('/usr/bin/open -a MacVim.app "{}"'.format(path.join(LATEX_PATH,
                                                     FILENAME + '.log')))
    # removeAuxFiles(FILENAME)
    writeError('LaTeX Error!')
else:
    system('open -a /Applications/Skim.app -g "{}" &>/dev/null'.format(
                                path.join(LATEX_PATH, FILENAME + '.pdf')))
    system('afplay /System/Library/Sounds/Morse.aiff')
