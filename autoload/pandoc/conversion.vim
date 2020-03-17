scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================
" Helper Functions for Pandoc {{{1
" ============================================================================

function! pandoc#conversion#MarkdownGitDiff() abort  "{{{2
    let gitLog = split(system('git log -n10 --no-color --format=reference -- ' .
                \ fnameescape(expand('%', ':p'))), '\n')
    if len(gitLog) == 0
        echo 'This file is not found in any commits. Aborting.'
        return
    endif
    let gitLogList = ['Select git commit (1 to ' . string(len(gitLog) + 1) .
                \ ' or enter anything else for HEAD)', '1. HEAD']
    for i in range(len(gitLog))
        call add(gitLogList, string(i + 2) . '. ' . gitLog[i])
    endfor
    let answer = inputlist(gitLogList)
    if answer == 1
        let answer = 'HEAD'
    elseif answer > 1 && answer <= len(gitLog) + 1
        let answer = split(gitLog[answer - 2])[0]
    else
        echohl Comment
        redraw | echo "Invalid response; aborting ..."
        echohl None
        return
    endif
    call pandoc#conversion#MyConvertMappingHelper('markdown-to-LaTeX.py', answer)
endfunction
"2}}}
function! pandoc#conversion#DisplayMessages(PID, text, ...) abort  "{{{2
    " To write to location list. Note that `...` is there because neovim
    " will include `stdout` and `stderr` as part of its arguments; I can
    " simply ignore those.
    if has('nvim')
        let l:text = a:text
    else
        let l:text = [a:text]
    endif
    let [l:buffer, l:winnum, l:errorFlag, l:texOutput] = s:pandocRunPID[a:PID]
    echohl WarningMsg
    for l:item in l:text
        if l:item !=# ''
            call add(l:texOutput, {'text': l:item})
        endif
        if l:item[0] ==# '!'
            echom 'ERROR:' l:item
            let s:pandocRunPID[a:PID] = [l:buffer, l:winnum, 1, l:texOutput]
            call pandoc#conversion#KillProcess(a:PID, 'silent')
            echohl None
            return
        elseif l:item[:15] =~? 'error'
            echom l:item
            let l:errorFlag = 1
        endif
    endfor
    let s:pandocRunPID[a:PID] = [l:buffer, l:winnum, l:errorFlag, l:texOutput]
    echohl None
endfunction
"2}}}
function! pandoc#conversion#DisplayError(PID, text, ...) abort  "{{{2
    " To write to messages
    " let l:winWidth = winwidth(0)
    echohl Comment
    if type(a:text) != 3  " If it's not a list, make it one!
        let l:text = [a:text]
    else
        let l:text = a:text
    endif
    call filter(l:text, 'v:val !=# ""')
    for l:line in l:text
        if l:line !~? '^----\|^Running\|^Latexmk\|^  Citation\|^  Reference'
            echom l:line
            " echom l:line[: l:winWidth - 1]
        endif
    endfor
    echohl None
endfunction
"2}}}
function! s:removePIDFromLists(PID) abort  "{{{2
    if has_key(s:pandocRunPID, a:PID)
        let [l:buffer, l:winnum, l:error, l:texOutput] = s:pandocRunPID[a:PID]
        call remove(s:pandocRunPID, a:PID)
        let l:PIDList = s:pandocRunBuf[l:buffer]
        for l:item in range(len(l:PIDList))
            if l:PIDList[l:item] == a:PID
                call remove(l:PIDList, l:item)
                let s:pandocRunBuf[l:buffer] = l:PIDList
                break
            endif
        endfor
        return l:winnum
    endif
endfunction
"2}}}
function! pandoc#conversion#EndProcess(PID, ...) abort  "{{{2
    try
        let [l:buffer, l:winnum, l:errorFlag, l:texOutput] = s:pandocRunPID[a:PID]
    catch /E716/  " Key not in Dict -- will happen if user kills process
        return
    endtry
    if l:errorFlag
        echohl WarningMsg
        echom 'Conversion Complete with Errors'
        echohl None
    else
        echohl Comment
        redraw | echo 'Conversion Complete'
        echohl None
    endif
    let l:winnum = <SID>removePIDFromLists(a:PID)
    " Retrieve wordcount from location list, and display as message.
    call setloclist(l:winnum, l:texOutput, 'r')
    let l:wordcount = l:texOutput[0]['text']
    if l:wordcount =~# '^Words:'
        echohl Comment
        redraw | echo l:wordcount
        echohl None
    endif
