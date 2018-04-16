#!/bin/bash -ex
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

#
#  !! This file is not versioned. !!
#

#
# Platform specifics
#
if [ `uname | grep -i "windows" | wc -l | awk '{print $1}'` -eq 1 ] ; then
  IS_WINDOWS=1
  IS_SOLARIS=0
  IS_LINUX=0
  DEVNULL=nul
  GREP="grep"
  AWK="awk"
  SED="sed"
  BC="bc"
else
  IS_WINDOWS=0

  # Don't decrease current ulimit but set only if trying to increase.
  ULIMIT=8192
  CURRENT_ULIMIT=`ulimit -u`
  if [ ${CURRENT_ULIMIT} -lt ${ULIMIT} ]; then
    if [ -z "${VERBOSE}" ] || [ "${VERBOSE}" = "true" ] ; then
      log_msg "wls-hudson-common.sh: increasing ulimit to ${ULIMIT}"
    fi
    ulimit -u ${ULIMIT} || true
  fi

  DEVNULL=/dev/null

  if [ `uname | grep -i "sunos" | wc -l | awk '{print $1}'` -eq 1 ] ; then
    GREP="ggrep"
    AWK="gawk"
    SED="gsed"
    BC="gbc"
    IS_SOLARIS=1
    IS_LINUX=0

    export PATH=/gf-hudson-tools/bin:${PATH}

  else
    GREP="grep"
    AWK="awk"
    SED="sed"
    BC="bc"
    IS_SOLARIS=0

    if [ `uname | grep -i "linux" | wc -l | awk '{print $1}'` -eq 1 ] ; then
      IS_LINUX=1
    fi
  fi
fi

get_global_version(){
  cat /gf-hudson-tools/build-tools/common/infra-version.txt | ${GREP} -v "^#"
}

#
# sources a common script matching the given pattern
# if GLOBAL_VERSION is defined, source that version of the script
# otherwise, determine the version of the value of _BASH_SOURCE
#
# _BASH_SOURCE will be set by this function.
#  it is available to sourced scripts to locate themselves.
#
# If GLOBAL_VERSION is not defined, and _BASH_SOURCE is not defined, this function will fail.
#
# E.g.
# source /gf-hudson-tools/build-tools/common/base.sh
# import "wls_external_common"
#
# Arg1 - the pattern of the script to source
#
import(){
  local VERSION
  if [ -z "${GLOBAL_VERSION}" ] ; then
    if [ -z "${_BASH_SOURCE}" ] ; then
      echo "ERROR, _BASH_SOURCE var is empty"
      return 1
    fi
    VERSION=`${_BASH_SOURCE} | ${SED} 's/\(.*\)-\(.*\)-.*/\2/'`
  else
    VERSION=${GLOBAL_VERSION}
  fi
  local PATTERN=`echo ${1} | ${SED} s@'-'@'_'@g`
  _BASH_SOURCE=`env | ${GREP} ${PATTERN}_${VERSION}= | cut -d '=' -f2`
  source ${_SOURCE_FILE}
}

