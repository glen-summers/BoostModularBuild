#!/bin/bash

dep_dir='ExternalDependencies'
wget_opt='--secure-protocol=auto --no-check-certificate --quiet'

Init()
{
	root=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	source "${root}/versions.config" || ErrorExit "versions"

	temp_dir="${root}/temp"
	download_dir="${temp_dir}/downloads"
	temp_modules="${temp_dir}/modules"

	local find_dir="$( FindDirectoryAbove ${root} ${dep_dir} )"
	if [[ -z "${find_dir}" ]]; then
		target_root="${temp_dir}/${dep_dir}"
	else
		target_root="${find_dir}/${dep_dir}"
	fi
	boost_ver_und="${boost_ver//./_}"
	boost_archive="boost-${boost_ver}.tar.gz"
}

Main()
{
	clear
	echo "${@}"
	Init

	case "${1}" in
		build)
			shift
			[[ "$#" -eq 1 ]] || ErrorExit "Usage: ${0} build <RootModule>"
			Build "${1}"
			;;
		deps)
			shift
			local -a deps_mods="${@}"
			local -a deps_result
			GetAllDeps deps_mods deps_result
			echo "${#deps_result[@]} dependencies:"
			printf '%s\n' "${deps_result[@]}"
			;;
		gen)
			local result
			Generate

			echo
			echo "# generated fix"
			echo "local fix=\\"
			echo "${result}"
			echo "# generated fix"
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
			ErrorExit "Usage: ${0} build <RootModule>|deps <RootModule>|clean|nuke|gen
    build <mod>    Generates an include directory with all <mod>'s dependencies
    deps <mod>     Displays all dependencies of <mod>
    clean          remove temp files
    nuke <mod>     remove the built target
    gen            generate module file lookup code"
	esac
}

Build()
{
	local mod="${1}"
	local boost_target="${target_root}/boost_${boost_ver_und}_${mod}"

	if [[ ! -f "${boost_target}/successfully_installed" ]]; then
		local -a mods=("${mod}")
		local -a deps_result
		GetAllDeps mods deps_result
		echo "Building ${boost_target} with ${#deps_result[@]} mods : ${deps_result[@]}"

		local mod
		for mod in ${deps_result[@]}
		do
			GetBoostModule "${mod}" "${boost_target}" true
		done

		touch "${boost_target}/successfully_installed"

		DeleteTree "${temp_modules}"
	fi
	du -sh "${boost_target}" || grep '[0-9\,]\+G'
}

