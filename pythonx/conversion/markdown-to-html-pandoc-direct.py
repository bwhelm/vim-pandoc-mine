#!/opt/local/bin/python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from os import path
import pandocConvert

toFormat = 'html5'
toExtension = '.html'
# extraOptions = '--latexmathml'
extraOptions = '--mathjax'
bookOptions = '--toc --smart --css=' +\
        path.expanduser('~/Applications/pandoc/buttondown.css')
articleOptions = '--smart --css=' +\
        path.expanduser('~/Applications/pandoc/buttondown.css')
addedFilter = '/usr/local/bin/pandoc-citeproc'
imageFormat = '.png'

theFile = argv[1].strip('"')

pandocConvert.convertMd(theFile, toFormat, toExtension, extraOptions,
                        bookOptions, articleOptions, addedFilter, imageFormat)
