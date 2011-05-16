" $Id$

" A lot of this is from google and various prefs/testing/experience

set nocompatible

" Switch syntax highlighting on, when the terminal has colors
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

set background=dark
if has("gui_runing")
  colorscheme fruity
  set guioptions-=T
else
  colorscheme delek
endif

set encoding=utf-8
try
  lang en_US
catch
endtry

" set cpo+=$
set sts=2 sw=2 ts=8 et
set autoindent           " keep the previous line's indentation
set cindent              " indent after line ending in {, and use 'cinwords'
                         " see also ':help c-indent'
set modeline modelines=5
set nu " Show line numbers
" set list " Show tabs as ^I
set ruler
set showcmd
set history=700 incsearch
" Keep some lines around scrolling
set so=7
set bs=2
set laststatus=2
set wildmenu
set ff=unix
set statusline=\ %{HasPaste()}%<%f%h\ %m%r%=%b\ 0x%B\ \ %{fugitive#statusline()}\ \ \ \ \ \ \ %l,%c%V\ %P
set magic
set nolazyredraw
filetype plugin indent on
" 500 ms for mapped key checking
set tm=500

" Disable bells
set novisualbell noerrorbells t_vb=

" Disable previewing as it can be very slow
if version >= 700
  set completeopt-=preview
endif

" Save marks for 100 files, and global marks
set viminfo='100,f1,\"100,:20,%,n~/.viminfo
set nobackup
set nowb
" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid or when inside an event handler
" (happens when dropping a file on gvim).
autocmd BufReadPost *
  \ if line("'\"") > 0 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif
" Restore last line
" au BufReadPost * if line("'\"") > 0|if line("'\"") <= line("$")|exe("norm '\"")|else|exe "norm $"|endif|endif 

" Check if the buffer is a tcl file
au BufRead,BufNewFile *.tcl set filetype=tcl
au BufRead,BufNewFile *.tcl set cinkeys=0{,0},0),:,!^F,o,O,e


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Parenthesis/bracket expanding
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
vnoremap $1 <esc>`>a)<esc>`<i(<esc>
vnoremap $2 <esc>`>a]<esc>`<i[<esc>
vnoremap $3 <esc>`>a}<esc>`<i{<esc>
vnoremap $$ <esc>`>a"<esc>`<i"<esc>
vnoremap $q <esc>`>a'<esc>`<i'<esc>
vnoremap $e <esc>`>a"<esc>`<i"<esc>
vnoremap $r <esc>`>a %><esc>`<i<%= <esc>

" Map auto complete of (, ", ', [
inoremap $1 ()<esc>i
inoremap $2 []<esc>i
inoremap $3 {}<esc>i
inoremap $4 {<esc>o}<esc>O
inoremap $q ''<esc>i
inoremap $e ""<esc>i
inoremap $t <><esc>i
inoremap $r <%= =><esc>i


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
let g:miniBufExplMapWindowNavArrows = 1

let php_sql_query = 1
let php_folding = 3
let tcl_sql_active = 1
let tcl_html_active = 1

" Recommended by http://wiki.tcl.tk/4049
au BufRead,BufNewFile *.tcl set sts=4 sw=4 ts=4 noet
au BufRead,BufNewFile *.py set sts=4 sw=4 ts=4 noet
au BufRead,BufNewFile *.xml set sts=4 sw=4 ts=4 noet

au BufRead,BufNewFile *.tpl set sts=4 sw=4 ts=4 et
au BufRead,BufNewFile *.php set sts=4 sw=4 ts=4 et
au BufRead,BufNewFile *.js set sts=4 sw=4 ts=4 et

" Do not inadvertently break a line
set textwidth=0
" Wrap text for display only
set wrap
set lbr " Use smart wrapping


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
au BufRead,BufNewFile *.rb set foldmethod=syntax
" au BufRead,BufNewFile *.tcl syn keyword tclStatement        global return lindex
" au BufRead,BufNewFile *.tcl syn match   tclStatement        "proc" contained
" au BufRead,BufNewFile *.tcl syntax region tclFunc start="^\z(\s*\)proc.*{$" end="^\z1}$" transparent fold contains=ALL

" Tcl maps
" au Filetype tcl map! ${ ${}<ESC>ha

" let b:unaryTagsStack="area base br dd dt hr img input link meta param"
au Filetype xhtml,html,tcl,smarty,php,eruby let b:closetag_html_style=1
au Filetype xhtml,html,xml,xsl,tcl,smarty,php,eruby source ~/.vim/scripts/closetag.vim
" Auto close </
au Filetype xhtml,html,xml,xsl,tcl,smarty,php,eruby map! </ <C-_>
" Auto close <? for php
" au Filetype php map! <? <? ?><ESC>hhi
au Filetype php map! <? <??><ESC>hi

" Auto close <% and <%= for eruby
au Filetype eruby map! <%= <%=  %><ESC>hhi
au Filetype eruby map! <% <%  %><ESC>hhi


" 7.3 features
try
  set undodir=~/.vimundo
  set undofile
  set undolevels=1000 "maximum number of changes that can be undone
  set undoreload=10000 "maximum number lines to save for undo on a buffer reload

  set cryptmethod=blowfish
catch
endtry



" Misc maps
let mapleader = ","
let g:mapleader = ","

map <leader>pp :setlocal paste!<cr>

" Reformat/indent whole file
noremap <leader>5 1GvG=

" fast saving
nmap <leader>w :w!<cr>

" Disable current search
map <silent> <leader><cr> :noh<cr>

" Close the current buffer
map <leader>bd :bd<cr>

function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    else
        return ''
    endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Cope
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Do :help cope if you are unsure what cope is. It's super useful!
map <leader>cc :botright cope<cr>
map <leader>n :cn<cr>
map <leader>p :cp<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Pressing ,ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>

"Shortcuts using <leader>
map <leader>sn ]s
map <leader>sp [s
map <leader>sa zg
map <leader>s? z=


""""""""""""""""""""""""""""""
" => MRU plugin
""""""""""""""""""""""""""""""
let MRU_Max_Entries = 400
map <leader>f :MRU<CR>


""""""""""""""""""""""""""""""
" => Visual mode related
""""""""""""""""""""""""""""""
" Really useful!
"  In visual mode when you press * or # to search for the current selection
vnoremap <silent> * :call VisualSearch('f')<CR>
vnoremap <silent> # :call VisualSearch('b')<CR>

" When you press gv you vimgrep after the selected text
vnoremap <silent> gv :call VisualSearch('gv')<CR>
map <leader>g :vimgrep // **/*.<left><left><left><left><left><left><left>


function! CmdLine(str)
    exe "menu Foo.Bar :" . a:str
    emenu Foo.Bar
    unmenu Foo
endfunction

" From an idea by Michael Naumann
function! VisualSearch(direction) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", '\\/.*$^~[]')
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'b'
        execute "normal ?" . l:pattern . "^M"
    elseif a:direction == 'gv'
        call CmdLine("vimgrep " . '/'. l:pattern . '/' . ' **/*.')
    elseif a:direction == 'f'
        execute "normal /" . l:pattern . "^M"
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction
