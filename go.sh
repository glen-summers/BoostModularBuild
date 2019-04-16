#!/bin/bash

# todos
# lower case vars...
# defence against circular array references?

BOOST_VER='1.69.0'
DEP_DIR='ExternalDependencies'
BOOST_VER_UND="${BOOST_VER//./_}"
BOOST_ARCHIVE="boost-${BOOST_VER}"

WGET_OPT='--secure-protocol=auto --no-check-certificate'

Init()
{
	ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	TEMP_DIR="${ROOT}/temp"
	DOWNLOAD_DIR="${TEMP_DIR}/downloads"

	local find_dir="$( FindDirectoryAbove ${ROOT} ${DEP_DIR} )"
	if [[ -z "${find_dir}" ]]; then
		TARGET_ROOT="${TEMP_DIR}/${DEP_DIR}"
	else
		TARGET_ROOT="${find_dir}/${DEP_DIR}"
	fi
}

Main()
{
	clear
	echo "${@}"
	Init

	case "${1}" in
		"build")
			shift
			[[ "$#" -eq 1 ]] || ErrorExit "Usage: ${0} build <RootModule>"
			Build "${1}"
			;;

		"deps")
			shift
			local -a deps_mods="${@}"
			local -a deps_result
			echo "Getting dependencies to ${TEMP_DIR}/modules..."
			GetAllDeps deps_mods deps_result
			DeleteTree "${TEMP_DIR}/modules"
			echo "${#deps_result[@]} dependencies:"
			printf '%s\n' "${deps_result[@]}"
			;;

		nuke)
			shift
			[[ "$#" -eq 1 ]] || ErrorExit "Usage: ${0} nuke <RootModule>"
			Nuke "${1}"
			;;
		clean)
			Clean
			;;
		*)
			ErrorExit "Usage: ${0} {build <RootModule>|nuke <RootModule>|clean}"
	esac
}

Build()
{
	local mod="${1}"
	local BOOST_TARGET="${TARGET_ROOT}/boost_${BOOST_VER_UND}_${mod^^}"

	if [[ ! -f "${BOOST_TARGET}/successfully_installed" ]]; then
		local -a mods=("${mod}")
		local -a deps_result
		GetAllDeps mods deps_result
		echo "Building ${BOOST_TARGET} with ${#deps_result[@]} mods : ${deps_result[@]}"

		local mod
		for mod in ${deps_result[@]}
		do
			GetBoostModule "${mod}" "${BOOST_TARGET}" true
		done

		touch "${BOOST_TARGET}/successfully_installed"

		DeleteTree "${TEMP_DIR}/modules"
	fi
	du -sh "${BOOST_TARGET}" || grep '[0-9\,]\+G'
}

Clean() 
{
	DeleteTree "${TEMP_DIR}"
}

Nuke()
{
	local mod="${1}"
	local BOOST_TARGET="${TARGET_ROOT}/boost_${BOOST_VER_UND}_${mod^^}"
	DeleteTree "${BOOST_TARGET}"
}

###########################################################################

GetBoostModule()
{
	local mod="${1//-/_}"
	local MOD_DIR="$2"
	local force="$3"

	local ARCHIVE="${BOOST_ARCHIVE}.tar.gz"
	local URL="https://github.com/boostorg/${mod}/archive/${ARCHIVE}"
	local FILE="${DOWNLOAD_DIR}/${mod}-${ARCHIVE}"
	local FILTER="${mod}-boost-${BOOST_VER}/include"

	Download "${URL}" "${FILE}"

	if [[ ! -d "${MOD_DIR}" || "${force}" = true ]]; then
		ExtractTarGz "${FILE}" "${MOD_DIR}" "${FILTER}"
	fi
}