Generate()
{
	local mod_dir="${temp_modules}/boost/"
	local url="https://github.com/boostorg/boost/archive/${boost_archive}"
	local file="${download_dir}/boost-${boost_archive}"
	local filter="boost-boost-${boost_ver}/libs"

	Download "${url}" "${file}"

	if [[ ! -d "${mod_dir}" ]]; then
		ExtractTarGz "${file}" "${mod_dir}" "${filter}"
	fi

	# avoid push?
	pushd "${mod_dir}" >/dev/null || ErrorExit
	local -a mods=(*/)
	popd >/dev/null
	mods=("${mods[@]%?}")

	# numeric: -> numeric_conversion interval odeint ublas
	local -a del=("numeric")
	local -a add=("numeric_conversion interval odeint ublas")
	mods=(${mods[@]} ${add[@]})
	UniqueAndRemove mods del mods

	local dir
	for dir in ${mods[@]}
	do
		GetBoostModule "${dir}" "${temp_modules}/${dir}" false

		local -a files
		GetHeadersWithNullGlob "${temp_modules}/${dir}/boost" files

		files=("${files[@]%\.*}")
		local -a tmp=(${dir})
		UniqueAndRemove files tmp files

		if [[ ${#files[@]} -eq 1 && "${files[0]}" != "${dir}" ]]; then
			result+="'s/^${files[0]}$/${dir}/;'\\"$'\n'
		elif [[ ${#files[@]} -ge 2 ]]; then
			result+=$(IFS=\| ; echo "'s/^(${files[*]})$/${dir}/;'\\")$'\n'
		fi
	done
}

Clean()
{
	DeleteTree "${temp_dir}"
}

Nuke()
{
	local mod="${1}"
	local boost_target="${target_root}/boost_${boost_ver_und}_${mod}"
	DeleteTree "${boost_target}"
}

###########################################################################

GetBoostModule()
{
	local mod="${1//-/_}"
	local mod_dir="$2"
	local force="$3"

	local url="https://github.com/boostorg/${mod}/archive/${boost_archive}"
	local file="${download_dir}/${mod}-${boost_archive}"
	local filter="${mod}-boost-${boost_ver}/include"

	Download "${url}" "${file}"

	if [[ ! -d "${mod_dir}" || "${force}" = true ]]; then
		ExtractTarGz "${file}" "${mod_dir}" "${filter}"
	fi
}

# result sill includes the input current_mods
# rejig loop to actually remove so is just deps
GetAllDeps()
{
	local -n current_mods=$1
	local -n found=$2
	local -a work_deps

	while : ; do
		if [[ ${#current_mods[@]} -eq 0 ]]; then
			break
		fi

		GetDeps current_mods work_deps

		found=("${found[@]}" "${current_mods[@]}")
		Unique found found
		UniqueAndRemove work_deps found current_mods
	done
}

GetDeps()
{
	local -n modules=$1
	local -n result=$2

	# move these to global at top of file
	local -a ext=('h' 'hpp' 'ipp')

	local match='^[ \t]*#[ \t]*include[ \t]*<boost\/[a-zA-Z0-9\._]*[/|>].*$'
	local clean='s/\/\/.*//;s/\/\*.*//;s/^[ \t]*#[ \t]*pragma.*$//' # fix for #includes in comments, etc.

	# todo generate?
	local trans=\
's/boost\/numeric\/conversion\//boost\/numeric_conversion\//;'\
's/boost\/numeric\/ublas\//boost\/ublas\//;'\
's/boost\/archive\//boost\/serialization\//;'\
's/boost\/functional\//boost\/container_hash\//;'\
's/boost\/concept\//boost\/concept_check\//;'\
's/boost\/detail\/([^/]+)\//boost\/\1\//;'\

	local capture='s/.*<boost\/([a-zA-Z0-9\._]*)[\/|>].*/\1/'
	local trim='s/\.hp?p?//;'

# generated fix
local fix=\
's/^current_function$/assert/;'\
's/^memory_order$/atomic/;'\
's/^(is_placeholder|mem_fn)$/bind/;'\
's/^circular_buffer_fwd$/circular_buffer/;'\
's/^concept_archetype$/concept_check/;'\
's/^(cstdint|cxx11_char_types|limits|version)$/config/;'\
's/^contract_macro$/contract/;'\
's/^(implicit_cast|polymorphic_cast|polymorphic_pointer_cast)$/conversion/;'\
's/^make_default$/convert/;'\
's/^(checked_delete|get_pointer|iterator|noncopyable|non_type|ref|swap|type|visit_each)$/core/;'\
's/^(blank|blank_fwd|cstdlib)$/detail/;'\
's/^dynamic_bitset_fwd$/dynamic_bitset/;'\
's/^exception_ptr$/exception/;'\
's/^foreach_fwd$/foreach/;'\
's/^function_equal$/function/;'\
's/^(integer_fwd|integer_traits)$/integer/;'\
's/^io_fwd$/io/;'\
's/^(function_output_iterator|generator_iterator|indirect_reference|iterator_adaptors|next_prior|pointee|shared_container_iterator)$/iterator/;'\
's/^(cstdfloat|math_fwd)$/math/;'\
's/^(multi_index_container|multi_index_container_fwd)$/multi_index/;'\
's/^cast$/numeric_conversion/;'\
's/^(none|none_t)$/optional/;'\
's/^nondet_random$/random/;'\
's/^(cregex|regex_fwd)$/regex/;'\
's/^(enable_shared_from_this|intrusive_ptr|make_shared|make_unique|pointer_cast|pointer_to_other|scoped_array|scoped_ptr|shared_array|shared_ptr|weak_ptr)$/smart_ptr/;'\
's/^cerrno$/system/;'\
's/^progress$/timer/;'\
's/^(token_functions|token_iterator)$/tokenizer/;'\
's/^aligned_storage$/type_traits/;'\
's/^(unordered_map|unordered_set)$/unordered/;'\
's/^(call_traits|compressed_pair|operators|operators_v1)$/utility/;'
# generated fix

	#$KnownLibs, calc from master project dir minus non modules

	local include
	printf -v include -- '--include=*.%s ' "${ext[@]}"

	Unique modules modules

	for module in ${modules[@]}
	do
		local target="${temp_modules}/${module}"
		GetBoostModule "${module}" "${target}" false
		pushd "${target}/boost"  >/dev/null || ErrorExit

		# $(match) - find all lines with '#include <boost/'
		# ${clean} - remove comments to avoid erroneous matches
		# $(trans) - translate known module locations
		# ${capture} - extract boost module name
		# ${trim} - remove file extensions
		# $(fix) - get module from a top level boost file names

		local ignore="^(${module}|pending|numeric)$"

		local raw_deps=$(IFS='\n' grep -E -r -h --include='*.hpp' --include='*.h' --include='*.ipp' "${match}" \
			| sed -E "${clean};${trans};${capture}" \
			| sort | uniq \
			| sed -E "${trim};${fix}" \
			| sort | uniq \
			| grep -Ev "${ignore}" )

		local -a tmp_deps
		readarray -t tmp_deps <<<"${raw_deps}";

		result=("${result[@]}" "${tmp_deps[@]}")
		Unique result result
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
	local -n unique_result=$2
	unique_result=($(echo "${values[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

UniqueAndRemove()
{
	local -n values=$1
	local -n remove=$2
	local -n result=$3
	# add remove twice to force remove if not in values, better solution?
	result=($(echo "${values[@]}" "${remove[@]}" "${remove[@]}" | tr ' ' '\n' | sort | uniq -u))
}

GetHeadersWithNullGlob()
{
	pushd "$1" >/dev/null || ErrorExit
	local -n values=$2
	local old=$(shopt -p nullglob)
	shopt -s nullglob
	values=(*.{h,hpp})
	eval "${old}"
	popd >/dev/null
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
	local url="${1}"
	local filename="${2}"

	if [[ ! -s "${filename}" ]]; then
		echo "downloading ${url} -> ${filename}"
		mkdir -p "$(dirname "${filename}")" || ErrorExit "mkdir failed"
		wget "${url}" -O "${filename}" ${wget_opt} || ErrorExit "wget failed"
	fi
}

ExtractTarGz()
{
	# strip parm?
	local archive="${1}"
	local dir="${2}"
	local filter="${3}"

	echo "Extracting ${archive} -> ${dir}"
	mkdir -p "${dir}" || ErrorExit "mkdir failed"
	tar xzf "${archive}" -C "${dir}" --strip 2 "${filter}" || ErrorExit "tar failed"
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