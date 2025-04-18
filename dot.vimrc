
" A lot of this is from google and various prefs/testing/experience

set nocompatible
" Enable pathogen
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

runtime bundle/vim-plug/plug.vim
call plug#begin('~/.vim/plugged')
call plug#end()

" Switch syntax highlighting on, when the terminal has colors
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
  set synmaxcol=500
  let g:solarized_extra_hi_groups=1
endif

if &t_Co > 16 || has("gui_running")
  if has("gui_running")
    au FileType ruby,eruby colorscheme railscasts
    let g:solarized_degrade=1
    set bg=light
  else
    let g:solarized_termcolors=256
    set bg=dark
  endif

  if &term =~ '256color'
    " disable Background Color Erase (BCE) so that color schemes
    " render properly when inside 256-color tmux and GNU screen.
    " see also http://snk.tuxfamily.org/log/vim-256color-bce.html
    set t_ut=
  endif

  colorscheme solarized8_high
else
  set bg=dark
  colorscheme delek
endif

if !has('gui_running') && &term =~ '^\%(screen\|tmux\)'
    " Better mouse support, see  :help 'ttymouse'
    " set ttymouse=sgr

    if &term =~ '-direct'
        " Enable true colors, see  :help xterm-true-color
        let &termguicolors = v:true
        let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
        let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
        " let &t_8f = "\<Esc>[38:2:%lu:%lu:%lum"
        " let &t_8b = "\<Esc>[48;2:%lu:%lu:%lum"
        colorscheme darkspectrum
    endif

    " Enable bracketed paste mode, see  :help xterm-bracketed-paste
    let &t_BE = "\<Esc>[?2004h"
    let &t_BD = "\<Esc>[?2004l"
    let &t_PS = "\<Esc>[200~"
    let &t_PE = "\<Esc>[201~"

    " Auto paste mode when pasting with bracketed paste
    let &t_SI .= "\<Esc>[?2004h"
    let &t_EI .= "\<Esc>[?2004l"

    inoremap <special> <expr> <Esc>[200\~ XTermPasteBegin()
    function! XTermPasteBegin()
        if mode() == 'n'
                let b:paste_inserted = 1
                startinsert
        else
                let b:paste_inserted = 0
        endif
        if ! &paste
                " set pastetoggle=<Esc>[201~
                set paste
                let b:bracketed_paste_active = 1
        else
                let b:bracketed_paste_active = 0
        endif
        return ""
    endfunction

    inoremap <special> <expr> <Esc>[201\~ XTermPasteEnd()
    function! XTermPasteEnd()
        if &paste && exists("b:bracketed_paste_active") && b:bracketed_paste_active == 1
                set nopaste
                let b:bracketed_paste_active = 0
        endif
        if exists("b:paste_inserted") && b:paste_inserted == 1
                stopinsert
                let b:paste_inserted = 0
        endif
        unlet b:paste_inserted
        unlet b:bracketed_paste_active
        return ""
    endfunction

    " Enable focus event tracking, see  :help xterm-focus-event
    let &t_fe = "\<Esc>[?1004h"
    let &t_fd = "\<Esc>[?1004l"

    " Enable modified arrow keys, see  :help xterm-modifier-keys
    execute "silent! set <xUp>=\<Esc>[@;*A"
    execute "silent! set <xDown>=\<Esc>[@;*B"
    execute "silent! set <xRight>=\<Esc>[@;*C"
    execute "silent! set <xLeft>=\<Esc>[@;*D"
endif

" Use POSIX shell syntax so $() is not hilighted red
let g:is_posix = 1

if has("gui_running")
  set guioptions-=T
endif

" focus-events might need this? c4b6afc8c7d2a03841baa5e921cc2ccffc218508
" set noautoread
set encoding=utf-8
try
  lang en_US
catch
endtry

set lazyredraw
if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j " Delete comment character when joining commented lines
endif

" set cpo+=$
set sw=2 ts=8
set et
set autoindent           " keep the previous line's indentation
set cindent              " indent after line ending in {, and use 'cinwords'
                         " see also ':help c-indent'
if exists('+colorcolumn')
  set colorcolumn=80
endif
set modeline modelines=5
set nu " Show line numbers
set listchars=tab:>\ ,trail:~,extends:>,precedes:<,nbsp:+
set ruler
set showcmd
set history=700 incsearch
" Keep some lines around scrolling
set scrolloff=7
set sidescrolloff=5
set bs=2
set laststatus=2
set wildmenu
set ff=unix
" set statusline=\ %{HasPaste()}%{SyntasticStatuslineFlag()}%<%f%h\ %m%r%=%b\ 0x%B\ \ %{fugitive#statusline()}\ \ \ \ \ \ \ %l,%c%V\ %P
set statusline=\ %{HasPaste()}%<%f%h\ %m%r%=%b\ 0x%B\ \ %{fugitive#statusline()}\ \ \ \ \ \ \ %l,%c%V\ %P
set magic
set nolazyredraw
filetype plugin indent on
" 500 ms for mapped key checking
set tm=500

set wildignore+=*.o,*.So,*.a,*.la,*.obj,*.Po,*.pyc

" Disable bells
set novisualbell noerrorbells t_vb=

" Disable previewing as it can be very slow
if version >= 700
  set completeopt-=preview
endif

" <Ctrl-l> redraws the screen and removes any search highlighting.
nnoremap <silent> <C-l> :nohl<CR><C-l>

" Save marks for 100 files, and global marks
set viminfo='100,f1,\"100,:20,n~/.viminfo
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

" Open quickfix window after :grep and :Ggrep
autocmd QuickFixCmdPost *grep* cwindow

" Define <leader>
let mapleader = ","
let g:mapleader = ","

augroup filetypedetect
au BufRead,BufNewFile *.tcl setf tcl
au BufNewFile,BufRead *.xt  setf xt
au BufRead,BufNewFile *.tpl setf smarty
au BufNewFile,BufRead svn-commit*.tmp           setf svn
augroup END


" Subversion commit file

" smarty

" au BufRead,BufNewFile *.php colorscheme ir_black

let g:miniBufExplMapWindowNavArrows = 1

let php_sql_query = 1
let php_folding = 3
let tcl_sql_active = 1
let tcl_html_active = 1

" Recommended by http://wiki.tcl.tk/4049
au BufRead,BufNewFile *.snippet setl sts=4 sw=4 ts=8 noet
au BufRead,BufNewFile vuln.xml setl sts=2 sw=2 ts=8 noet

au Filetype smarty setl sts=4 sw=4 ts=4 et
au Filetype xml setl sts=4 sw=4 ts=8 noet
au Filetype tcl setl sts=4 sw=4 ts=8 noet
au Filetype tcl setl cinkeys=0{,0},0),:,!^F,o,O,e
au Filetype php setl sts=4 sw=4 ts=4 et
au Filetype python setl sts=4 sw=4 ts=8 et
au Filetype javascript setl sts=4 sw=4 ts=4 et
au Filetype sh setl sts=8 sw=8 ts=8 noet

" Do not inadvertently break a line
set textwidth=0
" Wrap text for display only
set wrap
set lbr " Use smart wrapping

" Auto load cscope.out from current directory
" http://vim.wikia.com/wiki/Autoloading_Cscope_Database
if has("cscope") && executable("cscope")
  function! LoadCscope()
    let db = findfile("cscope.out", ".;")
    if (!empty(db))
      let path = strpart(db, 0, match(db, "/cscope.out$"))
      set nocscopeverbose " suppress 'duplicate connection' error
      exe "cs add " . db . " " . path
      set cscopeverbose
    endif
  endfunction
  au BufEnter /* call LoadCscope()
endif

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
set matchpairs+=<:>
let g:AutoClosePairs = {'(': ')', '{': '}', '[': ']', '<': '>', '"': '"', "'": "'", "/*":"*/"}
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

" delimitMate is too broken in 7.4.
" https://github.com/Raimondi/delimitMate/issues/138
" http://vim.wikia.com/wiki/Automatically_append_closing_characters
" https://groups.google.com/d/topic/vim_dev/gBumYDSEJoo/discussion
let g:loaded_delimitMate = 1

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
au Filetype tcl setl comments=:#
au Filetype tcl setl formatoptions+=r      " Automatically insert the current comment leader
au Filetype tcl setl formatoptions+=q      " Allow formatting of comments with 'gq'

" :verbose set autoindent? smartindent? cindent? cinkeys? indentexpr? indentkeys?
" Prevent the comment character from forcibly being inserted in column 1; # changing indent
au Filetype tcl setl cpoptions-=<          " allow '<keycode>' forms in mappings, e.g. <CR>
set cinkeys-=0#
set indentkeys-=0#
:inoremap # X<BS>#

" Folding
au Filetype tcl,php,ruby setl foldmethod=syntax
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
nmap <F8> :!/usr/bin/ctags -R --c++-kinds=+p --fields=+iaS --extra=+q .<CR>
nmap <leader>t :TagbarToggle<cr>
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
nmap <leader>pp :setlocal paste!<cr>

" Reload vimrc
nmap <leader>v :source ~/.vimrc<cr>

" Alternative ESC mapping in insert mode
imap jj <esc>

" map <C-w> :w!<CR>       " Map quick save

map <leader>e <esc>:NERDTreeToggle<cr>


" Reformat/indent whole file
nnoremap <leader>5 1GvG=
au FileType terraform nnoremap <leader>5 TerraformFmt

" fast saving
nmap <leader>w :w!<cr>
map <leader>q :qa!<cr>


" Disable current search
map <silent> <leader><cr> :noh<cr>

" Close the current buffer without hitting minbufexpl errors
nmap <leader>d :MBEbd<cr>
nmap <leader>bd :MBEbd<cr>
nmap <leader>bn :MBEbn<cr>
nmap <leader>bp :MBEbp<cr>
nmap <leader>bun :MBEbun<cr>
nmap <leader>bw :MBEbw<cr>
nmap <leader>bf :MBEbf<cr>

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
nmap <leader>ss :setlocal spell!<cr>

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

let g:terraform_align=1

"""""""""""""""""""""""""
" syntastic configuration
"""""""""""""""""""""""""

nmap <leader>ce :Errors<cr>
let g:syntastic_enable_signs = 1
" Auto open/close window
let g:syntastic_auto_loc_list = 0
let g:syntastic_quiet_messages = {'level': 'warnings'}
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [], 'passive_filetypes': [] }
" let g:syntastic_disabled_filetypes = ['c', 'php']
let g:syntastic_stl_format = '[%E{Err: %fe #%e}%B{, }%W{Warn: %fw #%w}]'

fun! ReadMan()
  " Assign current word under cursor to a script variable:
  let s:man_word = expand('<cword>')
  " Open a new window:
  :exe ":wincmd n"
  " Read in the manpage for man_word (col -b is for formatting):
  :exe ":r!man " . s:man_word . " | col -b"
  " Goto first line...
  :exe ":goto"
  " and delete it:
  :exe ":delete"
  :exec ":set filetype=man"
  :exec ":wincmd L"
endfun
" Map the K key to the ReadMan function:
map K :call ReadMan()<CR>

" source $VIMRUNTIME/ftplugin/man.vim
" nmap K :Man <cword><CR>

if filereadable(glob("~/.vim-freebsd")) 
  source ~/.vim/scripts/freebsd.vim
  au Filetype c,cpp call FreeBSD_Style()
  au FileType make let b:match_words = '^\.\s*\<ifn\=\(def\|make\)\=\>:^\.\s*\<elifn\=\(def\|make\)\=\>:^\.\s*\<else\>:^\.\s*\<endif\>,^\.\s*\<for\>:^\.\s*\<endfor\>'
endif

let g:ollama_enabled = 0

if filereadable(glob("~/.vimrc.site"))
    source ~/.vimrc.site
endif

if filereadable(glob("~/.vimrc.local")) 
    source ~/.vimrc.local
endif
