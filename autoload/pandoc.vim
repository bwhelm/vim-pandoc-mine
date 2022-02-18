scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================

" function! pandoc#AutoNameFile( ... ) abort  " {{{
"     " For pandoc files, this function will generate a filename from the title
"     " field of the YAML header, replacing diacritics, stripping out
"     " non-alphabetic characters and short words, converting ',' to '-', and
"     " converting spaces to `_`.
"     try
"         silent update
"     catch
"     endtry
"     let l:suffix = join(a:000, ' ')
"     let l:fileBegin = join(getline(0, 200), "\n")
"     if &filetype ==# 'pandoc'
"         let l:title = matchstr(l:fileBegin,
"             \ '\ntitle:\s\+\zs.\{-}\ze\s*\(\^\[\|\n\)')
"         let l:extension = '.md'
"     elseif &filetype ==# 'tex'
"         let l:title = matchstr(l:fileBegin,
"             \ '\ntitle:\s\+\zs.\{-}\ze\s*\(\^\[\|\n\)')
"         let l:extension = '.tex'
"     endif
"     if l:title ==# ''
"         echohl WarningMsg
"         redraw | echo 'Could not find title.'
"         echohl None
"         return
"     endif
"     if !empty(l:suffix)  " Add suffix if there is one
"         let l:title = l:title . '-' . l:suffix
"     else
"         " Try to guess a suffix: if presentation, name it that!
"         if l:fileBegin =~# '\n- aspectratio' || l:fileBegin =~# '\ntheme' ||
"                     \ l:fileBegin =~# '\nbeamerarticle'
"             let l:title .= '-presentation'
"             redraw | echo 'Identified as presentation.'
"         endif
"     endif
"     let l:title = tolower(l:title)
"     let l:title = substitute(l:title, '[.!?,:;] ', '-', 'g')
"     let l:title = tr(l:title, '/ ', '-_')
"     let l:title = iconv(l:title, 'utf8', 'ascii//TRANSLIT')
"     let l:title = substitute(l:title, '[^a-z0-9 _-]', '', 'g')
"     let l:title = substitute(l:title, '\c\<\(a\|an\|the\)_', '', 'g')
"     let l:title = substitute(l:title, '_\{2,}', '_', 'g')
"     let l:title = substitute(l:title, '-\{2,}', '-', 'g')
"     let l:newName = expand('%:p:h') . '/' . l:title . l:extension
"     let l:currentName = expand('%:p')
"     if l:newName !=? l:currentName && findfile(l:newName, '.;') !=# ''
"         " Note: if l:newName merely modifies the case of l:currentName, this
"         " will not throw up a warning. In most cases this is what I want,
"         " but if there is another file that is a case variant of the
"         " current file, this could be problematic. I won't worry about
"         " this possibility.
"         echohl WarningMsg
"         echo 'Destination file (' . fnamemodify(l:newName, ':t') . ') already exists. Overwrite? (y/N)'
"         if getchar() != 121  " ('y')
"             echo 'Aborting...'
"             echohl None
"             return
"         endif
"         echo 'Overwriting...'
"         echohl None
"     endif
"     if l:currentName !=# ''  "File already has a name
"         if findfile(l:currentName, '.;') ==# ''  " No existing file
"             execute 'write' l:newName
"         elseif l:currentName ==# l:newName  " Existing file with same name
"             silent update
"             echohl Comment
"             echo 'Updated existing file w/o renaming.'
"             echohl None
"         else  " Existing file with different name
"             if rename(l:currentName, l:newName)
"                 echohl Error
"                 echom 'Error renaming file' fnamemodify(l:currentName, ':t') 'to' fnamemodify(l:newName, ':t')
"                 echohl None
"             else
"                 echo 'File renamed to:' fnamemodify(l:newName, ':t')
"                 " Next line is needed when l:newName only modifies the
"                 " case of l:currentName: bwipeout will kill the
"                 " current buffer, and so it needs to be reloaded. (In
"                 " other cases, `edit` will do nothing.)
"                 execute 'edit' l:newName
"                 execute 'bwipeout' fnameescape(l:currentName)
"             endif
"         endif
"     else
"         " File does not already have a name. (Need `!` because we might be overwriting an existing file.)
"         execute 'write!' l:newName
"     endif
" endfunction
" " }}}
