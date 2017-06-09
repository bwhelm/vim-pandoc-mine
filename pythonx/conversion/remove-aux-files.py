#!/usr/bin/env python3

from os import path, remove
from sys import argv


# Remove aux files from LaTeX run
def removeAuxFiles(tmpFilePath, baseFileName):
    for extension in ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk', 'fls', 'out',
                      'run.xml', 'dvi', 'idx', 'ind', 'lof', 'synctex.gz',
                      'synctex.gz(busy)', 'toc']:
        try:
            remove(path.join(tmpFilePath, baseFileName + '.' + extension))
            print("Removed: " + path.join(tmpFilePath, baseFileName + '.' +
                  extension))
        except OSError:
            pass


if len(argv) == 1:
    fileName = "temp.md"
else:
    fileName = argv[1]
filePath, baseFileName = path.split(fileName)
baseFileName, ext = path.splitext(baseFileName)
tmpFilePath = path.expanduser("~/tmp/pandoc/")
removeAuxFiles(tmpFilePath, baseFileName)
