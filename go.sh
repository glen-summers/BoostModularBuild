#!/bin/bash

BOOST_VER=1.68.0

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
	local URL=${1}
	local CONTEXT=`dirname "${2}"`
	local ARCHIVE=`basename "${2}"`

	echo ${CONTEXT}
	echo ${ARCHIVE}

	local CACHED="${TEMP_DIR}/${CONTEXT}/${ARCHIVE}"

	if [[ ! -f "${CACHED}" ]]; then
		echo wget "${URL}/${ARCHIVE}" -P "${TEMP_DIR}/${CONTEXT}" ${WGET_OPT}
		wget "${URL}/${ARCHIVE}" -P "${TEMP_DIR}/${CONTEXT}" ${WGET_OPT} || ErrorExit "wget failed"
	else
		echo "${CACHED} present"
	fi
}

GetTarGz()
{
	local URL=${1}
	local ARCHIVE=${2}
	local DIR=${3}

	Download "${URL}" "${ARCHIVE}"
	echo tar xzf "${TEMP_DIR}/${ARCHIVE}" -C "${DIR}" || ErrorExit "tar failed"
	mkdir -p "${DIR}" || ErrorExit "mkdir failed"
	tar xzf "${TEMP_DIR}/${ARCHIVE}" -C "${DIR}" --strip 1 || ErrorExit "tar failed"
}

GetBoostModules()
 {
	local dir="$1"
	local mod
	for mod in "${@:2}"
	do
		local module="${mod//-/_}"
		local ARCHIVE="${module}/boost-${BOOST_VER}.tar.gz"
		local URL="https://github.com/boostorg/${module}/archive"
		GetTarGz "${URL}" "${ARCHIVE}" "${dir}"
	done
	#GetTarGz2 "${URL}" "${ARCHIVE}" "${dir}"
	#https://github.com/boostorg/test/archive/boost-1.68.0.tar.gz
	#https://github.com/boostorg/test/archive/test/boost-1.68.0.tar.gz
}


###########################################################################

Init()
{
	ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

	TEMP_DIR="${ROOT}/temp"

	local ABOVE="$( FindDirectoryAbove ${ROOT} ${DEP_DIR} )"
	if [[ -z "${ABOVE}" ]]; then
		TARGET_DIR="${TEMP_DIR}"
	else
		TARGET_DIR="${ABOVE}/${DEP_DIR}"
	fi
	echo "TARGET_DIR = ${TARGET_DIR}"

	local BOOST_VER_UND="boost_${BOOST_VER//./_}"
	BOOST_ARCHIVE="${BOOST_VER_UND}.7z"
	BOOST_TARGET="${TARGET_DIR}/${BOOST_VER_UND}"

	echo "BOOST_TARGET = ${BOOST_TARGET}"
}

Build
{}

Nuke{}

Clean
{}

###########################################################################

clear
Init

echo "go ${1}..."
case "${1}" in
	"")
		;&
	"build")
		Build
		;;
	nuke)
		Nuke
		;&
	clean)
		Clean
		;;
	*)
		ErrorExit "Usage: ${0} {build*|rebuild|clean|nuke}"
esac
