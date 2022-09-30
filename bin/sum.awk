#! /usr/bin/awk -f

function print_sum(group) {
	for (i = 1; i <= NF; i++) {
		if (group) {
			if (i == groupby) {
				printf group
			} else {
				printf sum_grouped[group,i]
			}
		} else {
			printf sum[i]
		}
		if (i != NF) {
			printf FS
		}
	}
	printf RS
}
{
	for (i = 1; i <= NF; i++) {
		if (groupby) {
			if (groupby == i) {
				groups[$groupby] = 1
				continue
			}
			sum_grouped[$groupby,i] += $i
		} else {
			sum[i] += $i
		}
	}
}
END {
	if (groupby) {
		for (group in groups) {
			print_sum(group)
		}
	} else {
		print_sum()
	}
}
# vim: set noet sw=8 ts=8:
