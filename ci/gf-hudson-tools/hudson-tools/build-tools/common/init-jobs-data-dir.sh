#!/bin/bash -e
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
# Copyright (c) 2018 Oracle and/or its affiliates. All rights reserved.
#
# The contents of this file are subject to the terms of either the GNU
# General Public License Version 2 only ("GPL") or the Common Development
# and Distribution License("CDDL") (collectively, the "License").  You
# may not use this file except in compliance with the License.  You can
# obtain a copy of the License at
# https://oss.oracle.com/licenses/CDDL+GPL-1.1
# or LICENSE.txt.  See the License for the specific
# language governing permissions and limitations under the License.
#
# When distributing the software, include this License Header Notice in each
# file and include the License file at LICENSE.txt.
#
# GPL Classpath Exception:
# Oracle designates this particular file as subject to the "Classpath"
# exception as provided by Oracle in the GPL Version 2 section of the License
# file that accompanied this code.
#
# Modifications:
# If applicable, add the following below the License Header, with the fields
# enclosed by brackets [] replaced by your own identifying information:
# "Portions Copyright [year] [name of copyright owner]"
#
# Contributor(s):
# If you wish your version of this file to be governed by only the CDDL or
# only the GPL Version 2, indicate your decision by adding "[Contributor]
# elects to include this software in this distribution under the [CDDL or GPL
# Version 2] license."  If you don't indicate a single choice of license, a
# recipient has the option to distribute your version of this file under
# either the CDDL, the GPL Version 2 or to extend the choice of license to
# its licensees as provided above.  However, if you add GPL Version 2 code
# and therefore, elected the GPL Version 2 license, then the option applies
# only if the new code is made subject to such option by the copyright
# holder.
#

if [ -z "${JOB_NAME}" ] ; then
  printf "\n\n ${0} - Error, JOB_NAME environment variable is not defined.\n\n"
  exit 1
fi

if [ -z "${BUILD_NUMBER}" ] ; then
  printf "\n\n ${0} - Error, BUILD_NUMBER environment variable is not defined.\n\n"
  exit 1
fi

if [ -z "${HUDSON_URL}" ] ; then
  printf "\n\n ${0} - Error, HUDSON_URL environment variable is not defined.\n\n"
  exit 1
fi

if [ -z "${HUDSON_MASTER_HOST}" ] ; then
  printf "\n\n ${0} - Error, HUDSON_MASTER_HOST environment variable is not defined.\n\n"
  exit 1
fi

PATH=/gf-hudson-tools/bin:${PATH}

#
# platform specifics
#
if [ `uname | grep -i "windows" | wc -l | awk '{print $1}'` -eq 1 ] ; then
  DEVNULL=nul
  GREP="grep"
  AWK="awk"
  SED="sed"
  export PATH=/mksnt/mksnt:$PATH
else
  DEVNULL=/dev/null
  if [ `uname | grep -i "sunos" | wc -l | awk '{print $1}'` -eq 1 ] ; then
    GREP="ggrep"
    AWK="gawk"
    SED="gsed"
  else
    GREP="grep"
    AWK="awk"
    SED="sed"
  fi
fi

# Create the job dir for the current job
INIT_JOB_NAME=`echo ${JOB_NAME} | ${SED} -e s@'\/'@'_'@g -e s@','@'_'@g -e s@'='@'_'@g`
export DATA_DIR="/gf-hudson-tools/jobs-data/${INIT_JOB_NAME}"
if [ ! -d ${DATA_DIR} ] ; then
  mkdir ${DATA_DIR}
else
  # if the job already exist do a cleanup
  # for jobs that are not running.
  for NAME in `ls ${DATA_DIR}` ; do
    if [ -f ${DATA_DIR}/${NAME} ] || [ -d ${DATA_DIR}/${NAME} ]; then
      ID=${NAME##*-}
      ID=${ID%.sh}
      IS_BUILDING=`curl --noproxy ${HUDSON_MASTER_HOST} ${HUDSON_URL}/job/${JOB_NAME}/${ID}/api/xml 2> ${DEVNULL} | ${AWK} 'BEGIN{ RS=">" ; FS="<" } /<\/building/{ print $1 }' | head -1`
      if [ -z "${IS_BUILDING}" ] || [ "${IS_BUILDING}" = "false" ] ; then
        # Why was this a 'rm -rf'?  Changing it to just 'rm -f'.
        #rm -rf ${DATA_DIR}/${NAME} || true
        rm -f ${DATA_DIR}/${NAME} || true
      fi
    fi
  done
fi

# Copy all files under build-tools/wls to the DATA dir
# and provide variables to access them
cd /gf-hudson-tools/hudson-tools/
for SCRIPT in `ls build-tools/wls/*.sh` ; do
  SCRIPT_NAME=`basename ${SCRIPT%.sh}`
  for VERSION_TAG in latest `git tag -l | ${AWK} '{t=$1 ; gsub("_","",t); print t" "$1}' | sort -rn | head -5 | ${AWK} '{print $2}'` ; do
    if [ "${VERSION_TAG}" = "latest" ] ; then
      DATA_DIR_LOCATION="${DATA_DIR}/${SCRIPT_NAME}-latest-${BUILD_NUMBER}.sh"
      cp /gf-hudson-tools/hudson-tools/build-tools/wls/`basename ${SCRIPT}` ${DATA_DIR_LOCATION}
      # export untagged name as latest
      VARNAME=`echo ${SCRIPT_NAME} | ${SED} s@'-'@'_'@g`
      export ${VARNAME}="${DATA_DIR_LOCATION}"
      # export latest
      VARNAME=${VARNAME}_latest
      export ${VARNAME}="${DATA_DIR_LOCATION}"
    else
      DATA_DIR_LOCATION="${DATA_DIR}/${SCRIPT_NAME}-${VERSION_TAG}-${BUILD_NUMBER}.sh"
      git show ${VERSION_TAG}:build-tools/wls/`basename ${SCRIPT}` 1> ${DATA_DIR_LOCATION} || true
      VERSION=`echo ${VERSION_TAG} | ${SED} -e s@'-'@'_'@g -e s@'\.'@'_'@g`
      VARNAME="`echo ${SCRIPT_NAME} | ${SED} s@'-'@'_'@g`_${VERSION}"
      export ${VARNAME}="${DATA_DIR_LOCATION}"
    fi
  done
done
cd - > ${DEVNULL} 2>&1
printf "\n"
