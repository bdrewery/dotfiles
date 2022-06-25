#! /usr/bin/awk -f

{
	# Fix spaces in name column
	#sizes = $(NF - 0)
	#requests = $(NF - 1)
	#memuse = $(NF - 2)
	#inuse = $(NF - 3)
	name_end = NF - 3
	name = ""
	for (i = 1; i < name_end; i++) {
		if (i == 1)
			name = $(i)
		else
			name = name FS $(i)
	}
	name_fixed = name
	gsub(/ /, "%", name_fixed)
	sub(name, name_fixed, $0)
}
{
	# Convert memuse to bytes
	memuse_k = $3
	memuse = substr(memuse_k, 1, length(memuse_k) - 1) * 1024
	$3 = memuse
}
{
	name = $1
	inuse = $2
	memuse = $3
	requests = $4
	sizes = $5

	# Trim some noise
	$4 = ""
	$5 = ""
}
NR == 1 {
	$1 = name
	$2 = sizes
	$3 = inuse
	NF = 3

	print "m-" $0, "TOTAL", "TOTAL(M)"
	next
}
$3 ~ /[0-9][0-9][0-9][0-9]+/ {
	memuse_m = memuse / 1024 / 1024
	if (memuse_m < 100) {
		next
	}
	$2 = sizes
	$3 = inuse

	print $0, memuse, sprintf("%d", memuse_m) | "sort -rnk4"
}
# vim: set noet sw=8 ts=8:
