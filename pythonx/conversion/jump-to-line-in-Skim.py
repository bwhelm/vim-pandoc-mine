#!/usr/bin/env python3
#coding: utf-8

'''
This aims to locate the current paragraph in the .pdf file by taking the
current paragraph, converting it into LaTeX, and the searching the
corresponding .tex file for that text. When that text is found, it passes the
relevant line number to Skim.app.

It works pretty well, but currently trips up on paragraphs that contain any
cross-references or in figure captions, etc. I'm not inclined to spend more
time fixing this. However, it might be worth seeing if there is a selection in
the markdown file, and if so searching for that rather than the entire
paragraph.
'''

from os import path
from subprocess import call, Popen, PIPE
from sys import stdout, argv
from re import search, sub, escape
from pipes import quote
import yaml


def toFormat(string, fromThis='markdown-fancy_lists', toThis='latex'):
    # Process string through pandoc to get formatted string. Is there a better
    # way?
    p1 = Popen(['echo'] + string.split(), stdout=PIPE)
    p2 = Popen(['pandoc', '--wrap=none', '--biblatex', '-f', fromThis, '-t',
                toThis, '--smart', '--mathml', '--filter',
                path.expanduser('~/Applications/pandoc/' +
                                'Comment-Filter/pandocCommentFilter.py')] +
               pandocOptions, stdin=p1.stdout, stdout=PIPE)
    p1.stdout.close()
    return p2.communicate()[0].decode('utf-8').strip('\n')


TEMP_PATH = path.expanduser('~/tmp/pandoc/')
PATH_TO_VIEWER = "/Applications/Skim.app"
MAX_YAML_LINES = 50

file = argv[1].strip('"')
lineNumber = int(argv[2]) - 1

with open(file, 'r', encoding='utf-8') as f:
    document = f.read().splitlines()


def findNextLine(lineNumber):
    while document[lineNumber].strip() == '':
        lineNumber += 1
    return document[lineNumber], lineNumber


thisLine, lineNumber = findNextLine(lineNumber)

# Get info from YAML header. Need this to determine whether `draft: true` is
# set, which will effect what output is produced.
if document[0] == '---':
    yheader = ''
    yamlLine = 1
    try:
        while document[yamlLine] not in ['---', '...'] and\
                yamlLine < MAX_YAML_LINES:
            yheader += document[yamlLine] + '\n'
            yamlLine += 1
        if yamlLine == MAX_YAML_LINES:
            yheader = 'yamlHeader: false'
    except IndexError:
        yheader = 'yamlHeader: false'
yamlHeader = yaml.load(yheader.replace('\t', '  '))
pandocOptions = []
try:
    if yamlHeader['draft']:
        pandocOptions.append('--metadata=draft')
except KeyError:
    pass
book = False
try:
    if yamlHeader['book']:
        pandocOptions.append('--chapters')
        book = True
except KeyError:
    pass

# This strips off some initial markdown formatting -- lists, quotations -- that
# we generally don't want. Some lists (like those that start with '*') will be
# included, but I didn't want to strip this off given that it might be
# emphasis. This generally makes searching for the text easier.
thisLine = thisLine.lstrip(' \t:0123456789.-+>')

# We're at a first-level heading. Pandoc treats the last first-level heading
# differently and will return a null-string. Need to work around this (and need
# to do this *after* the previous line.)
if thisLine.startswith('# '):
    # Here we're at a chapter heading, and we need to get the next real line
    # and search on that.
    if book:
        nextParagraph, lineNumber = findNextLine(lineNumber + 1)
        searchText = toFormat(nextParagraph).splitlines()
    else:
        # Find just the text of the heading (without attributes)
        match = thisLine.find('{')
        if match == -1:
            headingText = thisLine[2:]  # No attributes
        else:
            headingText = thisLine[2:match - 1]  # Strip attributes
        searchText = '\\\\section\\{{{}'\
            .format(escape(toFormat(headingText))).splitlines()
else:
    searchText = toFormat(thisLine).splitlines()

# If we're in a list or a long quotation or something similar, the generated
# LaTeX will be multiple lines long. In such cases, we want the second-to-last
# line (just before the "\end{enumerate}" or the "\end{quotation}").
if len(searchText) > 1:
    searchText = searchText[-2]
elif len(searchText) == 1:
    searchText = searchText[0]

# Need to escape text now so that we can add in regular expressions if needed
searchText = escape(searchText)
# Pandoc here returns "``...'' for quotation marks, whereas what I'll likely
# get when the whole document is processed is "\enquote{...}". This fixes that.
searchText = searchText.replace("\\'\\'", '.*').replace("\`\`", '.*')
# Pandoc here will think cross-references are bibliographic citations and so
# will use "\textcite{...}" or "\autocite{...}". When the whole document is
# processed, this will be "\cref{...}" instead. This fixes that. FIXME: Note
# that this does not capture multiple cross-references: [@one; @two] here
# renders as `\autocites{one}{two}`, but in the full document will be
# `\cref{one,two}`.
searchText = sub(r'\\(textcite|autocite)\\{', '\.+{', searchText)
# Pandoc here treats all documents as articles rather than books. This means if
# it's doing a forward search on a book, instead of finding `\section`s, I need
# to find `\chapter`s, etc. This fixes that.
# searchText = sub(r'\\(sub)*section\\{', '\.+{', searchText)

filePath, fileName = path.split(file)
fileBase, fileExtension = path.splitext(fileName)

texFile = path.join(TEMP_PATH, fileBase + '.tex')
pdfFile = path.join(TEMP_PATH, fileBase + '.pdf')

with open(texFile, 'r', encoding='utf-8') as f:
    for num, line in enumerate(f, 1):
        if search(searchText, line):
            break

line_number = str(num)

sync_command = ("'{}/Contents/SharedSupport/displayline' -g "
                .format(PATH_TO_VIEWER) + "{} {} {}"
                .format(line_number, quote(pdfFile), quote(texFile)))

stdout.write(sync_command)

call(sync_command, shell=True)
