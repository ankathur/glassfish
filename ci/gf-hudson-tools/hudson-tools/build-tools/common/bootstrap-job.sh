#!/bin/bash
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

# TODO implement use of base.sh
# source /gf-hudson-tools/build-tools/common/base.sh
# GLOBAL_VERSION=$(get_global_version)
# import "wls_external_common"

# allow overriding JOB_NAME with ORIG_JOB_NAME
if [ ! -z "${ORIG_JOB_NAME}" ] ; then
  _JOB_NAME="${ORIG_JOB_NAME}"
else
  _JOB_NAME="${JOB_NAME}"
fi

# Notes for the naming conventions to be implemented by Romain.
#
# if no JOB_DIR or JOB_SCRIPT is found
# try to set WLS_SRC and ORIG_JOB_NAME based on naming conventions.
#
# Only the following suffixes will be supported:
#
# If job name ends with -srcNNNN set WLS_SRC=srcNNNN
# If job name ends with -sandbox-XXXX set WLS_SRC=sandbox/XXXX
# If job name ends with -sb-XXXX set WLS_SRC=sandbox/XXXX
#
# * Special aliases *
# If job name ends with -ps1, set WLS_SRC=src122110
#
# E.g. job name is cluster-tests-srcXXX, WLS_SRC=XXX, ORIG_JOB_NAME=cluster-tests
# E.g. job name is cluster-tests-sb-XXX, WLS_SRC=sandbox/XXX, ORIG_JOB_NAME=cluster-tests
# E.g. job name is cluster-tests-sandbox-XXX, WLS_SRC=sandbox/XXX, ORIG_JOB_NAME=cluster-tests
# E.g. job name is cluster-tests-ps1, WLS_SRC=src122110, ORIG_JOB_NAME=cluster-tests

