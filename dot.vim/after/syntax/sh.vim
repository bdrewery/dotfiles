" https://vi.stackexchange.com/questions/9387/how-do-i-enable-language-specific-syntax-inside-a-heredoc
" safe b:current_syntax to restore it afterwards
" Value could be 'sh', 'posix', 'ksh' or 'bash'
let s:cs_safe = b:current_syntax

" unlet b:current_syntax, so sql.vim will load
unlet b:current_syntax
syntax include @SQL syntax/sql.vim

" restore saved syntax
let b:current_syntax = s:cs_safe

syn region shHereDoc matchgroup=shHereDocSql start=+<<-\=\s*['"\\]\=\z(SQLDOC\)+ matchgroup=shHereDocSql end="^[[:space:]]\z1\s*$"   contains=@SQL
hi def link shHereDocSql        shRedir
