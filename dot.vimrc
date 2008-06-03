" $Id$
" colorscheme murphy
" set sw=4 ts=4 cindent ruler

" Default
syntax on
set background=dark
colorscheme delek
set sts=2 sw=2 ts=8 et
set autoindent           " keep the previous line's indentation
set cindent              " indent after line ending in {, and use 'cinwords'
                         " see also ':help c-indent'
set modeline modelines=5
set ruler
set hlsearch history=50 incsearch
set bs=2
filetype on

" Standard mappings -Eric Peterson
map <F1> :tabn<ENTER>
map <F2> 0i### <ESC>j
map <F3> i#######################################################################<ESC>ji

" Restore last line
set viminfo='10,\"100,:20,%,n~/.viminfo
au BufReadPost * if line("'\"") > 0|if line("'\"") <= line("$")|exe("norm '\"")|else|exe "norm $"|endif|endif 

" Check if the buffer is a tcl file
au BufRead,BufNewFile *.tcl set filetype=tcl
au BufRead,BufNewFile *.tcl set cinkeys=0{,0},0),:,!^F,o,O,e

" Autoclose curly braces
" inoremap {              {}<LEFT>
" inoremap {<CR>  {<CR>}<ESC>O
" inoremap {{             {
" inoremap {}             {}


" smarty
au BufRead,BufNewFile *.tpl set filetype=smarty

" php
au BufRead,BufNewFile *.php set filetype=php
" au BufRead,BufNewFile *.php colorscheme ir_black
au BufRead,BufNewFile *.php set foldmethod=syntax

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
