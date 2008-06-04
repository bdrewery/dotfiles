" Better indent support for Smarty by making it possible to indent HTML sections
" as well.
if exists("b:did_indent")
  finish
endif

runtime! indent/html.vim
