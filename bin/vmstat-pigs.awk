#! /usr/bin/awk -f

NR == 1 {
	sub(/FAILSLEEP/, "FAIL SLEEP", $0)
	print $0, "TOTAL", "TOTAL(M)"
}
$4 ~ /[0-9][0-9][0-9]+/ {
	total = $2 * $4
	total_m = total / 1024 / 1024
	gsub(/,/, ", ", $0)
	if (total_m < 100) {
		next
	}
	print $0, total, sprintf("%d", total_m) | "sort -rnk10"
}
# vim: set noet sw=8 ts=8:
