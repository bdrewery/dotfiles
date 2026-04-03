# libexec/local.sh - Source .local file and .local.d directory for a given path
source_local() {
	local _base="$1"
	if [ -r "${_base}.local" ]; then
		. "${_base}.local"
	fi
	if [ -d "${_base}.local.d" ]; then
		local LC_ALL
		LC_ALL=C
		local _f
		for _f in "${_base}.local.d"/*; do
			case "${_f}" in
			"${_base}.local.d/*") break ;;
			esac
			[ -r "${_f}" ] || continue
			. "${_f}"
		done
	fi
}
