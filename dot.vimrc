" $Id$

set nocompatible

" Switch syntax highlighting on, when the terminal has colors
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

set background=dark
if has("gui_runing")
  colorscheme fruity
else
  colorscheme delek
endif

set sts=2 sw=2 ts=8 et
set autoindent           " keep the previous line's indentation
set cindent              " indent after line ending in {, and use 'cinwords'
                         " see also ':help c-indent'
set modeline modelines=5
set ruler
set showcmd
set history=50 incsearch
set bs=2
set laststatus=2
set wildmenu
set ff=unix
set statusline=%<%f%h\ %m%r%=%b\ 0x%B\ \ \ \ \ \ \ \ \ %l,%c%V\ %P
filetype plugin indent on

" Disable previewing as it can be very slow
if version >= 700
  set completeopt-=preview
endif

" Save marks for 100 files, and global marks
set viminfo='100,f1,\"100,:20,%,n~/.viminfo
set nobackup
" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid or when inside an event handler
" (happens when dropping a file on gvim).
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif
" Restore last line
" au BufReadPost * if line("'\"") > 0|if line("'\"") <= line("$")|exe("norm '\"")|else|exe "norm $"|endif|endif 

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
command! DiffOrig vert new | set bt=nofile | r # | 0d_ | diffthis
                \ | wincmd p | diffthis

" Check if the buffer is a tcl file
au BufRead,BufNewFile *.tcl set filetype=tcl
au BufRead,BufNewFile *.tcl set cinkeys=0{,0},0),:,!^F,o,O,e

" Autoclose curly braces
" inoremap {              {}<LEFT>
" inoremap {<CR>  {<CR>}<ESC>O
" inoremap {{             {
" inoremap {}             {}

" Subversion commit file
au BufNewFile,BufRead svn-commit*.tmp           setf svn

" smarty
au BufRead,BufNewFile *.tpl set filetype=smarty

" php
au BufRead,BufNewFile *.php set filetype=php
" au BufRead,BufNewFile *.php colorscheme ir_black
au BufRead,BufNewFile *.php set foldmethod=syntax

" Fix highlighting breaking when closing buffers
let g:miniBufExplForceSyntaxEnable = 1

let php_sql_query = 1
let php_folding = 3
let tcl_sql_active = 1
let tcl_html_active = 1

" Recommended by http://wiki.tcl.tk/4049
au BufRead,BufNewFile *.tcl set sts=4 sw=4 ts=4 noet

" Do not inadvertently break a line
au BufRead,BufNewFile *.tcl set textwidth=0


" Comments
au BufRead,BufNewFile *.tcl set comments=:#
au BufRead,BufNewFile *.tcl set formatoptions+=r      " Automatically insert the current comment leader
au BufRead,BufNewFile *.tcl set formatoptions+=q      " Allow formatting of comments with 'gq'

" Prevent the comment character from forcibly being inserted in column 1
au BufRead,BufNewFile *.tcl set cpoptions-=<          " allow '<keycode>' forms in mappings, e.g. <CR>
au BufRead,BufNewFile *.tcl inoremap # X<BS>#
au BufRead,BufNewFile *.tcl set cinkeys-=0#           " # in column 1 does not prevent >> from indenting
au BufRead,BufNewFile *.tcl set indentkeys-=0#

" Folding
au BufRead,BufNewFile *.tcl set foldmethod=syntax
" au BufRead,BufNewFile *.tcl syn keyword tclStatement        global return lindex
" au BufRead,BufNewFile *.tcl syn match   tclStatement        "proc" contained
" au BufRead,BufNewFile *.tcl syntax region tclFunc start="^\z(\s*\)proc.*{$" end="^\z1}$" transparent fold contains=ALL

" Tcl maps
" au Filetype tcl map! ${ ${}<ESC>ha

" let b:unaryTagsStack="area base br dd dt hr img input link meta param"
au Filetype xhtml,html,tcl,smarty,php let b:closetag_html_style=1
au Filetype xhtml,html,xml,xsl,tcl,smarty,php source ~/.vim/scripts/closetag.vim
" Auto close </
au Filetype xhtml,html,xml,xsl,tcl,smarty,php map! </ <C-_>
" Auto close <? for php
" au Filetype php map! <? <? ?><ESC>hhi
au Filetype php map! <? <??><ESC>hi
" Auto create array syntax in strings
" au Filetype php map! {$ {$['']}<ESC>hhhhi
" au Filetype php map! {$ {$']}<ESC>hhi

" Misc maps
" Reformat/indent whole file
noremap ,5 1GvG=

"
" NextIndent()
"
" Jump to the next or previous line that has the same level or a lower
" level of indentation than the current line.
"
" exclusive (bool): true: Motion is exclusive
" false: Motion is inclusive
" fwd (bool): true: Go to next line
" false: Go to previous line
" lowerlevel (bool): true: Go to line with lower indentation level
" false: Go to line with the same indentation level
" skipblanks (bool): true: Skip blank lines
" false: Don't skip blank lines
function! NextIndent(exclusive, fwd, lowerlevel, skipblanks)
 let line = line('.')
 let column = col('.')
 let lastline = line('$')
 let indent = indent(line)
 let stepvalue = a:fwd ? 1 : -1
 while (line > 0 && line <= lastline)
   let line = line + stepvalue
   if ( ! a:lowerlevel && indent(line) == indent ||
     \ a:lowerlevel && indent(line) < indent)
     if (! a:skipblanks || strlen(getline(line)) > 0)
       if (a:exclusive)
         let line = line - stepvalue
       endif
       exe line
       exe "normal " column . "|"
       return
     endif
   endif
 endwhile
endfunc

" Moving back and forth between lines of same or lower indentation.
nnoremap <silent> [l :call NextIndent(0, 0, 0, 1)<cr>
nnoremap <silent> ]l :call NextIndent(0, 1, 0, 1)<cr>
nnoremap <silent> [L :call NextIndent(0, 0, 1, 1)<cr>
nnoremap <silent> ]L :call NextIndent(0, 1, 1, 1)<cr>
vnoremap <silent> [l <esc>:call NextIndent(0, 0, 0, 1)<cr>m'gv''
vnoremap <silent> ]l <esc>:call NextIndent(0, 1, 0, 1)<cr>m'gv''
vnoremap <silent> [L <esc>:call NextIndent(0, 0, 1, 1)<cr>m'gv''
vnoremap <silent> ]L <esc>:call NextIndent(0, 1, 1, 1)<cr>m'gv''
onoremap <silent> [l :call NextIndent(0, 0, 0, 1)<cr>
onoremap <silent> ]l :call NextIndent(0, 1, 0, 1)<cr>
onoremap <silent> [L :call NextIndent(1, 0, 1, 1)<cr>
onoremap <silent> ]L :call NextIndent(1, 1, 1, 1)<cr>

" Same thing (less effective)
nn <M-,> k:call search ("^". matchstr (getline (line (".")+ 1), '\(\s*\)') ."\\S", 'b')<CR>^
nn <M-.> :call search ("^". matchstr (getline (line (".")), '\(\s*\)') ."\\S")<CR>^
