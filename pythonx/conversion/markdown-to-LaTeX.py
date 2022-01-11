#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion. It repeats this with
the version of the file checked in to git, computes a diff between them, and
generates a .pdf of the result.
"""

from sys import argv
from os import chdir, path, rename
import pandocConvert

toFormat = 'latexraw'
toExtension = '.tex'
extraOptions = ''
bookOptions = ''
articleOptions = ''
addedFilter = ''


# Get old file in git repository to diff with
currentFileName = argv[1].strip('"')
currentFilePath, currentFileShortName = path.split(currentFileName)
chdir(currentFilePath)
pandocTempDir = path.expanduser(argv[2])

# Create .tex file of current working file
pandocConvert.writeMessage('Creating .tex of working file...')
pandocConvert.convertMd(pandocTempDir, currentFileName, toFormat,
                        toExtension, extraOptions, bookOptions,
                        articleOptions, addedFilter)

currentFileBaseName, currentFileExt = path.splitext(currentFileShortName)
texFileShortName = currentFileBaseName + ".tex"
rename(path.join(pandocTempDir, texFileShortName),
       path.join(currentFilePath, texFileShortName))

exit(0)
