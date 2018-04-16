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

# OS-specific section
if [ `uname | grep -i "sunos" | wc -l | awk '{print $1}'` -eq 1 ] ; then
  GREP="ggrep"
  AWK="gawk"
  SED="gsed"
  BC="gbc"
  export PATH=/gf-hudson-tools/bin:${PATH}
else
  GREP="grep"
  AWK="awk"
  SED="sed"
  BC="bc"
fi

export GREP AWK SED BC

checkStatus(){
  TEST_ID=$1
  STATUS_FILE=$2
  content=$3
  case $TEST_ID in
    findbugs_all)
      resultFile="${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/results/findbugs_results/findbugscheck.log";;
    copyright)
      resultFile="${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/results/copyright_results/copyrightcheck.log";;
    findbugs_low_priority_all)
      resultFile="${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/results/findbugs_low_priority_all_results/findbugscheck.log";;
  esac
  isSuccess=`cat "${resultFile}" | ${GREP} "SUCCESS" || true`
  platform=`cat ${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/platform`
  if [ "${isSuccess}" = "" ];then
    echo "${content} ~ Failures:NA,Errors:NA ~ ${platform} ~"  | ${AWK} -F '~' '{print "~",$2,"~",$3,"~","UNSTABLE","~",$5,"~",$7,"~",$8, "~"}' >> ${STATUS_FILE}
  else
    echo "${content} ~ Failures:NA,Errors:NA ~ ${platform} ~" | ${AWK} -F '~' '{print "~",$2,"~",$3,"~","SUCCESS","~",$5,"~",$7,"~", $8, "~"}' >> ${STATUS_FILE}
  fi
}

add_to_test_status(){
  status_file=${CONTAINER_WORKSPACE}/test-results/test-status.txt
  rm ${status_file}.tmp > /dev/null || true  
  AGG_JUD="${CONTAINER_WORKSPACE}/test-results/test_results_junit.xml"
  rm ${AGG_JUD} > /dev/null || true 
  echo "<testsuites>" >> $AGG_JUD
  IFS=$'\n'
  if [ -f ${status_file} ] ; then
    for i in `cat ${status_file}`
    do
     test_id=`echo ${i} | ${SED} 's/ ~ */~/g' | cut -d'~' -f2`
      isTestSuccess=`echo $i | ${GREP} "SUCCESS" || true`
      if [ "${isTestSuccess}" != "" ];then
        #echo $test_id       
        case ${test_id} in
          findbugs_all)
            checkStatus ${test_id} ${status_file}.tmp ${i};;
          findbugs_low_priority_all)
            checkStatus ${test_id} ${status_file}.tmp ${i};;
          copyright)
            checkStatus ${test_id} ${status_file}.tmp ${i};;
          *)
            set_job_status ${test_id} ${status_file}.tmp ${i}
            aggregate_downstream_junit_xml ${test_id};;
        esac
      else
        platform=`cat ${CONTAINER_WORKSPACE}/test-results/${test_id}/platform`
        echo "${i} ~ Failures:NA,Errors:NA ~ ${platform} ~" | ${AWK} -F '~' '{print "~",$2,"~",$3,"~",$4,"~",$5,"~",$7,"~",$8,"~"}'  >> ${status_file}.tmp
      fi
    done
  fi
  echo "</testsuites>" >> $AGG_JUD
  mv ${status_file}.tmp ${status_file}
}

set_job_status(){
  TEST_ID="${1}"
  statusFile="${2}"
  statusLine="${3}"
  JUD="${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/results/junitreports/test_results_junit.xml"
  isFailure=`cat ${JUD} | ${GREP} -aE "<failure ((type)*|(message)*)" || true `
  isError=`cat ${JUD} | ${GREP} -aE "<error ((type)*|(message)*)" || true`
  numFail=`cat ${JUD} | ${GREP} -acE "<failure ((type)*|(message)*)" || true`
  numError=`cat ${JUD} | ${GREP} -acE "<error ((type)*|(message)*)" || true`
  status="PASSED"
  platform=`cat ${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/platform`
  if [ "${isFailure}" = "" -a "${isError}" = "" ];then
    echo "${statusLine} ~ Failures:0,Errors:0 ~ ${platform} ~" | ${AWK} -F '~' '{print "~",$2,"~",$3,"~","SUCCESS","~",$5,"~",$7,"~",$8,"~"}' >> ${statusFile}
  else
    echo "${statusLine} ~ Failures:${numFail},Errors:${numError} ~ ${platform} ~"  | ${AWK} -F '~' '{print "~",$2,"~",$3,"~","UNSTABLE","~",$5,"~",$7,"~",$8,"~"}' >> ${statusFile}
  fi
}

aggregate_downstream_junit_xml(){
  TEST_ID="${1}"
  JUD="${CONTAINER_WORKSPACE}/test-results/${TEST_ID}/results/junitreports/test_results_junit.xml"
  AGG_JUD="${CONTAINER_WORKSPACE}/test-results/test_results_junit.xml"
  cat ${JUD} | ${SED} '/<\?xml version/d' | ${SED} '/<testsuites>/d' | ${SED} '/<\/testsuites>/d' >>${AGG_JUD}
}

add_to_test_status
