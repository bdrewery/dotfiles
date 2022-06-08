#! /usr/bin/awk -f
{
  sum += $1
}
END {
  print sum
}
# vim: set noet sw=8 ts=8:
