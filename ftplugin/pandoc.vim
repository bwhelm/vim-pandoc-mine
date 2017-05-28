" vim: set fdm=marker foldlevel=1:
scriptencoding utf-8
" My settings that should apply only to files with filetype=pandoc.

if exists('b:loaded_pandoc_mine')
	finish
endif
let b:loaded_pandoc_mine=1

" =========================================================================== }}}
" AutoCmd {{{1
" ===========================================================================

augroup pandoc
	autocmd!
	" CD to directory of current file
	autocmd BufWinEnter * lcd %:p:h
augroup END

" =========================================================================== }}}
" Variables for Conversions {{{1
" ===========================================================================

let b:pandoc_converting = 0  " keeps track of whether currently converting or not
let b:pandoc_autoPDFEnabled = 0  " Turn autoPDF off by default...
let b:pandoc_lastConversionMethod = 'markdown-to-PDF-LaTeX.py'  " Last method used for conversions

" ============================================================================ }}}
" Key mappings {{{1
" ============================================================================

" Jumping to Headings {{{2
" -------------------
function! s:JumpToHeader(direction)
	let l:jumpLine = search('^#\{1,6}\s.*', a:direction . 'nW')
	if l:jumpLine > 0
		execute l:jumpLine
	else
		echohl Error
		if a:direction ==# 'b'
			echo 'No previous header'
		else
			echo 'No next header'
		endif
		echohl None
	endif
