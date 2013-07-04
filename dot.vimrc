" $Id$

" A lot of this is from google and various prefs/testing/experience

set nocompatible

" Switch syntax highlighting on, when the terminal has colors
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
  set synmaxcol=200
endif

set background=dark
if &t_Co > 16 || has("gui_running")

  colorscheme solarized

  if has("gui_running")
    au FileType ruby,eruby colorscheme railscasts
    let g:solarized_degrade=1
  else
    let g:solarized_termcolors=256
  endif

else
  colorscheme delek
endif
set bg=dark

" Use POSIX shell syntax so $() is not hilighted red
let g:is_posix = 1

if has("gui_running")
  set guioptions-=T
endif

set encoding=utf-8
try
  lang en_US
catch
endtry

" set cpo+=$
set sw=2 ts=8
set autoindent           " keep the previous line's indentation
set cindent              " indent after line ending in {, and use 'cinwords'
                         " see also ':help c-indent'
if exists('+colorcolumn')
  set colorcolumn=80
endif
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
set statusline=\ %{HasPaste()}%{SyntasticStatuslineFlag()}%<%f%h\ %m%r%=%b\ 0x%B\ \ %{fugitive#statusline()}\ \ \ \ \ \ \ %l,%c%V\ %P
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

" Define <leader>
let mapleader = ","
let g:mapleader = ","

" Check if the buffer is a tcl file
au BufRead,BufNewFile *.tcl set filetype=tcl
au BufRead,BufNewFile *.tcl set cinkeys=0{,0},0),:,!^F,o,O,e


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
au BufRead,BufNewFile *.tcl set sts=4 sw=4 ts=8 noet
au BufRead,BufNewFile *.snippet set sts=4 sw=4 ts=8 noet
au BufRead,BufNewFile *.py set sts=4 sw=4 ts=8 et
au BufRead,BufNewFile *.xml set sts=4 sw=4 ts=8 noet
au BufRead,BufNewFile vuln.xml set sts=2 sw=2 ts=8 noet

au BufRead,BufNewFile *.tpl set sts=4 sw=4 ts=4 et
au BufRead,BufNewFile *.php set sts=4 sw=4 ts=4 et
au BufRead,BufNewFile *.js set sts=4 sw=4 ts=4 et

au BufRead,BufNewFile *.sh set sts=0 sw=8 ts=8 noet

augroup filetypedetect
au BufNewFile,BufRead *.xt  setf xt
augroup END

" Do not inadvertently break a line
set textwidth=0
" Wrap text for display only
set wrap
set lbr " Use smart wrapping

""""""""""""""""""
" snipMate configuration
""""""""""""""""""
let g:snips_author = 'Bryan Drewery'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Parenthesis/bracket expanding
" (http://vim.wikia.com/wiki/Automatically_append_closing_characters)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Auto close braces and skip over them as well
" autoclose.vim params (http://www.vim.org/scripts/script.php?script_id=2009)
let g:AutoClosePairs = {'(': ')', '{': '}', '[': ']', '"': '"', "'": "'", "/*":"*/"}
let g:AutoCloseRegions = ["Comment", "String", "Character"]
map <leader>a :AutoCloseToggle<cr>
" Disable and use delimitMate instead
let g:AutoCloseOn = 0
let g:loaded_AutoClose = 1

" delimitMate config (https://github.com/Raimondi/delimitMate)
" au FileType mail let b:delimitMate_autoclose = 0 
map <leader>d :DelimitMateSwitch<cr>
let delimitMate_balance_matchpairs = 1
let delimitMate_excluded_regions = "Comment,String,Character"

" Auto close </ with closetag.vim
" au Filetype xhtml,html,xml,xsl,tcl,smarty,php,eruby map! </ <C-_>

" Autoclose on > and be smart about it
au FileType xhtml,xml,smarty,php,eruby so ~/.vim/ftplugin/html_autoclosetag.vim


" Auto close <? for php
" au Filetype php map! <? <? ?><ESC>hhi
" au Filetype php map! <? <??><ESC>hi

" Auto close <% and <%= for eruby
au Filetype eruby map! <%= <%=  %><ESC>hhi
au Filetype eruby map! <% <%  %><ESC>hhi

" Tcl maps
" au Filetype tcl map! ${ ${}<ESC>ha

" Auto close comments
" FIXME: This first one doesn't seem to work
inoremap /*          /**/<Left><Left>
inoremap /*<Space>   /*<Space><Space>*/<Left><Left><Left>
inoremap /*<CR>      /*<CR>/<Esc>O
" When setting up a doc comment, always expand out
inoremap /**         /**<CR>/<Esc>O
inoremap /**<Space>  /**<CR>/<Esc>O
inoremap /**<CR>     /**<CR>/<Esc>O
inoremap <Leader>/*  /*


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

" let b:unaryTagsStack="area base br dd dt hr img input link meta param"
au Filetype xhtml,html,tcl,smarty,php,eruby let b:closetag_html_style=1
au Filetype xhtml,html,xml,xsl,tcl,smarty,php,eruby source ~/.vim/scripts/closetag.vim

" 7.3 features
try
  set undodir=~/.vimundo
  set undofile
  set undolevels=1000 "maximum number of changes that can be undone
  set undoreload=10000 "maximum number lines to save for undo on a buffer reload

  set cryptmethod=blowfish
catch
endtry

" CTags support
map <F8> :!/usr/bin/ctags -R --c++-kinds=+p --fields=+iaS --extra=+q .<CR>
map <leader>t :TagbarToggle<cr>
inoremap <leader><tab> <C-R>=AutoCompletion()<CR>

function! AutoCompletion()
  if &omnifunc != ''
    return "\<C-X>\<C-O>"
  elseif &dictionary != ''
    return "\<C-K>"
  else
    return "\<C-N>"
  endif
endfunction

" Misc maps
map <leader>pp :setlocal paste!<cr>

" Reload vimrc
map <leader>v :source ~/.vimrc<cr>

" Alternative ESC mapping in insert mode
imap jj <esc>

" map <C-w> :w!<CR>       " Map quick save

map <leader>e <esc>:NERDTreeToggle<cr>


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

"""""""""""""""""""""""""
" syntastic configuration
"""""""""""""""""""""""""

map <leader>ce :Errors<cr>
let g:syntastic_enable_signs = 1
" Auto open/close window
let g:syntastic_auto_loc_list = 0
let g:syntastic_quiet_warnings = 0
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [], 'passive_filetypes': [] }
" let g:syntastic_disabled_filetypes = ['c', 'php']
let g:syntastic_stl_format = '[%E{Err: %fe #%e}%B{, }%W{Warn: %fw #%w}]'
