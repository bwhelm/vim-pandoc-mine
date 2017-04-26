" ============================================================================
" Helper Functions for Pandoc {{{1
" ============================================================================

function! DisplayMessages(channel, text, ...)
	" To write to quickfix list. Note that `...` is there because neovim will
	" include `stdout` and `stderr` as part of its arguments; I can simply
	" ignore those.
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
			call KillProcess('silent')
		elseif l:item[:15] =~? 'error'
			echom l:item
			let b:errorFlag = 1
		endif
	endfor
	echohl None
endfunction

function! DisplayError(channel, text, ...)
	" To write to messages
	let l:winWidth = winwidth(0)
	echohl Comment
	if has('nvim')
		let l:text = a:text
	else
		let l:text = [a:text]
	endif
	for l:line in l:text
		if l:line !~? '^----\|^Running\|^Latexmk\|^  Citation\|^  Reference'
			echom l:line
			"echom l:line[: l:winWidth - 1]
		endif
	endfor
	echohl None
endfunction

function! EndProcess(...)
	if b:converting  " If job hasn't already been killed
		if b:errorFlag
			echohl WarningMsg
			echom 'Conversion Complete with Errors'
			echohl None
		else
			echohl Comment
			echom 'Conversion Complete'
			echohl None
		endif
		let b:converting=0
	endif
endfunction

function! KillProcess(...)
	" Presence of any argument indicates silence.
	if b:converting
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
		let b:converting=0
	else
		echohl Comment
		echom 'No job to kill!'
		echohl None
	endif
endfunction


" =========================================================================== }}}
" Functions for Conversions {{{1
" ===========================================================================


" Following function calls the conversion script given by a:command only if
" another conversion is not currently running.
function! MyConvertHelper(command, ...)
	if empty(a:command)
		let l:command = b:lastConversionMethod
	else
		let b:lastConversionMethod = a:command
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
	if !exists('b:converting')
		let b:converting = 0
	endif
	if b:converting
		call DisplayError(0, 'Already converting...')
	else
		let b:converting = 1
		call setloclist(0, [])
		if has('nvim')
			let b:conversionJob = jobstart('/usr/bin/env python3 ' . fnamemodify('~/.vim/python-scripts/' . l:command, ':p') . ' "' . l:fileName . '"', {'on_stdout': 'DisplayMessages', 'on_stderr': 'DisplayError', 'on_exit': 'EndProcess'})
		else
			let b:conversionJob = job_start('/usr/bin/env python3 ' . fnamemodify('~/.vim/python-scripts/' . l:command, ':p') . ' "' . l:fileName . '"', {'out_cb': 'DisplayMessages', 'err_cb': 'DisplayError', 'close_cb': 'EndProcess'})
		endif
	endif
endfunction

" Following function will temporarily turn off auto conversion, run the
" requested conversion, and then restore auto conversion to its former state.
" It will also check to see if the current buffer has a filename, and if not
" it will create a temporary .md file with the text of the current buffer and
" run the conversion on that file.
function! MyConvertMappingHelper(command)
	if !exists('b:autoPDFEnabled')
		let b:autoPDFEnabled = 0
	endif
	if b:autoPDFEnabled
		call <SID>ToggleAutoPDF()
		call <SID>MyConvertHelper(a:command)
		call <SID>ToggleAutoPDF()
	else
		call <SID>MyConvertHelper(a:command)
	endif
endfunction

