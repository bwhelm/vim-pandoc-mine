" ============================================================================
" Helper Functions for Pandoc {{{1
" ============================================================================

function! pandoc#conversion#DisplayMessages(PID, text, ...) abort
    " To write to location list. Note that `...` is there because neovim
    " will include `stdout` and `stderr` as part of its arguments; I can
    " simply ignore those.
    if has('nvim')
        let l:text = a:text
    else
        let l:text = [a:text]
    endif
    echohl WarningMsg
    for l:item in l:text
        laddexpr l:item
        if l:item[0] ==# '!'
            echom 'ERROR: ' . l:item
            call pandoc#conversion#KillProcess(a:PID, 'silent')
        elseif l:item[:15] =~? 'error'
            echom l:item
            let [l:buffer, l:winnum, l:errorFlag] = g:pandocRunPID[a:PID]
            let g:pandocRunPID[a:PID] = [l:buffer, l:winnum, 1]
        endif
    endfor
    echohl None
endfunction

function! pandoc#conversion#DisplayError(PID, text, ...) abort
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

function! s:removePIDFromLists(PID) abort
    if has_key(g:pandocRunPID, a:PID)
        let [l:buffer, l:winnum, l:error] = g:pandocRunPID[a:PID]
        call remove(g:pandocRunPID, a:PID)
        let l:PIDList = g:pandocRunBuf[l:buffer]
        for l:item in range(len(l:PIDList))
            if l:PIDList[l:item] == a:PID
                call remove(l:PIDList, l:item)
                let g:pandocRunBuf[l:buffer] = l:PIDList
                break
            endif
        endfor
        return l:winnum
    endif
endfunction

function! pandoc#conversion#EndProcess(PID, text, ...)
    try
        let [l:buffer, l:winnum, l:errorFlag] = g:pandocRunPID[a:PID]
    catch /E716/  " Key not in Dict -- will happen if user kills process
        return
    endtry
    if l:errorFlag
        echohl WarningMsg
        echom 'Conversion Complete with Errors'
        echohl None
    else
        echohl Comment
        echom 'Conversion Complete'
        echohl None
    endif
    let l:winnum = <SID>removePIDFromLists(a:PID)
    " Retrieve wordcount from location list, and display as message.
    let l:locList = getloclist(l:winnum)
    let l:wordcount = ""
    for l:dict in l:locList
        if l:dict['text'] =~ "^Words:"
            let l:wordcount = dict['text']
            break
        endif
    endfor
    if l:wordcount != ""
        echohl Comment
        echom l:wordcount
        echohl None
    endif
endfunction

function! pandoc#conversion#KillProcess(...) abort
    " Presence of any argument indicates silence.
    if a:0 > 1
        let l:PID = a:1
        let l:silent = 1
    elseif a:0 == 1
        let l:silent = 1
    else
        let l:silent = 0
    endif
    if !exists("l:PID")
        let l:PIDList = keys(g:pandocRunPID)
        if len(l:PIDList) == 0
            echohl Comment
            echom 'No job to kill!'
            echohl None
            return
        endif
        call sort(l:PIDList)
        let l:PID = l:PIDList[0]
    endif
    try
        let [l:buffer, l:winnum, l:error] = g:pandocRunPID[l:PID]
        if has('nvim')
            call jobstop(str2nr(l:PID))
        else
            call job_stop(str2nr(l:PID))
        endif
    catch /E900\|E716/  " This may happen if job has just stopped on its own.
    endtry
    " Print message ... only if there are no arguments.
    if !l:silent
        echohl Comment
        echom 'Job killed.'
        echohl None
    endif
    call <SID>removePIDFromLists(l:PID)
endfunction


" =========================================================================== }}}
" Functions for Conversions {{{1
" ===========================================================================

" Path to plugin's python conversion folder (e.g.,
" `~/.vim/plugged/vim-pandoc-mine/pythonx/conversion/`)
let s:pythonScriptDir = expand('<sfile>:p:h:h:h') . '/pythonx/conversion/'

" Following function calls the conversion script given by a:command only if
" another conversion is not currently running.
function! s:MyConvertHelper(command, ...) abort
    if !exists('g:pandocRunPID')
        " `g:pandocRunPID` is a dictionary used to keep track of all PIDs and
        " errorFlags for each buffer number. Its keys are the PIDs;
        " its values are lists of [buffer number, errorFlag].
        " `g:pandocRunBuf` is a dictionary used to keep track of all buffers
        " and what PIDs there might be for current processes. Its keys are the
        " buffer numbers; its values are [PID1, PID2, ...].
        let g:pandocRunPID = {}
        let g:pandocRunBuf = {}
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
    let l:buffer = bufnr("%")
    " l:pandoc_converting will be > 0 only if a conversion is ongoing.
    if has_key(g:pandocRunBuf, l:buffer)
        let l:pandoc_converting = len(g:pandocRunBuf[l:buffer])
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
                    \ ' "' . l:fileName . '" ' . l:auxCommand,
                    \ {'on_stdout': 'pandoc#conversion#DisplayMessages',
                    \ 'on_stderr': 'pandoc#conversion#DisplayError',
                    \ 'on_exit': 'pandoc#conversion#EndProcess'})
        else
            let l:jobPID = job_start('/usr/bin/env python3 ' .
                    \ s:pythonScriptDir . l:command .
                    \ ' "' . l:fileName . '" ' . l:auxCommand,
                    \ {'out_cb': 'pandoc#conversion#DisplayMessages',
                    \ 'err_cb': 'pandoc#conversion#DisplayError',
                    \ 'close_cb': 'pandoc#conversion#EndProcess'})
        endif
        let g:pandocRunPID[l:jobPID] = [l:buffer, bufwinid("%"), 0]
        if has_key(g:pandocRunBuf, l:buffer)
            let g:pandocRunBuf[l:buffer] += [l:jobPID]
        else
            let g:pandocRunBuf[l:buffer] = [l:jobPID]
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

" Following sets up autogroup to call .pdf conversion script when leaving
" insert mode.
function! pandoc#conversion#ToggleAutoPDF() abort
    if b:pandoc_autoPDFEnabled
        let b:pandoc_autoPDFEnabled = 0
        augroup AutoPDFConvert
            autocmd!
        augroup END
        echohl Comment
        echom 'Auto PDF Off...'
        echohl None
    else
        let b:pandoc_autoPDFEnabled = 1
        augroup AutoPDFConvert
            autocmd!
            autocmd BufWritePost <buffer> :call <SID>MyConvertHelper('')
        augroup END
        echohl Comment
        echom 'Auto PDF On...'
        echohl None
    endif
endfunction

" Following function will temporarily turn off auto conversion, run the
" requested conversion, and then restore auto conversion to its former state.
" It will also check to see if the current buffer has a filename, and if not
" it will create a temporary .md file with the text of the current buffer and
" run the conversion on that file.
function! pandoc#conversion#MyConvertMappingHelper(command, ...) abort
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
