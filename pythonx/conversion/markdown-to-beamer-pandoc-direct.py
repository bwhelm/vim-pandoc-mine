#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from distutils.spawn import find_executable
import pandocConvert

toFormat = 'beamer'
toExtension = '.pdf'
extraOptions = ''
articleOptions = ''
bookOptions = articleOptions
addedFilter = find_executable('pandoc-citeproc')
imageFormat = '.pdf'

theFile = argv[1].strip('"')

pandocConvert.convertMd(theFile, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)
