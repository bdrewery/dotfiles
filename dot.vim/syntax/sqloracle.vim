" Vim syntax file
" Language:	SQL, PL/SQL (Oracle 8i/9i)
" Maintainer:	Paul Moore <gustav@morpheus.demon.co.uk>
" Modified By:  David Kalosi <david.kalosi@spordat.sk>
" Last Change:	2004 Feb 10
" Added the missing 9i builtin functions and SQL keywords 

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" The SQL reserved words, defined as keywords.

syn keyword sqlSpecial  false null true

syn keyword sqlKeyword	access add as asc begin by check cluster column
syn keyword sqlKeyword	compress connect current cursor decimal default desc
syn keyword sqlKeyword	else elsif end exception exclusive file for from
syn keyword sqlKeyword	function group having identified if immediate increment
syn keyword sqlKeyword	index initial into is level loop maxextents mode modify
syn keyword sqlKeyword	nocompress nowait of offline on online start
syn keyword sqlKeyword	successful synonym table then to trigger uid
syn keyword sqlKeyword	unique user validate values view whenever
syn keyword sqlKeyword	where with option order pctfree privileges procedure
syn keyword sqlKeyword	public resource return row rowlabel rownum rows
syn keyword sqlKeyword	session share size smallint type using

" added by DAVID, oracle extenstions

syn keyword sqlKeyword  package body replace subtype record constant
syn keyword sqlKeyword  raise when directory forall bulk collect limit
syn keyword sqlKeyword  systimestamp operator outline 
syn keyword sqlKeyword  database dimenstion indextype java materialized log
syn keyword sqlKeyword  profile resource cost role rollback segment sequence
syn keyword sqlKeyword  system tablespace 

syn keyword sqlOperator	not and or
syn keyword sqlOperator	in any some all between exists
syn keyword sqlOperator	like escape
syn keyword sqlOperator union intersect minus
syn keyword sqlOperator prior distinct
syn keyword sqlOperator	sysdate out

syn keyword sqlStatement alter analyze audit comment commit create
syn keyword sqlStatement delete drop execute explain grant insert lock noaudit
syn keyword sqlStatement rename revoke rollback savepoint select set
syn keyword sqlStatement truncate update

syn keyword sqlType	boolean char character date float integer long
syn keyword sqlType	mlslabel number raw rowid varchar varchar2 varray
syn keyword sqlType     blob clob bfile xmltype anytype

" Strings and characters:
syn region sqlString		start=+"+  skip=+\\\\\|\\"+  end=+"+
syn region sqlString		start=+'+  skip=+\\\\\|\\'+  end=+'+

" Numbers:
syn match sqlNumber		"-\=\<\d*\.\=[0-9_]\>"

" Comments:
syn region sqlComment    start="/\*"  end="\*/" contains=sqlTodo
syn match sqlComment	"--.*$" contains=sqlTodo

syn sync ccomment sqlComment

" Todo.
syn keyword sqlTodo TODO FIXME XXX DEBUG NOTE

" Oracle functions

syn keyword sqlFunction abs acos add_months ascii asciistr asi atan atan2
syn keyword sqlFunction avg bfilename bin_to_num bitand cast ceil 
syn keyword sqlFunction chartorowid chr coalesce count 
syn keyword sqlFunction compose convert corr cos cosh covar_pop covar_samp
syn keyword sqlFunction cume_dist current_date current_timestamp 
syn keyword sqlFunction dbtimezone decode decompose dense_rank
syn keyword sqlFunction depth deref dump empty_clob empty_blob
syn keyword sqlFunction existsnode exp extract extractvalue first 
syn keyword sqlFunction efirst_value floor from_tz greatest group_id
syn keyword sqlFunction grouping grouping_id hextoraw initcap instr
syn keyword sqlFunction lag last last_day last_value lead least 
syn keyword sqlFunction length ln localtimestamp log lower lpad 
syn keyword sqlFunction ltrim make_ref max min mod months_between nchr new_time
syn keyword sqlFunction next_dat nls_charset_decl_len 
syn keyword sqlFunction nls_charset_id nls_charset_name nls_initcap 
syn keyword sqlFunction nls_lower nlssort ntile nullif numtodsinterval
syn keyword sqlFunction numtoyminterval nvl nvl2 path percent_rank 
syn keyword sqlFunction percentile_cont percentile_disc 
syn keyword sqlFunction power rank ratio_to_report rawtohex ref reftohex
syn keyword sqlFunction regr replace round row_number rowidtochar rowidtonchar
syn keyword sqlFunction rpad rtrim sessiontimezone sign sin sinh 
syn keyword sqlFunction soundex sqrt stddev stddev_pop 
syn keyword sqlFunction stddev_samp substr sum sys_connect_by_path sys_context
syn keyword sqlFunction sys_dburigen sys_extract_utc sys_guid 
syn keyword sqlFunction sys_typeid sys_xmlagg sys_xmlgen sysdate 
syn keyword sqlFunction systimestamp tan tanh to_char to_clob to_date
syn keyword sqlFunction to_dsinterval to_lob to_multi_byte to_nchar 
syn keyword sqlFunction to_nclob to_number to_single_byte 
syn keyword sqlFunction to_timestamp to_timestamp_tz to yminterval 
syn keyword sqlFunction translate treat trim trunc tz_offset uid 
syn keyword sqlFunction unistr updatexml upper userenv value 
syn keyword sqlFunction var_pop var_samp variance vsize width_bucket 
syn keyword sqlFunction xmlagg xmlcolattval xmlconcat xmlelement 
syn keyword sqlFunction xmlforest xmlsequence xmlstransform

" Define the default highlighting. 
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sql_syn_inits")
  if version < 508
    let did_sql_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink sqlComment	Comment
  HiLink sqlKeyword	sqlSpecial
  HiLink sqlNumber	Number
  HiLink sqlOperator	sqlStatement
  HiLink sqlSpecial	Special
  HiLink sqlStatement	Statement
  HiLink sqlString	String
  HiLink sqlType	Type
  HiLink sqlTodo	Todo
  HiLink sqlFunction    Statement

  delcommand HiLink
endif

let b:current_syntax = "sql"

" vim: ts=8