JOB_DIR="/gf-hudson-tools/hudson-tools/jobs/${_JOB_NAME%/*}"
if [ -d ${JOB_DIR} ] ; then

  # TODO remove this when we start using base.sh
  if [ `uname | grep -i "sunos" | wc -l | awk '{print $1}'` -eq 1 ] ; then
    SED="gsed"
  else
    SED="sed"
  fi

  WS_TOP=`echo ${WORKSPACE} | ${SED} s@/${JOB_NAME%/*}.*@@g`
  OLD_WORKSPACE=${WORKSPACE}
  BOOTSTRAP_LOG="${WS_TOP}/${_JOB_NAME%/*}-bootstrap.log"

  printf "### invoking init-job-data-dir.sh ###\n\n" > ${BOOTSTRAP_LOG}
  set -x >> ${BOOTSTRAP_LOG} 2>&1
  source /gf-hudson-tools/hudson-tools/build-tools/common/init-jobs-data-dir.sh >> ${BOOTSTRAP_LOG} 2>&1
  set +x >> ${BOOTSTRAP_LOG} 2>&1

  # Pull in some methods used by this file and by hudson common
  source ${wls_external_common_latest}
  source ${wls_clean_processes_latest}

  if [ -z "${SKIP_BOOTSTRAP_CLEAN_PROCESSES}" ] ; then
    clean_job_processes "clean_job_process_bootstrap" ${BOOTSTRAP_LOG}
    perform_clean_processes "clean_processes_bootstrap" ${BOOTSTRAP_LOG}
  fi

  # if WLS_SRC is defined, set the workspace with it
  # to reuse workspace and p4 client names.
  if [ ! -z "${WLS_SRC}" ] ; then
    # step out of workspace
    cd ${WS_TOP} >> ${BOOTSTRAP_LOG} 2>&1

    # delete the workspace if not a symlink
    if [ ${IS_WINDOWS} -eq 0 ]; then
      if [ -L "${JOB_NAME%/*}" ] ; then
        log_msg "rm -f ${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG}
        rm -f "${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG} 2>&1
      else
        log_msg "rm -rf ${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG}
        rm -rf "${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG} 2>&1 || true
      fi
    else
      if [ -L "${JOB_NAME%/*}" ] ; then
        log_msg "rm -f ${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG}
        rm -f "${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG} 2>&1
      else
        log_msg "mkdir -p ${WS_TOP}/empty_dir" >> ${BOOTSTRAP_LOG}
        mkdir -p ${WS_TOP}/empty_dir >> ${BOOTSTRAP_LOG} 2>&1 || true

        log_msg "robocopy ${WS_TOP}/empty_dir ${JOB_NAME%/*} /mir" >> ${BOOTSTRAP_LOG}
        robocopy ${WS_TOP}/empty_dir "${JOB_NAME%/*}" /mir >> ${BOOTSTRAP_LOG} 2>&1 || true

        log_msg "rmdir ${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG}
        rmdir "${JOB_NAME%/*}" >> ${BOOTSTRAP_LOG} 2>&1

        log_msg "rmdir ${WS_TOP}/empty_dir" >> ${BOOTSTRAP_LOG}
        rmdir ${WS_TOP}/empty_dir >> ${BOOTSTRAP_LOG} 2>&1 || true
      fi
    fi

    # Set new workspace to branch and symlink it.
    log_msg "Setting new workspace name: export WORKSPACE=${WS_TOP}/wls-${WLS_SRC}" >> ${BOOTSTRAP_LOG}
    export WORKSPACE=${WS_TOP}/wls-${WLS_SRC}

    log_msg "mkdir -p `dirname ${OLD_WORKSPACE}`" >> ${BOOTSTRAP_LOG}
    mkdir -p `dirname ${OLD_WORKSPACE}` >> ${BOOTSTRAP_LOG} 2>&1 || true

    log_msg "which ln" >> ${BOOTSTRAP_LOG}
    which ln >> ${BOOTSTRAP_LOG} 2>&1

    log_msg "ln -s ${WORKSPACE} ${OLD_WORKSPACE}" >> ${BOOTSTRAP_LOG}
    ln -s ${WORKSPACE} ${OLD_WORKSPACE} >> ${BOOTSTRAP_LOG} 2>&1

    log_msg "mkdir -p ${WORKSPACE}" >> ${BOOTSTRAP_LOG}
    mkdir -p ${WORKSPACE} >> ${BOOTSTRAP_LOG} 2>&1 || true

    log_msg "ls -l ${OLD_WORKSPACE}" >> ${BOOTSTRAP_LOG}
    ls -l ${OLD_WORKSPACE} >> ${BOOTSTRAP_LOG} 2>&1

    log_msg "ls -l ${OLD_WORKSPACE}/" >> ${BOOTSTRAP_LOG}
    ls -l ${OLD_WORKSPACE}/ >> ${BOOTSTRAP_LOG} 2>&1
  fi

  log_msg "cd ${WORKSPACE}" >> ${BOOTSTRAP_LOG}
  cd ${WORKSPACE} >> ${BOOTSTRAP_LOG} 2>&1

  # On windows the -f may not work
  for FILE in `ls ${JOB_DIR}/bin/` ; do
    log_msg "rm -rf ./${FILE}" >> ${BOOTSTRAP_LOG}
    rm -rf ./${FILE} >> ${BOOTSTRAP_LOG} 2>&1
  done
  log_msg "cp -rf ${JOB_DIR}/bin/* ." >> ${BOOTSTRAP_LOG}
  cp -rf ${JOB_DIR}/bin/* . >> ${BOOTSTRAP_LOG} 2>&1

  # Run the job script
  set +e
  log_msg "bash -ex ./${_JOB_NAME%/*}.sh" >> ${BOOTSTRAP_LOG}
  bash -ex ./${_JOB_NAME%/*}.sh 2> ${WORKSPACE}/jobdebug.log
  EXIT_CODE=${?}
  set -e

  if [ ! -d ${WORKSPACE}/archives ] ; then
    log_msg "mkdir ${WORKSPACE}/archives" >> ${BOOTSTRAP_LOG}
    mkdir ${WORKSPACE}/archives >> ${BOOTSTRAP_LOG} 2>&1
  fi

  log_msg "mv ${WORKSPACE}/jobdebug.log ${WORKSPACE}/archives/" >> ${BOOTSTRAP_LOG}
  mv ${WORKSPACE}/jobdebug.log ${WORKSPACE}/archives/ >> ${BOOTSTRAP_LOG} 2>&1|| true
  
  # Tail jobdebug when job fails.
  if [ ${EXIT_CODE} -ne 0 ]  && [ ${EXIT_CODE} -ne 123 ] && [ -s ${WORKSPACE}/archives/jobdebug.log ]; then
    printf "\n############## ${_JOB_NAME%/*}.sh exited with code ${EXIT_CODE} - showing last 100 lines of archives/jobdebug.log ##############\n\n"
    tail -100 ${WORKSPACE}/archives/jobdebug.log
    printf "\n##################################\n\n"
  fi

  # Clean up job script.
  rm -f ${_JOB_NAME%/*}.sh || true

  log_msg "mv ${BOOTSTRAP_LOG} ${WORKSPACE}/archives/" >> ${BOOTSTRAP_LOG}
  mv ${BOOTSTRAP_LOG} ${WORKSPACE}/archives/ >> ${BOOTSTRAP_LOG} 2>&1 || true

  log_msg "exit ${EXIT_CODE}" >> ${BOOTSTRAP_LOG}
  exit ${EXIT_CODE}
else
  echo "ERROR ${JOB_DIR} does not exist"
  exit 1
fi

