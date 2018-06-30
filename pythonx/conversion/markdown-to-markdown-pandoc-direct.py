#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from os import path
from distutils.spawn import find_executable
import pandocConvert

toFormat = 'markdown'
toExtension = '.md'
extraOptions = '--preserve-tabs  --wrap=none --atx-headers '
bookOptions = ''
articleOptions = ''
addedFilter = find_executable('pandoc-citeproc')
imageFormat = ''

theFile = argv[1].strip('"')
pandocTempDir = path.expanduser(argv[2])
pdfApp = path.expanduser(argv[3])

pandocConvert.convertMd(pdfApp, pandocTempDir, theFile, toFormat, toExtension,
                        extraOptions, bookOptions, articleOptions,
                        addedFilter, imageFormat)