endfunction
noremap <buffer><silent> ]] :call <SID>JumpToHeader('')<CR>
noremap <buffer><silent> [[ :call <SID>JumpToHeader('b')<CR>

" Fold Section {{{2
" ------------
nnoremap <buffer><silent> z3 :call pandoc#fold#foldSection()<CR>
nnoremap <buffer><silent> z# :call pandoc#fold#foldAllSections()<CR>

" for conversions {{{2
" ---------------
"  (For all of these, call the helper function with relevant command.)

" Note that the `cc` mapping is to repeat the last conversion
nnoremap <buffer><silent> <LocalLeader>cc :call pandoc#conversion#MyConvertMappingHelper("")<CR>
inoremap <buffer><silent> <LocalLeader>cc <C-o>:call pandoc#conversion#MyConvertMappingHelper("")<CR>
" PDF conversion
nnoremap <buffer><silent> <LocalLeader>cp :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
inoremap <buffer><silent> <LocalLeader>cp <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-LaTeX.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cP :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cP <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-PDF-pandoc-direct.py")<CR>
" HTML conversion
nnoremap <buffer><silent> <LocalLeader>ch :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>ch <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-html-pandoc-direct.py")<CR>
" RevealJS conversion
nnoremap <buffer><silent> <LocalLeader>cr :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cr <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-revealjs-pandoc-direct.py")<CR>
" LaTeX Beamer conversion
nnoremap <buffer><silent> <LocalLeader>cb :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cb <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-beamer-pandoc-direct.py")<CR>
" Word .docx conversion
nnoremap <buffer><silent> <LocalLeader>cd :call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cd <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-docx-pandoc-direct.py")<CR>
" Markdown conversion
nnoremap <buffer><silent> <LocalLeader>cm :call
		\ pandoc#conversion#MyConvertMappingHelper("convert-to-markdown.py")<CR>
nnoremap <buffer><silent> <LocalLeader>cM :call pandoc#conversion#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
inoremap <buffer><silent> <LocalLeader>cM <C-o>:call
		\ pandoc#conversion#MyConvertMappingHelper("markdown-to-markdown-pandoc-direct.py")<CR>
" Kill current conversion
nnoremap <buffer><silent> <LocalLeader>ck :call pandoc#conversion#KillProcess()<CR>

" Path to plugin's python conversion folder (e.g.,
" `~/.vim/plugged/vim-pandoc-mine/pythonx/conversion/`)
let s:pythonScriptDir = expand('<sfile>:p:h:h') . '/pythonx/conversion/'
command! RemoveAuxFiles :execute '!'
			\ . s:pythonScriptDir . 'remove-aux-files.py'
			\ . ' ' . fnameescape(expand('%:p'))
nnoremap <buffer><silent> <LocalLeader>cK :RemoveAuxFiles<CR>

nnoremap <buffer><silent> <LocalLeader>ca :call pandoc#conversion#ToggleAutoPDF()<CR>
inoremap <buffer><silent> <LocalLeader>ca <C-o>:call pandoc#conversion#ToggleAutoPDF()<CR>

nnoremap <silent><buffer> <C-]> :call pandoc#references#GoToReference()<CR>

" Find Comments {{{2
" -------------
" Note: allow remaps so that it works with vim-slash
nmap <buffer><silent> <LocalLeader>fc /\[.\{-}\]{\.[a-z]\{-}}/<CR>

" Citations {{{2
" ---------
" Find page references needing complete citations
noremap <buffer><silent> <LocalLeader>fr /(\(\d\+f\{0,2}\(, \d\+f\{0,2}\\|--\d\+\)\?\))<CR>

" To break undo sequence automatically {{{2
" ------------------------------------
" These interfere with abbreviations if `inoremap` is used, so I'm using
" simply `imap`.
imap <buffer><silent> . .<C-G>u
imap <buffer><silent> ! !<C-G>u
imap <buffer><silent> ? ?<C-G>u
imap <buffer><silent> ; ;<C-G>u
"imap <buffer><silent> ] ]<C-G>u
" The following interferes with listmode.
"imap <buffer><silent> <CR> <CR><C-G>u

" List mode {{{2
" ---------
" Start with listmode on by default ... but don't toggle list mode if the
" buffer has already been loaded.
if !exists('b:listmode')
	let b:listmode=1
	call listmode#ListModeOn(0)
endif

" Miscellaneous {{{2
" -------------
" In visual and normal modes, select text to be indexed and hit <ctrl-x> ("indeX")
vnoremap <buffer><silent> <C-x> c<i <Esc>pa><Esc>mip`i
nnoremap <buffer><silent> <C-x> ciw<i <Esc>pa><Esc>mip`i

" Jump to corresponding line in Skim.app
if has('nvim')
	command! JumpToPDF silent call jobstart("/usr/bin/env python3 " .
				\ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
				\ ' "' . expand('%:p') . '" ' . line("."), {"on_stdout":
				\ "pandoc#conversion#DisplayMessages", "on_stderr": "pandoc#conversion#DisplayError"})
else  " normal vim
	command! JumpToPDF silent call job_start("/usr/bin/env python3 " .
				\ s:pythonScriptDir . 'jump-to-line-in-Skim.py' .
				\ ' "' . expand('%:p') . '" ' . line("."), {"out_cb":
				\ "pandoc#conversion#DisplayMessages", "err_cb": "pandoc#conversion#DisplayError"})
endif
nnoremap <buffer><silent> <LocalLeader>j :JumpToPDF<CR>
" nnoremap <buffer><silent> <LocalLeader>j :call system('python ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
" FIXME: Should the next line be mapped to :JumpToPDF?
inoremap <buffer><silent> <LocalLeader>j <C-o>:call system('python ~/.vim/python-scripts/jump-to-line-in-Skim.py "' . expand('%') . '" ' . line('.'))<CR>
" Open Dictionary.app with word under cursor
nnoremap <buffer><silent> K :!open dict:///<cword><CR><CR>
" Faster mapping to bibliography/cross-reference completion
"inoremap <buffer> <C-c> <C-x><C-u>
" Italicize/boldface current word
nnoremap <buffer><silent> <D-e> "zciw*<Esc>"zpa*<Esc>
inoremap <buffer><silent> <D-e> <Esc>"zciw*<Esc>"zpa*
vnoremap <buffer><silent> <C-e> c*<C-r>"*<Esc>gvlol
nnoremap <buffer><silent> <D-b> "zciw**<Esc>"zpa**<Esc>
inoremap <buffer><silent> <D-b> <Esc>"zciw**<Esc>"zpa**
vnoremap <buffer><silent> <C-b> c**<C-r>"**<Esc>gvlloll

" Next mapping will delete the surrounding comment, leaving the inside text.
" Note that it doesn't do any checking to see if the cursor is actually in a
" comment.
nnoremap <buffer><silent> dsc mclT[dt]hPldf}`ch
" Next mappings allow for changing the comment type of next comment. Note that
" it doesn't do anything about checking to see where that comment is.
nnoremap <buffer><silent> cscc mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwcomment<Esc>`c
nnoremap <buffer><silent> cscm mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwmargin<Esc>`c
nnoremap <buffer><silent> cscf mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwfixme<Esc>`c
nnoremap <buffer><silent> csch mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwhighlight<Esc>`c
nnoremap <buffer><silent> cscs mc/{\.\(comment\\|margin\\|fixme\\|highlight\\|smcaps\)}<CR>llcwsmcaps<Esc>`c
"}}}

" ============================================================================ }}}
" TextObjects {{{1
" ============================================================================
" If textobj-user plugin is loaded, ...
if exists('*textobj#user#plugin')
	" Create text object for deleting/changing/etc.
	call textobj#user#plugin('pandoccomments', {
		\	'comment': {
		\		'pattern': ['\[',
					\ '\]{\.\(comment\|margin\|fixme\|highlight\|smcaps\)}'],
		\		'select-a': 'ac',
		\		'select-i': 'ic',
		\	},
		\ })
	" Create text object for (sub)sections
	function! FindAroundSection()
		let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
		return ['V', [0, l:startLine, 1, 0], [0, l:endLine, 1, 0]]
	endfunction
	function! FindInsideSection()
		let [l:startLine, l:endLine] = pandoc#fold#FindSectionBoundaries()
		let l:eof = line('$')
		while l:startLine < l:eof
			let l:startLine = l:startLine + 1
			if getline(l:startLine) =~# '\S'
				break
			endif
		endwhile
		while l:endLine > l:startLine
			if getline(l:endLine) =~# '\S'
				break
			endif
			let l:endLine = l:endLine - 1
		endwhile
		return ['V', [0, l:startLine, 1, 0], [0, l:endLine, 1, 0]]
	endfunction
	call textobj#user#plugin('pandocmine', {
		\ 'section': {
		\		'select-a': 'a#',
		\ 		'select-a-function': 'FindAroundSection',
		\		'select-i': 'i#',
		\ 		'select-i-function': 'FindInsideSection',
		\	},
		\ })
endif

" ============================================================================ }}}
" Completion Function for References/Bibliography {{{1
" ============================================================================
set omnifunc=pandoc#references#MyCompletion

" ============================================================================ }}}
" TOC Support {{{1
" ============================================================================
command! TOC call pandoc#toc#ShowTOC()

" ============================================================================ }}}
" Folding {{{1
" ============================================================================
set foldtext=pandoc#fold#FoldText()

" ============================================================================ }}}
" Other {{{1
" ============================================================================
" Don't want numbers displayed for pandoc documents
"setlocal nonumber
"setlocal norelativenumber
" Turn on spell checking
setlocal spell spelllang=en_us
" Turn off checking for capitalization errors
"setlocal spellcapcheck=
setlocal equalprg=pandoc\ -t\ markdown+table_captions-simple_tables-multiline_tables-grid_tables+pipe_tables+line_blocks-fancy_lists+definition_lists+example_lists\ --wrap=none\ --from=markdown-fancy_lists\ --atx-headers\ --standalone\ --preserve-tabs\ --normalize
" Allow wrapping past BOL and EOL when using `h` and `l`
set whichwrap+=h,l
" List of characters that can cause a line break; don't want breaking at '@',
" since this marks citations/cross-references.
set breakat-=@
