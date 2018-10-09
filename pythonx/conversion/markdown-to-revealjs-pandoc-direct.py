#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from os import path, symlink, chdir, makedirs
from distutils.spawn import find_executable
import pandocConvert

toFormat = 'revealjs'
toExtension = '.html'
# extraOptions = '-V revealjs-url=http://lab.hakim.se/reveal-js'
extraOptions = ''
articleOptions = ''
bookOptions = articleOptions
addedFilter = find_executable('pandoc-citeproc')
imageFormat = '.png'

# Make sure reveal.js is symlinked to tmp/pandoc
revealJSAliasDir = path.expanduser('~/tmp/pandoc/')
revealJSAliasFile = 'reveal.js'
revealJSSource = path.expanduser(
        '~/Applications/pandoc-others/hakimel-reveal.js')
try:
    makedirs(revealJSAliasDir)
except OSError:  # This is for Python 3.x. For 2.7, need OSError
    pass
if not path.exists(path.join(revealJSAliasDir, revealJSAliasFile)):
    chdir(revealJSAliasDir)
    symlink(revealJSSource, revealJSAliasFile)

theFile = argv[1].strip('"')
pandocTempDir = path.expanduser(argv[2])
pdfApp = path.expanduser(argv[3])

pandocConvert.convertMd(pdfApp, pandocTempDir, theFile, toFormat, toExtension,
                        extraOptions, bookOptions, articleOptions,
                        addedFilter, imageFormat)
