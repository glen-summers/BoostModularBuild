#!/bin/bash

# lower case vars...
BOOST_VER='1.69.0'
DEP_DIR='ExternalDependencies'
BOOST_VER_UND="${BOOST_VER//./_}"
BOOST_ARCHIVE="boost-${BOOST_VER}"

WGET_OPT='--secure-protocol=auto --no-check-certificate'

MODULES1="test"
MODULES2="algorithm assert bind compatibility config core detail exception function io iterator mpl numeric_conversion optional preprocessor smart_ptr static_assert timer type_traits utility"
MODULES3="type_index container_hash throw_exception predef integer move range"
MODULES="${MODULES1} ${MODULES2} ${MODULES3}"

Init()
{
	ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	TEMP_DIR="${ROOT}/temp"
	DOWNLOAD_DIR="${TEMP_DIR}/downloads"

	local TARGET_ROOT="$( FindDirectoryAbove ${ROOT} ${DEP_DIR} )"
	if [[ -z "${TARGET_ROOT}" ]]; then
		BOOST_TARGET="${TEMP_DIR}"
	else
		# param for target name?
		BOOST_TARGET="${TARGET_ROOT}/${DEP_DIR}/boost_${BOOST_VER_UND}_TEST"
	fi
}

Main()
{
	clear
	echo "${@}"
	Init

	case "${1}" in
		"")
			;&
		"build")
			Build
			;;
		nuke)
			Nuke
			;;
		clean)
			Clean
			;;
		*)
			ErrorExit "Usage: ${0} {build*|clean|nuke}"
	esac
}

Build()
{
	echo "BOOST_TARGET = ${BOOST_TARGET}"
	if [[ ! -f "${BOOST_TARGET}/successfully_installed" ]]; then

		local mod
		for mod in ${MODULES}
		do
			GetBoostModule "${mod}" "${BOOST_TARGET}" true
		done

		touch "${BOOST_TARGET}/successfully_installed"
	fi
}

Clean() 
{
	DeleteTree "${TEMP_DIR}"
}

Nuke()
{
	DeleteTree "${BOOST_TARGET}"
}

###########################################################################

ErrorExit()
{
	echo "${1}" 1>&2
	exit 1
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

###########################################################################

Main "${@}"