# result sill includes the input CurrentMods
# rejig loop to actually remove so is just deps
GetAllDeps()
{
	local -n CurrentMods=$1
	local -n Found=$2
	local -a WorkDeps

	while : ; do
		if [[ ${#CurrentMods[@]} -eq 0 ]]; then
			break
		fi

		GetDeps CurrentMods WorkDeps

		Found=("${Found[@]}" "${CurrentMods[@]}")
		Unique Found Found
		UniqueAndRemove WorkDeps Found CurrentMods
	done
}

GetDeps()
{
	local -n MODULES=$1
	local -n RESULT=$2

	# move these to global at top of file
	local -a EXT=('h' 'hpp' 'ipp')

	local MATCH='^[ \t]*#[ \t]*include[ \t]*<boost\/[a-zA-Z0-9\._]*[/|>].*$'
	local CLEAN='s/\/\/.*//;s/\/\*.*//;s/^[ \t]*#[ \t]*pragma.*$//' # fix for #includes in comments, etc.

	# todo generate?
	local TRANS=\
's/boost\/numeric\/conversion\//boost\/numeric_conversion\//;'\
's/boost\/numeric\/ublas\//boost\/ublas\//;'\
's/boost\/archive\//boost\/serialization\//;'\
's/boost\/functional\//boost\/container_hash\//;'\
's/boost\/detail\/([^/]+)\//boost\/\1\//;'\

	local CAPTURE='s/.*<boost\/([a-zA-Z0-9\._]*)[\/|>].*/\1/'
	local TRIM='s/\.hp?p?//;'

	# todo generate
	local FIX=\
's/^(assert|current_function)$/assert/;'\
's/^(atomic|memory_order)$/atomic/;'\
's/^(bind|is_placeholder|mem_fn)$/bind/;'\
's/^(circular_buffer|circular_buffer_fwd)$/circular_buffer/;'\
's/^(concept|concept_archetype|concept_check)$/concept_check/;'\
's/^(config|cstdint|cxx11_char_types|limits|version)$/config/;'\
's/^(contract|contract_macro)$/contract/;'\
's/^(implicit_cast|polymorphic_cast|polymorphic_pointer_cast)$/conversion/;'\
's/^(convert|make_default)$/convert/;'\
's/^(checked_delete|get_pointer|iterator|noncopyable|non_type|ref|swap|type|visit_each)$/core/;'\
's/^(blank|blank_fwd|cstdlib)$/detail/;'\
's/^(dynamic_bitset|dynamic_bitset_fwd)$/dynamic_bitset/;'\
's/exception_ptr/exception/;'\
's/^(foreach|foreach_fwd)$/foreach/;'\
's/^(function|function_equal)$/function/;'\
's/^(integer|integer_fwd|integer_traits)$/integer/;'\
's/io_fwd/io/;'\
's/^(function_output_iterator|generator_iterator|indirect_reference|iterator_adaptors|next_prior|pointee|shared_container_iterator)$/iterator/;'\
's/^(cstdfloat|math_fwd)$/math/;'\
's/^(multi_index_container|multi_index_container_fwd)$/multi_index/;'\
's/^(none|none_t|optional)$/optional/;'\
's/^(nondet_random|random)$/random/;'\
's/^(cregex|regex|regex|regex_fwd)$/regex/;'\
's/^(enable_shared_from_this|intrusive_ptr|make_shared|make_unique|pointer_cast|pointer_to_other|scoped_array|scoped_ptr|shared_array|shared_ptr|smart_ptr|weak_ptr)$/smart_ptr/;'\
's/cerrno/system/;'\
's/^(progress|timer)$/timer/;'\
's/^(tokenizer|token_functions|token_iterator)$/tokenizer/;'\
's/^(aligned_storage|type_traits)$/type_traits/;'\
's/^(unordered_map|unordered_set)$/unordered/;'\
's/^(call_traits|compressed_pair|operators|operators_v1|utility)$/utility/;'\
's/cast/numeric_conversion/;'

	#$KnownLibs, calc from master project dir minus non modules

	local INCLUDE
	printf -v INCLUDE -- '--include=*.%s ' "${EXT[@]}"

	Unique MODULES MODULES

	for MODULE in ${MODULES[@]}
	do
		local target="${TEMP_DIR}/modules/${MODULE}"
		GetBoostModule "${MODULE}" "${target}" false
		pushd "${target}/boost"  >/dev/null || ErrorExit

		# $(MATCH) - find all lines with '#include <boost/'
		# ${CLEAN} - remove comments to avoid erroneous matches
		# $(TRANS) - translate known module locations
		# ${CAPTURE} - extract boost module name
		# ${TRIM} - remove file extensions
		# $(FIX) - get module from a top level boost file names

		local IGNORE="^(${MODULE}|pending|numeric)$"

		local RawDeps=$(IFS='\n' grep -E -r -h --include='*.hpp' --include='*.h' --include='*.ipp' "${MATCH}" \
			| sed -E "${CLEAN};${TRANS};${CAPTURE}" \
			| sort | uniq \
			| sed -E "${TRIM};${FIX}" \
			| sort | uniq \
			| grep -Ev "${IGNORE}" )

		local -a TmpDeps
		readarray -t TmpDeps <<<"${RawDeps}";

		RESULT=("${RESULT[@]}" "${TmpDeps[@]}")
		Unique RESULT RESULT
		popd > /dev/null
	done
}

###########################################################################

ErrorExit()
{
	echo "${1}" 1>&2
	exit 1
}

Unique()
{
	local -n values=$1
	local -n uniqueResult=$2
	uniqueResult=($(echo "${values[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

UniqueAndRemove()
{
	local -n values=$1
	local -n remove=$2
	local -n result=$3
	# add remove twice to force remove if not in values, better solution?
	result=($(echo "${values[@]}" "${remove[@]}" "${remove[@]}" | tr ' ' '\n' | sort | uniq -u))
}

FindDirectoryAbove()
{
	local path="${1}"
	while [[ "${path}" != "" && ! -d "${path}/${2}" ]]; do
		path="${path%/*}"
	done
	echo "${path}"
}

Download() 
{
	local URL="${1}"
	local FILENAME="${2}"

	if [[ ! -s "${FILENAME}" ]]; then
		echo "downloading ${URL} -> ${FILENAME}"
		mkdir -p "$(dirname "${FILENAME}")" || ErrorExit "mkdir failed"
		wget "${URL}" -O "${FILENAME}" ${WGET_OPT} || ErrorExit "wget failed"
	fi
}

ExtractTarGz()
{
	# strip parm?
	local ARCHIVE="${1}"
	local DIR="${2}"
	local FILTER="${3}"

	echo "Extracting ${ARCHIVE} -> ${DIR}"
	mkdir -p "${DIR}" || ErrorExit "mkdir failed"
	tar xzf "${ARCHIVE}" -C "${DIR}" --strip 2 "${FILTER}" || ErrorExit "tar failed"
}

DeleteTree() 
{
	local dir="${1}"
	if [[ -d "${dir}" ]]; then
		echo "deleting ${dir}..."
		local n=0
		until [ ${n} -ge 10 ]
		do
			rm -frd "${dir}" && return
			n=$[${n}+1]
			sleep 1
		done
		ErrorExit "failed to delete, retries exceeded"
	fi
}

###########################################################################

Main "${@}"