endfunction
"2}}}
function! pandoc#conversion#KillProcess(...) abort  "{{{2
    " Presence of any argument indicates silence.
    if a:0 > 1
        let l:PID = a:1
        let l:silent = 1
    elseif a:0 == 1
        let l:silent = 1
    else
        let l:silent = 0
    endif
    if !exists('l:PID')
        let l:PIDList = keys(s:pandocRunPID)
        if len(l:PIDList) == 0
            echohl Comment
            redraw | echo 'No job to kill!'
            echohl None
            return
        endif
        call sort(l:PIDList)
        let l:PID = l:PIDList[0]
    endif
    try
        let [l:buffer, l:winnum, l:error, l:texOutput] = s:pandocRunPID[l:PID]
        if has('nvim')
            call jobstop(str2nr(l:PID))
        else  " for vim
            call job_stop(l:PID)
        endif
    catch /E900\|E716/  " This may happen if job has just stopped on its own.
    endtry
    " Print message ... only if there are no arguments.
    if !l:silent
        echohl Comment
        redraw | echo 'Job killed.'
        echohl None
    endif
    call <SID>removePIDFromLists(l:PID)
endfunction
"2}}}

" =========================================================================== }}}
" Functions for Conversions {{{1
" ===========================================================================

" Path to plugin's python conversion folder (e.g.,
" `~/.vim/plugged/vim-pandoc-mine/pythonx/conversion/`)
let s:pythonScriptDir = expand('<sfile>:p:h:h:h') . '/pythonx/conversion/'

function! s:MyConvertHelper(command, ...) abort  "{{{2
    " Following function calls the conversion script given by a:command only if
    " another conversion is not currently running.
    if !exists('s:pandocRunPID')
        " `s:pandocRunPID` is a dictionary used to keep track of all PIDs and
        " errorFlags for each buffer number. Its keys are the PIDs;
        " its values are lists of [buffer number, errorFlag, texOutput].
        let s:pandocRunPID = {}
        " `s:pandocRunBuf` is a dictionary used to keep track of all buffers
        " and what PIDs there might be for current processes. Its keys are the
        " buffer numbers; its values are [PID1, PID2, ...].
        let s:pandocRunBuf = {}
    endif
    if !exists('s:pandocTempDir')
        let s:pandocTempDir = '~/tmp/pandoc'
    endif
    if !exists('s:pandocPdfApp')
        let s:pandocPdfApp = '/Applications/Skim.app'
    endif
    let l:auxCommand = a:0 == 0 ? '' : a:1
    if empty(a:command)
        let l:command = b:pandoc_lastConversionMethod
    else
        let b:pandoc_lastConversionMethod = a:command
        let l:command = a:command
    endif
    messages clear
    let l:errorFlag = 0
    let l:fileName = expand('%:p')
    if empty(l:fileName)
        let l:textList = getline(0, '$')
        let l:fileName = fnamemodify(tempname(), ':h') . '/temp.md'
        call writefile(l:textList, l:fileName)
    else
        update
    endif
    let l:buffer = bufnr('%')
    " l:pandoc_converting will be > 0 only if a conversion is ongoing.
    if has_key(s:pandocRunBuf, l:buffer)
        if has('nvim')
            let l:pandoc_converting = len(s:pandocRunBuf[l:buffer])
        elseif s:pandocRunBuf[l:buffer][0] =~# 'dead'
            " If using vim, the job ID will change from 'run' to 'dead' when
            " the job ends. Catch this, and remove it from lists.
            let l:pandoc_converting = 0
            let l:PID = matchstr(s:pandocRunBuf[l:buffer][0], '\d\+')
            unlet s:pandocRunBuf[l:buffer][0]
            unlet s:pandocRunPID['process ' . l:PID . ' run']
        else
            let l:pandoc_converting = 1
        endif
    else
        let l:pandoc_converting = 0
    endif
    " Don't change existing .tex file if currently in use
    if l:pandoc_converting && (l:command ==# 'markdown-to-PDF-LaTeX.py' ||
                    \ l:command ==# 'convert-to-markdown.py')
        call pandoc#conversion#DisplayError(0, 'Already converting...')
    else
        call setloclist(0, [])
        if has('nvim')
            let l:jobPID = jobstart('/usr/bin/env python3 ' .
                    \ s:pythonScriptDir . l:command .
                    \ ' "' . l:fileName . '" ' . s:pandocTempDir . ' ' .
                    \ s:pandocPdfApp . ' ' . l:auxCommand,
                    \ {'on_stdout': 'pandoc#conversion#DisplayMessages',
                    \ 'on_stderr': 'pandoc#conversion#DisplayError',
                    \ 'on_exit': 'pandoc#conversion#EndProcess'})
        else
            let l:jobPID = job_start('/usr/bin/env python3 ' .
                    \ s:pythonScriptDir . l:command .
                    \ ' "' . l:fileName . '" ' . s:pandocTempDir . ' ' .
                    \ s:pandocPdfApp . ' ' . l:auxCommand,
                    \ {'out_cb': 'pandoc#conversion#DisplayMessages',
                    \ 'err_cb': 'pandoc#conversion#DisplayError',
                    \ 'close_cb': 'pandoc#conversion#EndProcess'})
        endif
        let s:pandocRunPID[l:jobPID] = [l:buffer, bufwinid('%'), 0, []]
        if has_key(s:pandocRunBuf, l:buffer)
            let s:pandocRunBuf[l:buffer] += [l:jobPID]
        else
            let s:pandocRunBuf[l:buffer] = [l:jobPID]
        endif
        " Write servername to file if nvim; delete it if not. This will be
        " used in pdf-md-backward-search.py to identify relevant vim server to
        " open document in.
        let l:serverFile = expand('~/tmp/pandoc/') .
                    \ fnamemodify(l:fileName, ':t:r') . '.nvimserver'
        if has('nvim')
            let l:serverName = serverlist()[0]
            call writefile([l:serverName], l:serverFile)
        else
            call delete(l:serverFile)
        endif
    endif
endfunction
"2}}}
function! pandoc#conversion#ToggleAutoPDF() abort  "{{{2
    " Following sets up autogroup to call .pdf conversion script when leaving
    " insert mode.
    if b:pandoc_autoPDFEnabled
        let b:pandoc_autoPDFEnabled = 0
        augroup AutoPDFConvert
            autocmd!
        augroup END
        echohl Comment
        redraw | echo 'Auto PDF Off...'
        echohl None
    else
        let b:pandoc_autoPDFEnabled = 1
        augroup AutoPDFConvert
            autocmd!
            autocmd BufWritePost <buffer> :call <SID>MyConvertHelper('')
        augroup END
        echohl Comment
        redraw | echo 'Auto PDF On...'
        echohl None
    endif
endfunction
"2}}}
function! pandoc#conversion#MyConvertMappingHelper(command, ...) abort  "{{{2
    " Following function will temporarily turn off auto conversion, run the
    " requested conversion, and then restore auto conversion to its former state.
    " It will also check to see if the current buffer has a filename, and if not
    " it will create a temporary .md file with the text of the current buffer and
    " run the conversion on that file.
    let l:auxCommand = a:0 == 0 ? '' : a:1
    if !exists('b:pandoc_autoPDFEnabled')
        let b:pandoc_autoPDFEnabled = 0
    endif
    if b:pandoc_autoPDFEnabled
        call pandoc#conversion#ToggleAutoPDF()
        call <SID>MyConvertHelper(a:command, l:auxCommand)
        call pandoc#conversion#ToggleAutoPDF()
    else
        call <SID>MyConvertHelper(a:command, l:auxCommand)
    endif
endfunction
"2}}}
"1}}}
