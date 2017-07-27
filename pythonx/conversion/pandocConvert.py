#!/usr/bin/env python3

"""
This script is designed to be called by another script in vim, providing the
information below to typeset the file in the given format.
Thus, the script should be called as follows:

    pandocConvert.py file TO_EXTENSION extraOptions bookOptions
         articleOptions filter, imageFormat

Here's what each of these are (read from stdin):
    * MARKDOWN_FILE: complete path to file to be converted
    * TO_EXTENSION: extension of file type to be converted to (e.g., '.html'
      or '.docx')
    * extraOptions: special options for this extension
    * bookOptions: options to send to pandoc if file is a book
    * articleOptions: options to send to pandoc if file is an article
    * addedFilter: a filter to call with the pandoc command
    * imageFormat: the format of any images to be produced
"""

from os import makedirs, chdir, listdir, environ, path, remove
from subprocess import run, check_output, PIPE, call
from sys import stdout, stderr
from re import match, finditer, MULTILINE
from shutil import copyfile
from time import time
from urllib.request import urlretrieve
from tempfile import mkdtemp
from hashlib import sha1


def removeOldFiles(directory, time):
    """
    Remove old files from `directory`, but not `reveal.js` symlink
    """
    modTime = 60 * 60 * 24 * 4  # max number of seconds to keep aux files
    for file in listdir(directory):
        if time - path.getmtime(path.join(directory, file)) > modTime and\
           file != 'reveal.js':
            try:
                remove(path.join(directory, file))
            except OSError:
                pass


"""
Note: latexmk sends messages to stderr by default. I don't want that. So in
autoload/pandoc/conversion.vim, I'm sending stderr to vim messages and
stdout to the quickfix list. That means in defining writeError and
writeMessage, I'm sending errors to stdout and messages to stderr. That's
on purpose.
"""


def writeError(errorMsg):
    """
    Writes errorMsg to stderr
    """
    stdout.write(errorMsg + '\n')
    stdout.flush()
    return


def writeMessage(message):
    """
    Writes message to stdout
    """
    stderr.write(message + '\n')
    stderr.flush()
    return


def readFile(fileName):
    """
    Read text from file on disk.
    """
    with open(fileName, 'r', encoding='utf-8') as f:
        text = f.read()
    return text


def writeFile(fileName, text):
    """
    Write text to file on disk.
    """
    with open(fileName, 'w', encoding='utf-8') as f:
        f.write(text)


def needsUpdating(originalFile, tempFile):
    """
    Returns True if tempFile needs to be updated from original.
    """
    if not path.isfile(tempFile) or\
       path.getmtime(tempFile) < path.getmtime(originalFile):
        return True
    else:
        return False


def generateTeXImage(texFile, imagePath):
    """
    This will generate a .pdf image from a .tex file if needed. Returns the
    (new) fileName.
    """
    name = sha1(texFile.encode('utf-8')).hexdigest()
    imageFile = path.join(imagePath, name + '.pdf')
    if needsUpdating(texFile, imageFile):
        tmpdir = mkdtemp()
        chdir(tmpdir)
        tempTexFile = path.join(tmpdir, name + '.tex')
        newImageFile = path.join(tmpdir, name + '.pdf')
        copyfile(texFile, tempTexFile)
        imageError = run(['pdflatex', tempTexFile], stdout=PIPE)
        if imageError.returncode:
            writeError('Error creating ' + newImageFile + ': ' +
                       imageError.returncode)
            exit(1)
        copyfile(newImageFile, imageFile)
        writeMessage('Created ' + path.basename(texFile)[:-3] + 'pdf')
    return imageFile


def convertImage(imageFile, imageFormat, imagePath):
    """
    Checks to see if image needs to be converted and, if so, converts
    it. Otherwise, touches the existing file. Returns the (new)
    fileName.
    """
    name, extension = path.splitext(imageFile)
    if extension == imageFormat:  # No need to convert
        return imageFile
    else:
        oldImageFile = imageFile
        imageFile = path.join(imagePath, name + imageFormat)
        if needsUpdating(oldImageFile, imageFile):
            imageError = run(['convert', '-density', '300', oldImageFile,
                             '-quality', '100', imageFile], stdout=PIPE)
            if imageError.returncode:
                writeError('Error converting ' + oldImageFile + ' to ' +
                           imageFile + ':' + imageError.returncode)
                exit(1)
            writeMessage('Converted image from ' + extension + ' to ' +
                         imageFormat + '...')
        return imageFile


def copyImage(image, myPath, imagePath, imageFormat):
    """
    Takes an image and a path to .md file that image is embedded in, and
    copies the image from there to imagePath only if necessary. Returns
    the (new) fileName.
    """
    if image.startswith(('http://', 'https://')):
        # It's an online image; need to download to imagePath
        imageFile = path.join(imagePath,
                              path.basename(image).replace(' ', '-'))
        if path.isfile(imageFile):
            imageFile = convertImage(imageFile, imageFormat, imagePath)
        else:
            urlretrieve(image, imageFile)  # otherwise retrieve it
            writeMessage('Retrieved ' + path.basename(image) + ' from web.')
            imageFile = convertImage(imageFile, imageFormat, imagePath)

    else:  # Local image
        if not path.isabs(image):  # If we have a relative path....
            image = path.abspath(path.join(myPath, image))
        # writeMessage("IMAGE: " + path.basename(image))
        # Don't need escaped filenames
        unescapedImage = image.replace('\\\\', '')

        # # For some reason, Texts substitutes '%20' for '\ '; need to correct
        # # for it here, assuming that it won't otherwise be in the fileName
        # unescapedImage = unescapedImage.replace('%20', '\\\\ ')

        # Add new path and change spaces to '-'
        imageFile = path.join(imagePath,
                              path.basename(unescapedImage).replace(' ', '-'))
        name, extension = path.splitext(imageFile)
        if extension == '.tex':  # We have a tikz figure; need to typeset
            imageFile = generateTeXImage(unescapedImage, imagePath)
            extension = '.pdf'
            imageFile = convertImage(imageFile, imageFormat, imagePath)
        else:  # Not a .tex file, so just need to copy to new location.
            if needsUpdating(unescapedImage, imageFile):
                copyfile(unescapedImage, imageFile)
                writeMessage("Copied image: " + path.basename(image))
            imageFile = convertImage(imageFile, imageFormat, imagePath)

    return imageFile


def processImages(text, filePath, imagePath, imageFormat):
    """
    Locate all standard images in the file and processes them: generating
    the image from a .tex file if necessary, and copying the image to
    imagePath, updating the markdown file with new locations.
    """
    found = finditer(r'(!\[.*?\]\()(.*?)(\s+(["\']).*?\4)?\)', text)
    for item in found:
        imageOrig, title = item.group(2, 3)
        if not title:
            title = ''
        if imageOrig:
            image = imageOrig.strip()
            newImage = copyImage(image, filePath, imagePath, imageFormat)
            # Now need doubly escaped search strings...
            imageFound = item.group(0).replace('\\\\', '\\\\\\\\')
            imageReplace = item.group(1) + newImage + title + ')'

            # Replace only the first occurrence, since there may be multiple
            # figures with the same image file.
            text = text.replace(imageFound, imageReplace, 1)
    return text


def processTransclusion(text, myPath, imagePath, imageFormat):
    """
    Recursively searches given text for transcluded files, retrieving their
    contents, processing for images (which need to be relative to the
    transcluded file's path) and for further transcluded files. Substitutes
    these contents into original text and returns it. Normally this will strip
    out YAML headers, but if the attribute given is "!" it will not.
    """
    found = finditer(r'^\s*@\[(.*?)\]\((.+)\)(\{.*?\})?', text, MULTILINE)
    if not found:
        return text
    for item in found:
        caption, theFile, attributes = item.group(1, 2, 3)
        theFile = path.abspath(path.join(myPath, theFile))
        writeMessage("Transcluding " + theFile)
        newText = readFile(theFile).splitlines()
        # Need to strip any YAML header
        if newText[0] == '---' and attributes != "{!}":
            writeMessage("Stripping YAML header...")
            counter = 0
            for line in newText[1:]:
                counter += 1
                if line[:3] in ('...', '---'):
                    break
            if counter < len(newText):
                newText = newText[counter + 1:]
        for index in range(len(newText)):
            """
            If the first non-blank line of transcluded file starts with "~~~",
            try to preserve attributes from transclusion line
            """
            line = newText[index]
            if line[:3] == '~~~':
                oldAttr = match('([^{]*){#(\S*)\s+([^}]*)}', line)
                if oldAttr:
                    initial, tag, oldAttributes = oldAttr.group(1, 2, 3)
                    line = initial + '{#' + tag + ' ' + oldAttributes + \
                        ' ' + attributes[1:-1] + '}'
                else:
                    line = '~~~ {' + attributes[1:-1] + '}'
                newText[index] = line
                break
            elif line != '':
                break
        newText = '\n' + '\n'.join(newText) + '\n'
        newText = processImages(newText, path.dirname(theFile), imagePath,
                                imageFormat)
        newText = processTransclusion(newText, path.dirname(theFile),
                                      imagePath, imageFormat)
        oldText = item.group(0).replace('\\\\', '\\\\\\\\')
        text = text.replace(oldText, newText)
    return text


def runPandoc(pandocCommandList):
    # writeError(str(pandocOptions))
    return run(pandocCommandList, shell=False).returncode


def removeAuxFiles(latexPath, baseFilename):
    # Remove aux files from LaTeX run
    for extension in ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk', 'fls', 'out',
                      'run.xml']:
        try:
            remove(path.join(latexPath, baseFilename + '.' + extension))
        except OSError:
            pass


def runLatex(latexPath, baseFileName, latexFormat):
    # Need to produce .pdf file, which will be opened by runLatex script...
    chdir(latexPath)
    environ['PATH'] = environ['PATH'] + ':/Library/TeX/texbin'

    texCommand = ['latexmk', latexFormat, '-f', '-synctex=1',
                  path.join(latexPath, baseFileName + '.tex')]
    latexError = call(texCommand, stdout=stdout)
    if latexError:
        removeAuxFiles(latexPath, baseFileName)
        writeError('LaTeX Error!: ' + str(latexError))
        return True  # Error
    return False  # No error


def convertMd(myFile, toFormat, toExtension, extraOptions, bookOptions,
              articleOptions, addedFilter, imageFormat):
    writeMessage('Starting conversion to ' + toExtension)

    pandocVersion = check_output(['/usr/bin/env', 'pandoc', '--version']) \
        .decode('utf-8').split('\n')[0].split(' ')[1].split('.')
    if int(pandocVersion[0]) < 2 and int(pandocVersion[1]) < 19:
        platform = 'old'
    else:
        platform = 'new'

    tempPath = path.expanduser('~/tmp/pandoc/')
    imagePath = path.join(tempPath, 'Figures')

    # Make sure temporary path exists for LaTeX compilation
    try:
        makedirs(path.join(tempPath, 'Figures'))
    except OSError:
        pass
    chdir(tempPath)
    now = time()
    removeOldFiles(tempPath, now)
    removeOldFiles(path.join(tempPath, 'Figures'), now)

    filePath, fileName = path.split(myFile)
    baseFileName, fileExtension = path.splitext(fileName)
    if fileExtension != '.md':
        writeError('Need to provide a .md file!')
        exit(1)
    newFilePath = path.join(tempPath, baseFileName + fileExtension)
    mdText = readFile(myFile)

    mdText = processImages(mdText, filePath, imagePath, imageFormat)
    mdText = processTransclusion(mdText, filePath, imagePath, imageFormat)
    # File will be written to new (temp) location later

    # Figure out command to send to pandoc
    suppressPdfFlag = False
    if toFormat == 'latexraw':
        suppressPdfFlag = True
        toFormat = 'latex'
    pandocOptions = ['--standalone',
                     '--from=markdown-fancy_lists',
                     '--mathml',
                     '--smart',
                     '--no-wrap',
                     '--to=' + toFormat]
    pandocOptions += ['--filter',
                      path.expanduser('~/Applications/pandoc/' +
                                      'Comment-Filter/' +
                                      'pandocCommentFilter.py')]
    pandocOptions += ['--filter',
                      path.expanduser('~/Applications/pandoc/' +
                                      'pandoc-reference-filter/' +
                                      'internalreferences.py')]
    pandocOptions += extraOptions.split()

    # addedFilter might be a String, a List, or None. This will add all to
    # pandocOptions.
    if addedFilter:
        if isinstance(addedFilter, str):
            addedFilter = [addedFilter]
        for myFilter in addedFilter:
            pandocOptions = pandocOptions + ['--filter', myFilter]

    # Check to see if we need to use chapters or sections for 1st-level heading
    bookFlag = False

    # If toExtension = '.tex', this determines how latexmk creates a pdf file
    # (whether using pdflatex, lualatex, or xelatex). Default is pdflatex.
    latexFormat = '-pdf'

    # Process YAML header into pandocOptions
    intextCSL = '--csl=' + path.expanduser(
            '~/.pandoc/chicago-manual-of-style-16th-edition-full-in-text.csl')
    notesCSL = '--csl=' + path.expanduser(
            '~/.pandoc/chicago-fullnote-bibliography.csl')

    mdTextSplit = mdText.splitlines()
    for lineIndex in range(len(mdTextSplit)):
        line = mdTextSplit[lineIndex].lower()
        if lineIndex == 0 and line != "---":
            break
        elif line.startswith('book: ') and line[6:] != 'false':
            # bookFlag can be "true", "section", "chapter", or "part"
            bookFlag = line[6:]
            if bookFlag == "true":  # Default to "chapter"
                bookFlag = "chapter"
        elif line.startswith('biblatex: true') and toExtension == '.tex':
            pandocOptions.append('--biblatex')
        elif line.startswith('bibinline: true') and toExtension != '.tex':
            pandocOptions.append(intextCSL)
        elif line.startswith('biboptions: notes') and toExtension != '.tex':
            pandocOptions.append(notesCSL)
        elif line.startswith('csl:') and toExtension != '.tex':
            mdTextSplit[lineIndex] = 'csl: ' + path.expanduser(line[5:])
        elif line.startswith('htmltoc: true') and toExtension == '.html':
            pandocOptions.append('--toc')
        elif line.startswith('lualatex: true'):
            latexFormat = '-lualatex'
        elif line.startswith('xelatex: true'):
            latexFormat = '-xelatex'
        elif line.startswith('geometry: ipad'):  # Special case for ipad geom
            mdTextSplit[lineIndex] = 'geometry: paperwidth=176mm,' +\
                'paperheight=234mm,'
            if bookFlag:  # Specify for OUPRoyal.cls
                mdTextSplit[lineIndex] += 'outer=22mm,' +\
                    'top=2.5pc,' +\
                    'bottom=3pc,' +\
                    'headsep=1pc,' +\
                    'includehead,' +\
                    'includefoot,' +\
                    'centering,' +\
                    'inner=22mm,' +\
                    'marginparwidth=17mm'
            else:  # Make dimension same as default article class, letterpaper
                mdTextSplit[lineIndex] += 'width=360.0pt,' +\
                    'height=541.40024pt,' +\
                    'headsep=1pc,' +\
                    'centering'
        elif line.startswith('bibliography:'):
            # Check kpsewhich to retrieve full path to bib databases.
            if line[13:].strip():
                mdTextSplit[lineIndex] = \
                    'bibliography: ' + \
                    check_output(['kpsewhich',
                                  line[13:].strip().strip('"').strip("'")])\
                    .decode('utf-8')
            else:
                for i in range(lineIndex + 1, len(mdTextSplit)):
                    if mdTextSplit[i].startswith('- '):
                        mdTextSplit[i] = '- ' + \
                                check_output(['kpsewhich',
                                              mdTextSplit[i][2:].strip('"')
                                              .strip("'")])[:-1]\
                                .decode('utf-8')
                    else:
                        break
        elif line[:3] in ('...', '---') and lineIndex != 0:
            break

    # Write modified mdText to new (temp) location
    mdText = "\n".join(mdTextSplit)
    writeFile(newFilePath, mdText)

    # Need to clean up .csl: I only want 1 csl, and it should be full-in-text
    # first.
    if intextCSL in pandocOptions and notesCSL in pandocOptions:
        pandocOptions.remove(notesCSL)

    if bookFlag:
        pandocOptions.append('--top-level-division=' + bookFlag)
        pandocOptions = pandocOptions + bookOptions.split()
    else:
        pandocOptions = pandocOptions + articleOptions.split()

    pandocCommandList = ['/usr/bin/env', 'pandoc', newFilePath, '-o',
                         path.join(tempPath, baseFileName + toExtension)] +\
        pandocOptions

    # Run pandoc
    if platform == 'old':
        # If on raspberrypi, sync the bibliographical database.
        writeMessage('Synchronizing bibTeX databases...')
        run(['/home/bennett/coding/sync-bib.py'])
    pandocError = runPandoc(pandocCommandList)
    if pandocError:
        writeError('Error creating ' + toExtension + ' file: ' +
                   str(pandocError))
        exit(1)

    endFile = baseFileName + toExtension
    if toFormat == 'latex' and toExtension == '.tex' and not suppressPdfFlag:
        writeMessage('Successfully created LaTeX file...')
        # Run LaTeX
        latexError = runLatex(tempPath, baseFileName, latexFormat)
        if latexError:
            writeError('Error running LaTeX.')
            exit(1)
        endFile = baseFileName + '.pdf'
        if path.exists('/Applications/Skim.app'):
            call(['open', '-a', '/Applications/Skim.app', '-g',
                  path.join(tempPath, endFile)])
    elif toExtension == '.pdf':
        if path.exists('/Applications/Skim.app'):
            call(['open', '-a', '/Applications/Skim.app', '-g',
                  path.join(tempPath, endFile)])
    else:
        if path.exists('/usr/bin/open') and not suppressPdfFlag:
            call(['open', path.join(tempPath, endFile)])
    # If on raspberrypi, upload resulting file to dropbox.
    if platform == 'old':
        message = check_output(
            ['/home/bennett/Applications/dropbox-uploader/dropbox_uploader.sh',
             'upload', endFile, endFile]).decode('utf-8')[:-1]
        writeMessage(message)
    if path.exists('/System/Library/Sounds/Morse.aiff') \
            and not suppressPdfFlag:
        call(['afplay', '/System/Library/Sounds/Morse.aiff'])
