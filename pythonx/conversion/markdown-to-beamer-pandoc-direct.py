#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from distutils.spawn import find_executable
from os import path
import pandocConvert

theFile = argv[1].strip('"')
filePath, fileName = path.split(theFile)
baseFileName, fileExtension = path.splitext(fileName)
outputFile = baseFileName + '.tex'

toFormat = 'beamer'
toExtension = '.tex'
# The following will have pandoc create a LaTeX beamer file, which
# pandocConvert will run through LaTeX to produce .pdf slides. This way,
# LaTeX's aux files are saved in ~/tmp/pandoc/, and subsequent runs are much
# faster.
# extraOptions = '--output=' + outputFile
extraOptions = ''
articleOptions = ''
bookOptions = articleOptions
addedFilter = [find_executable('pandoc-citeproc'),
               find_executable('pandocBeamerFilter.lua')]

imageFormat = '.pdf'

pandocConvert.convertMd(theFile, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)
