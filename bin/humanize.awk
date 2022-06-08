#! /usr/bin/awk -f
# Copyright (c) 2012-2017 Bryan Drewery <bdrewery@FreeBSD.org>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

BEGIN {
	conv["B"] = 1024**0
	conv["KiB"] = 1024**1
	conv["MiB"] = 1024**2
	conv["GiB"] = 1024**3
	conv["TiB"] = 1024**4
	conv["PiB"] = 1024**5
	conv["EiB"] = 1024**6
	conv["ZiB"] = 1024**7
	conv["YiB"] = 1024**8

	conv_max = 0
	for (unit in conv) {
		if (conv[unit] > conv_max) {
			conv_max = conv[unit]
			conv_max_unit = unit
		}
	}
}

# Humanize the output of a size, ie, 1048576 -> 1MiB
function humanize(number) {
	for (unit in conv) {
		hum[conv[unit]] = unit
	}
	for (x = conv[conv_max_unit]; x >= 1024; x /= 1024) {
		if (number >= x) {
                        break
		}
	}
	return sprintf("%.2f %s", number/x, hum[x])
}
function getbsize() {
	if (!ENVIRON["BLOCKSIZE"]) {
		return 1
	}
	blocksize_env = ENVIRON["BLOCKSIZE"] ? ENVIRON["BLOCKSIZE"] : "512"
	if (blocksize_env ~ /[0-9]+/) {
		n = blocksize_env
	} else {
		n = 1
	}
	if (blocksize_env == "G" || blocksize_env == "g") {
		form = "G"
		max = conv_max / conv["GiB"]
		mul = conv["GiB"]
	} else if (blocksize_env == "K" || blocksize_env == "k") {
		form = "K"
		max = conv_max / conv["KiB"]
		mul = conv["KiB"]
	} else if (blocksize_env == "M" || blocksize_env == "m") {
		form = "M"
		max = conv_max / conv["MiB"]
		mul = conv["MiB"]
	} else if (n == blocksize_env ||
	    blocksize_env == "B" || blocksize_env == "b") {
		form = "B"
		max = conv_max
		mul = 1
	} else {
		printf("%s: unknown blocksize\n", blocksize_env) > "/dev/stderr"
		n = 512
		max = conv_max
		mul = 1
	}
	if (n > max) {
		printf("maximum blocksize is %ld%s\n", conv_max / conv["GiB"],
		    conv_max_unit) > "/dev/stderr"
		n = max
	}
	blocksize = n * mul
	if (blocksize < 512) {
		printf("minimum blocksize is 512\n") > "/dev/stderr"
		form = "B"
		n = 512
		blocksize = n
	}
	return blocksize
}
{
	blocksize = getbsize()
	print humanize($1 * blocksize)
}
# vim: set noet sw=8 ts=8:
