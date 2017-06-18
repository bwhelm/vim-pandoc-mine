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

toFormat = 'docx'
toExtension = '.docx'
extraOptions = ''
bookOptions = '--reference-docx=' +\
        path.expanduser('~/.pandoc/default-chapter-styles.docx') + ' '
articleOptions = '--reference-docx=' +\
        path.expanduser('~/.pandoc/default-styles.docx') + ' '
addedFilter = find_executable('pandoc-citeproc')
imageFormat = '.png'

theFile = argv[1].strip('"')

pandocConvert.convertMd(theFile, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)
