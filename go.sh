#!/bin/bash

BOOST_VER=1.68.0
DEP_DIR=ExternalDependencies
BOOST_VER_UND="boost_${BOOST_VER//./_}"
WGET_OPT=--secure-protocol=auto --no-check-certificate
MODULES="test algorithm"

#test
#algorithm;assert;bind;build;compatibility;config;core;detail;exception;function;io;iterator;mpl;numeric_conversion;optional;preprocessor;smart_ptr;static_assert;timer;type_traits;utility
#type_index;container_hash;throw_exception;predef;integer;move;range

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

	if [[ ! -f "${FILENAME}" ]]; then
		wget "${URL}" -O "${FILENAME}" ${WGET_OPT} || ErrorExit "wget failed"
	else
		echo "${FILENAME} present"
	fi
}

ExtractTarGz()
{
	local ARCHIVE=${1}
	local DIR=${2}
	local FILTER=${3}

	mkdir -p "${DIR}" || ErrorExit "mkdir failed"
	tar xzf "${ARCHIVE}" -C "${DIR}" --strip 1 "${FILTER}" || ErrorExit "tar failed"
}

DeleteTree() {
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

GetBoostModules()
{
	local mod
	for mod in "${@:1}"
	do
		local MODULE="${mod//-/_}"
		local ARCHIVE="boost-${BOOST_VER}.tar.gz"
		local URL="https://github.com/boostorg/${MODULE}/archive/${ARCHIVE}"
		local FILE="${DOWNLOAD_DIR}/${MODULE}-${ARCHIVE}"
		local FILTER="${MODULE}-boost-${BOOST_VER}/include"
		Download "${URL}" "${FILE}"
		ExtractTarGz "${FILE}" "${BOOST_TARGET}" "${FILTER}"
	done
}

###########################################################################

Init() 
{
	ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	TEMP_DIR="${ROOT}/temp"
	DOWNLOAD_DIR="${TEMP_DIR}/downloads"

	local TARGET_ROOT="$( FindDirectoryAbove ${ROOT} ${DEP_DIR} )"
	if [[ -z "${TARGET_ROOT}" ]]; then
		BOOST_TARGET="${TEMP_DIR}"
	else
		BOOST_TARGET="${TARGET_ROOT}/${DEP_DIR}/${BOOST_VER_UND}_TEST"
	fi

	echo "BOOST_TARGET = ${BOOST_TARGET}"
	echo "DOWNLOAD_DIR = ${DOWNLOAD_DIR}"
}

Build()
{
	mkdir -p "${DOWNLOAD_DIR}"
	GetBoostModules ${MODULES}
}

Clean() {
	DeleteTree "${TEMP_DIR}"
}

Nuke()
{
	DeleteTree "${BOOST_TARGET}"
}

###########################################################################

clear
echo "go $1..."
Init

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
		ErrorExit "Usage: ${0} {build*|clean|nuke}"
esac
