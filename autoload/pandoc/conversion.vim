" ============================================================================
" Helper Functions for Pandoc {{{1
" ============================================================================

function! pandoc#conversion#DisplayMessages(channel, text, ...)
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
            call pandoc#conversion#KillProcess('silent')
        elseif l:item[:15] =~? 'error'
            echom l:item
            let b:errorFlag = 1
        endif
    endfor
    echohl None
endfunction

function! pandoc#conversion#DisplayError(channel, text, ...) abort
    " To write to messages
    let l:winWidth = winwidth(0)
    echohl Comment
    if has('nvim')
        let l:text = a:text
    else
        let l:text = [a:text]
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

function! pandoc#conversion#EndProcess(...)
    if b:pandoc_converting  " If job hasn't already been killed
        if b:errorFlag
            echohl WarningMsg
            echom 'Conversion Complete with Errors'
            echohl None
        else
            echohl Comment
            echom 'Conversion Complete'
            echohl None
        endif
        let b:pandoc_converting=0
    endif
endfunction

function! pandoc#conversion#KillProcess(...) abort
    " Presence of any argument indicates silence.
    if b:pandoc_converting
        if has('nvim')
            call jobstop(b:conversionJob)
        else
            call job_stop(b:conversionJob)
        endif
        " Print message ... only if there are no arguments.
        if !a:0
            echohl Comment
            echom 'Job killed.'
            echohl None
        endif
        let b:pandoc_converting=0
    else
        echohl Comment
        echom 'No job to kill!'
        echohl None
    endif
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
    let l:auxCommand = a:0 == 0 ? '' : a:1
    if empty(a:command)
        let l:command = b:pandoc_lastConversionMethod
    else
        let b:pandoc_lastConversionMethod = a:command
        let l:command = a:command
    endif
    messages clear
    let b:errorFlag = 0
    let l:fileName = expand('%:p')
    if empty(l:fileName)
        let l:textList = getline(0, '$')
        let l:fileName = fnamemodify(tempname(), ':h') . '/temp.md'
        call writefile(l:textList, l:fileName)
    else
        update
    endif
    if !exists('b:pandoc_converting')
        " `b:pandoc_converting` is used to keep track of whether a current .tex
        " file is being used for conversion and so should not be overwritten.
        let b:pandoc_converting = 0
    endif
    " Don't change existing .tex file if currently in use
    if b:pandoc_converting && (l:command ==# 'markdown-to-PDF-LaTeX.py' ||
                    \ l:command ==# 'convert-to-markdown.py')
        call pandoc#conversion#DisplayError(0, 'Already converting...')
    else
        if l:command ==# 'markdown-to-PDF-LaTeX.py' ||
                    \ l:command ==# 'convert-to-markdown.py'
            let b:pandoc_converting = 1
        endif
        call setloclist(0, [])
        if has('nvim')
            let b:conversionJob = jobstart('/usr/bin/env python3 ' .
                    \ s:pythonScriptDir . l:command .
                    \ ' "' . l:fileName . '" ' . l:auxCommand,
                    \ {'on_stdout': 'pandoc#conversion#DisplayMessages',
                    \ 'on_stderr': 'pandoc#conversion#DisplayError',
                    \ 'on_exit': 'pandoc#conversion#EndProcess'})
        else
            let b:conversionJob = job_start('/usr/bin/env python3 ' .
                    \ s:pythonScriptDir . l:command .
                    \ ' "' . l:fileName . '" ' . l:auxCommand,
                    \ {'out_cb': 'pandoc#conversion#DisplayMessages',
                    \ 'err_cb': 'pandoc#conversion#DisplayError',
                    \ 'close_cb': 'pandoc#conversion#EndProcess'})
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
            autocmd BufWritePost <buffer> :call <SID>MyConvertHelper("markdown-to-PDF-LaTeX.py")
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
        call conversion#ToggleAutoPDF()
        call <SID>MyConvertHelper(a:command, l:auxCommand)
        call conversion#ToggleAutoPDF()
    else
        call <SID>MyConvertHelper(a:command, l:auxCommand)
    endif
endfunction
