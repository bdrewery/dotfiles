#! /usr/bin/awk -f
{
	for (i = 1; i <= NF; i++) {
		sum[i] += $i
	}
}
END {
	for (i = 1; i <= NF; i++) {
		printf sum[i]
		if (i != NF) {
			printf FS
		}
	}
	printf RS
}
# vim: set noet sw=8 ts=8:
