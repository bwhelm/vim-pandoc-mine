#!/usr/bin/env python3

"""
This script is designed to be run from within vim. It retrieves the filename
(and complete path) of the current vim document, sets some options, and calls
the pandocConvert.py script to complete the conversion.
"""

from sys import argv
from distutils.spawn import find_executable
from os import path
from subprocess import run
import pandocConvert

theFile = argv[1].strip('"')
filePath, fileName = path.split(theFile)
baseFileName, fileExtension = path.splitext(fileName)
outputFile = baseFileName + '.tex'

pandocTempDir = path.expanduser(argv[2])
pdfApp = path.expanduser(argv[3])

# Adjust for pandoc-citeproc's different versions on pandoc > 2.10.x
pandocVersion = run(['pandoc', '--version'], encoding='utf8',
                    capture_output=True)
pandocVersionNumber = pandocVersion.stdout.split('\n')[0][7:]
pandocVersionList = pandocVersionNumber.split('.')
if int(pandocVersionList[0]) > 2 or (int(pandocVersionList[0]) == 2 and
                                     int(pandocVersionList[1]) > 10):
    extraOptions = '--citeproc'
    addedFilter = []
else:
    extraOptions = ''
    addedFilter = [find_executable('pandoc-citeproc')]

toFormat = 'beamer'
toExtension = '.tex'
# The following will have pandoc create a LaTeX beamer file, which
# pandocConvert will run through LaTeX to produce .pdf slides. This way,
# LaTeX's aux files are saved in ~/tmp/pandoc/, and subsequent runs are much
# faster.
# extraOptions = '--output=' + outputFile
articleOptions = ''
bookOptions = articleOptions
addedFilter.append(find_executable('pandocBeamerFilter.lua'))

imageFormat = '.pdf'

pandocConvert.convertMd(pdfApp, pandocTempDir, theFile, toFormat, toExtension,
                        extraOptions, bookOptions, articleOptions,
                        addedFilter, imageFormat)
