#! /usr/bin/awk -f
{
	# Some names have spaces
	colon = index($0, ":")
	bucket = substr($0, 1, colon)
	gsub(/ /, "%", bucket)
	$0 = bucket substr($0, colon + 1)
	# Some values lack spaces after ','
	gsub(/,/, ", ", $0)
	gsub(/,/, "", $0)
	sub(/FAILSLEEP/, "FAIL SLEEP", $0)
}
{
	name = $1
	size = $2
	limit = $3
	used = $4
	free = $5
	req = $6
	fail = $7
	sleep = $8
	xdomain = $9
	# Trim some noise
	$3 = ""
	$5 = ""
	$6 = ""
	$7 = ""
	$8 = ""
	$9 = ""
}
NR == 1 {
	$1 = name
	$2 = size
	$3 = used
	NF = 3
	print "z-" $0, "TOTAL", "TOTAL(M)"
	next
}
$4 ~ /[0-9][0-9][0-9]+/ {
	memuse = size * used
	memuse_m = memuse / 1024 / 1024
	if (memuse_m < 100) {
		next
	}

	print $0, memuse, sprintf("%d", memuse_m) | "sort -rnk4"
}
# vim: set noet sw=8 ts=8:
