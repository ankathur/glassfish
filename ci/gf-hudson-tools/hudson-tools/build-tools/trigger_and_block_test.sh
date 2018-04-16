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

#
# TODO make timeout configurable. (TEST_QUEUE_TIMEOUT, TESTS_RUN_TIMEOUT)
# TODO create a trap and kill downstreams
#

if [ -z "${TEST_JOB_NAME}" ] ; then
  echo "TEST_JOB_NAME variable is not set"
  exit 0
fi

TEST_JOB_URL=${HUDSON_URL}/job/${TEST_JOB_NAME}
DOWNSTREAM_URLS=""
HOSTNAME=`hostname | cut -f 1 -d'.'`

# The max number of failed trigger attempts.
TRIGGER_MAX_RETRY=3

# The max number of failed attempts to find a job.
FIND_JOB_MAX_RETRY=60

# The sleep time between each batch of jobs search.
# If there is queue, this value needs to be increased.
# TIMEOUT ~= FIND_JOB_MAX_RETRY * FIND_JOBS_LOOP_SLEEP
FIND_JOBS_LOOP_SLEEP=10

# The max number of failed attempts to block for a job.
BLOCK_JOB_MAX_RETRY=6

# The sleep time between each batch of jobs blocking.
# If the triggered jobs have a long duration,
# this value needs to be increated.
# TIMEOUT ~= BLOCK_JOB_MAX_RETRY * BLOCK_JOB_MAX_RETRY
BLOCK_JOBS_LOOP_SLEEP=60

# The max number of failed attempts to get status for a job.
GET_JOB_STATUS_MAX_RETRY=6

# The sleep time between each attempt of getting status for a job.
GET_JOB_STATUS_LOOP_SLEEP=10

#
# platform specifics
#
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

#
# Logs an empty line to make spacing in the console output
#
log_empty_line(){
  printf "###\n\n"
}

#
# Logs a message with some markers and date to stdout
# Args: the message to log
#
log_msg(){
  if [ ${#*} -eq 0 ] ; then echo "log_msg() - requires msg arguments" ; return 1 ; fi
  (printf "### [`TZ=PST8PDT date +"%b %d %Y %T"`] ${*} ###\n\n")
}

#
# Log a message with some markers and date to stderr
# Args - the message to log
#
log_debug(){
  log_msg ${*} >&2
}

#
# isnumber - echo true if the provided arg is a number, false otherwise
# Args: The argument that should be evaluated as a number or not.
#
# e.g. if `isnumber -` ; then echo "yes" ; else echo "no" ; fi
# don't use [ ]  or test to interpret true or false
#
isnumber() { 
  if [ ${#} -eq 0 ] ; then
    echo false
    return
  fi
  local x
  x=`echo ${1} | tr -d ' '`
  if [ ${#x} -eq 0 ] ; then
    echo false
    return
  fi
  # only dots
  x=`echo ${1} | tr -d '.'`
  if [ ${#x} -eq 0 ] ; then
    echo false
    return
  fi
  # check for operations (+/-)
  x=`echo ${1} | tr -d '+' | tr -d '/' | tr -d '-'`
  if [ ${#x} -ne ${#1} ] ; then
    echo false
    return
  fi
 
  x=`echo "(${1}+1)/1" | ${BC} 2>&1`
  if [ ${?} -ne 0 ] || [ `echo ${x} | ${GREP} 'error' | wc -l | ${AWK} '{print $1}'` -eq 1 ]; then
    echo false
  else
    echo true
  fi
}

#
# Gets the last build number of the test job.
# This will include the currently on-going runs.
#
get_test_job_last_build_number(){
  local url="${TEST_JOB_URL}/api/xml?xpath=//lastBuild/number/text()"
  log_debug "get_test_job_last_build_number(${url}): invoking curl"
  curl "${url}"
  local error_code=${?}
  if [ ${error_code} -ne 0 ] ; then
    log_debug "get_test_job_last_build_number(${url}): error_code=${error_code}"
  fi
}

#
# Gets the final job status.
# This must be called once the job is complete.
#
# Args: BUILD_NUMBER
#
get_test_job_status(){
  local url="${TEST_JOB_URL}/${1}/api/xml?xpath=//result/text()"
  log_debug "get_test_job_status(${url}): invoking curl"
  curl "${url}"
  local error_code=${?}
  if [ ${error_code} -ne 0 ] ; then
    log_debug "get_test_job_status(${url}): error_code=${error_code}"
  fi
}

#
# Returns true if a test job run is building, false if not.
#
# Args: BUILD_NUMBER
#
is_test_job_building(){
  local url="${TEST_JOB_URL}/${1}/api/xml?xpath=(//building)\[1\]/text()"
  log_debug "is_test_job_building(${url}): invoking curl"
  curl "${url}"
  local error_code=${?}
  if [ ${error_code} -ne 0 ] ; then
    log_debug "is_test_job_building(${url}): error_code=${error_code}"
  fi
}

#
# Returns true if the test job as a queue, false if not
#
# Args: BUILD_NUMBER
#
is_test_job_inqueue(){
  local url="${TEST_JOB_URL}/${1}/api/xml?xpath=//inQueue/text()"
  log_debug "is_test_job_inqueue(${url}): invoking curl"
  curl "${url}"
  local error_code=${?}
  if [ ${error_code} -ne 0 ] ; then
    log_debug "is_test_job_inqueue(${url}): error_code=${error_code}"
  fi
}

#
# Returns the build parameters of a given test job run
# As space separated string of PARAM_NAME=PARAM_VALUE
#
# Args: BUILD_NUMBER
#
get_test_job_params(){
  local url="${TEST_JOB_URL}/${1}/api/xml?xpath=//parameter&wrapper=list"
  log_debug "get_test_job_params(${url}): invoking curl"
  curl "${url}" | \
    ${SED} \
      -e s@'<list><parameter>'@@g -e s@'</list>'@@g \
      -e s@'<parameter>'@@g -e s@'</parameter>'@@g \
      -e s@'<name>'@@g -e s@'</name>'@@g \
      -e s@'<value>'@'='@g -e s@'</value>'@' '@g -e s@'<value/>'@' '@g


  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    log_debug "get_test_job_params(${url}): error_code=${error_code}"
    # exit with curl status code
    return ${PIPESTATUS[0]}
  fi
}

#
# Converts a key=value string into a list
#
# Args: key=value
#
key_val_as_list(){
    local param_key=`echo ${1} | cut -d '=' -f1`
    local param_value=`echo ${1} | cut -d '=' -f2`
    echo "${param_key} ${param_value}"
}

#
# Map style.
# Returns the value for the supplied key
#
# Args: key array_of_key=val
#
get_value_from_key_val_array(){
  local _array=${2}
  local array=(${_array[*]})
  local i=0
  while [ ${i} -lt ${#array[*]} ]
  do
    entry=(`key_val_as_list ${array[${i}]}`)
    if [ "${entry[0]}" = "${1}" ] ; then
      echo "${entry[1]}"
      return 0
    fi
    i=$((i+1))
  done
}

#
# Returns true if the test job was triggered by the current PARENT_ID and given TEST_ID
#
# Args: params array to match the job
#
is_test_job_match(){
  local array=${2}
  local match_params=(${array[*]})
  set +e
  local job_param=(`get_test_job_params ${1}`)
  local error_code=${?}
  set -e

  if [ ${error_code} -ne 0 ] ; then
    # no match
    echo false
    return 0
  fi

  # match provided params with job params
  local i=0
  while [ ${i} -lt ${#match_params[*]} ]
  do
    local match_entry=(`key_val_as_list  ${match_params[${i}]}`)
    job_value=`get_value_from_key_val_array ${match_entry[0]} "${job_param[*]}"`
    if [ "${job_value}" != "${match_entry[1]}" ] ; then
      echo false
      return 0
    fi
    i=$((i+1))
  done
  # match
  echo true
}

#
# Find a test job for TEST_ID
#
# Args: TEST_ID PREVIOUS_LAST_BUILD
#
find_test_job(){
    local previous_last_build=${2}
    local last_build=`get_test_job_last_build_number`

    # nothing running and nothing new completed
    if [ "${previous_last_build}" = "${last_build}" ] ; then
      return 1
    fi

    # look into the newly completed run
    local i=$((previous_last_build+1))
    while [ ${i} -le ${last_build} ]
    do
      local params
      params[1]="PARENT_NODE=${HOSTNAME}"
      params[0]="PARENT_ID=${JOB_NAME}_${BUILD_NUMBER}"
      params[1]="PARENT_WS_PATH=${WORKSPACE}"
      params[2]="TEST_ID=${1}"
      if `is_test_job_match ${i} "${params[*]}"` ; then
        # the triggered run is already completed
        echo ${i}
        return 0
      fi
      i=$((i+1))
    done

    # not found
    return 1
}

#
# Triggers a test job run for a given TEST_ID
# Returns the corresponding BUILD_NUMBER in test job
#
# Args: NODENAME WORKSPACE_PATH TEST_ID
#
trigger_test_job(){
  local params
  if [[ ${#} -eq 3 ]]; then
    params="PARENT_ID=${JOB_NAME}_${BUILD_NUMBER}&PARENT_NODE=${1}&PARENT_WS_PATH=${2}&TEST_ID=${3}"
    log_msg "[INFO] trigger_test_job(): triggering ${3}"
  elif [[ ${#} -eq 4 ]]; then
    params="PARENT_ID=${JOB_NAME}_${BUILD_NUMBER}&PARENT_NODE=${1}&PARENT_WS_PATH=${2}&TEST_ID=${3}&LABEL=${4}"
    log_msg "[INFO] trigger_test_job(): triggering ${3} on label ${4}"
  fi
  curl -X POST \
    "${TEST_JOB_URL}/buildWithParameters?${params}&delay=0sec" 2> /dev/null
}

#
# Adds status regarding a given test job to ${WORKSPACE}/test-results/status.txt
# If a exist already exist for TEST_ID, it will be replaced.
#
# Args: TEST_ID JOB_URL TEST_STATUS [MESSAGE]
#
add_to_test_status(){
  local status_file=${WORKSPACE}/test-results/test-status.txt
  if [ -f ${status_file} ] ; then
    cat ${status_file} | ${GREP} -v "~ ${1} ~" > ${status_file}.tmp
    mv ${status_file}.tmp ${status_file}
  fi
  echo " ~ ${1} ~ ${2} ~ ${3} ~ ${4}" >> ${status_file}
  cat ${status_file}
}

#
# Triggers all downstreams and returns a space separated string
# for the build numbers of the downstream jobs.
#
# Args: list of TEST_ID
#
run_test_jobs(){

  local test_ids=${*}
  local triggers
  local error_count
  local triggered_test_ids=""

  log_empty_line
  if [ ${#test_ids} -eq 0 ] ; then
    log_msg "[INFO] run_test_jobs(): no test ids provided, skipping."
    return 0
  fi
  log_msg "[INFO] run_test_jobs(): triggering jobs"

  # get the last build before the triggers
  local last_build=`get_test_job_last_build_number`

  for test_id in ${test_ids}
  do
    local testid_entry=(`key_val_as_list ${test_id}`)
    local testid_key=${testid_entry[0]}
    local testid_value=${testid_entry[1]}
    for i in 1 2 3
    do
      set +e
      if [[ ${testid_key} = ${testid_value} ]]; then
        trigger_test_job "${HOSTNAME}" "${WORKSPACE}" "${test_id}"
      else
        trigger_test_job "${HOSTNAME}" "${WORKSPACE}" "${testid_key}" "${testid_value}"
        test_id=${testid_key}
      fi
      local error_code=${?}
      set -e
      if [ ${error_code} -eq 0 ] ; then
        triggered_test_ids="${triggered_test_ids} ${test_id}"
        mkdir -p ${WORKSPACE}/test-results/${test_id}
        break
      fi
    done
  done

  log_msg "[INFO] run_test_jobs(): all jobs triggered."
  sleep 40

  # to array
  triggered_test_ids=(${triggered_test_ids})

  # initialize error_count array with 1
  # it is used to keep tracks of error count per test_id
  for ((i=0;i<${#triggered_test_ids[@]};i++))
  {
    error_count[${i}]=1
  }

  log_empty_line
  log_msg "[INFO] run_test_jobs(): waiting for all jobs to be running."

  while(true)
  do

    # for each test_id, find trigger
    local test_id_index=0
    for test_id in ${triggered_test_ids[@]}
    do

      # skip if trigger is already found
      if [ ! -z "${triggers[${test_id_index}]}" ] ; then
        test_id_index=$((test_id_index+1))
        continue
      fi

      set +e
      local job_url=${TEST_JOB_URL}/${job_build_number}
      local job_build_number=`get_trigger ${test_id} ${last_build}`
      local error_code=${?}
      set -e

      # find_test_job failed, record the error count for the test_id
      if [ ${error_code} -ne 0 ] ||  ! `isnumber ${job_build_number}`; then
        log_msg "[ERROR] run_test_jobs(): unable to find job for ${test_id} (ERROR_COUNT=${error_count[${test_id_index}]})"

        # allow up to 6 errors per test_id
        if [ ${error_count[${test_id_index}]} -gt 6 ] ; then
          add_to_test_status "${test_id}" "-" "ABORTED" "(unable to find job)"
          # record the test_id as ABORTED (-1)
          triggers[${test_id_index}]="${test_id}=-1"
        fi
        # record error_count for the test_id
        error_count[${test_id_index}]=$((error_count[${test_id_index}]+1))

      # find_test_job succeeded, record the build_number for the test_id
      else
        log_msg "[INFO] run_test_jobs(): found job for ${test_id}: ${job_url}"
        triggers[${test_id_index}]="${test_id}=${job_build_number}"
      fi

      test_id_index=$((test_id_index+1))
    done

    if [ ${#triggers[@]} -eq ${#triggered_test_ids[@]} ] ; then
      log_msg "[INFO] run_test_jobs(): all jobs found."
      break;
    fi

    log_msg "[INFO] run_test_jobs(): sleep 10."
    sleep 10
  done

  # Error: no job found.
  if [ ${#triggers[@]} -eq 0 ] ; then
    log_msg "[ERROR] run_test_jobs(): no job found for test ids: ${test_ids}"
    return 1
  fi

  wait_for_test_jobs_completion ${triggers[@]}
}

curl_debug(){
  local url=$1
  local opts=$2
  set +e
  result=`curl -f ${opts} ${url}`
  local error_code=${?}
  set -e
  if [ ${error_code} -ne 0 ];then
    log_msg "[ERROR] curl_debug(): curl to ${url} with ${opts} failed."
    echo ""
  else
    echo $result
  fi
}

get_trigger(){
  local test_id_inp=$1                                                                                                                                                                               
  local parent_job_id="${JOB_NAME}_${BUILD_NUMBER}"
  local url="${TEST_JOB_URL}/api/xml?xpath=//build/number&wrapper=list"
  for build_number in `curl_debug "${url}" | ${SED} -e s@'<number>'@'\n<number>'@g -e s@'<list>'@@g -e s@'</list>'@@g -e s@'<number>'@@g -e s@'</number>'@@g | ${SED} '1d'`
  do
     job_url="$TEST_JOB_URL/$build_number"
     curl_url="${job_url}/api/xml?xpath=//parameter[name=\"PARENT_ID\"]/value/text()"
     parent=`curl_debug ${curl_url} --globoff`     
     curl_url="${job_url}/api/xml?xpath=//parameter[name=\"TEST_ID\"]/value/text()"
     test_id=`curl_debug ${curl_url} --globoff`
     curl_url="${job_url}/api/xml?xpath=//number/text()"
     trigger_number=`curl_debug ${curl_url} --globoff`
     if [ "$parent" = "${parent_job_id}" -a "$test_id" = "${test_id_inp}" ];then
       echo $trigger_number
       break
     fi
  done
}

# Checks status of downstream job result
# Ideally this should be pushed to downstream job, but due to hudson 
# text plugin bug with concurrent jobs. We cannot do this.
# Args: TEST_ID

is_job_stable(){
  local test_id_inp=$1
  local is_success
  case ${test_id_inp} in                                                                                                                                                                            
    findbugs_all)
      result_file="${WORKSPACE}/test-results/${test_id_inp}/results/findbugs_results/findbugscheck.log"
      is_success=`cat "${result_file}" | ${GREP} "SUCCESS" || true`;;
    findbugs_lp)
      result_file="${WORKSPACE}/test-results/${test_id_inp}/results/findbugs_lp_results/findbugscheck.log"
      is_success=`cat "${result_file}" | ${GREP} "SUCCESS" || true`;;                                                                                                                              
    copyright)
      result_file="${WORKSPACE}/test-results/${test_id_inp}/results/copyright_results/copyrightcheck.log"
      is_success=`cat "${result_file}" | ${GREP} "SUCCESS" || true`;;                                                                                            
    *)                                                   
      JUD="${WORKSPACE}/test-results/${test_id_inp}/results/junitreports/test_results_junit.xml"
      is_failure=`cat ${JUD} | ${GREP} -aE "<failure ((type)*|(message)*)" || true `
      is_error=`cat ${JUD} | ${GREP} -aE "<error ((type)*|(message)*)" || true`
      if [ "${is_failure}" != "" -o "${is_error}" != "" ];then
        is_success=""
      else
        is_success="SUCCESS"
      fi
      ;;
   esac
   echo "$is_success"
}

#Triggers job again if it was unstable 
# Args: TEST_ID JOB_ID TRIGGER_RETRY_COUNT
trigger_again_if_unstable(){
  local test_id_inp=$1  
  local trigger_count=$3
  local new_trigger=$2
  local is_success=`is_job_stable ${test_id_inp}`
  if [ "${is_success}" = ""  ];then
    #job is unstable trigger again
    if [ "${trigger_count}" -le "2" ];then
      trigger_test_job "${HOSTNAME}" "${WORKSPACE}" "${test_id_inp}" > /dev/null
      new_trigger=`get_trigger ${test_id_inp}`
    fi
  fi 
  echo ${new_trigger}
}

#
# Blocks until the given jobs are complete.
# Args: array of TEST_ID=TEST_BUILD_NUMBER
#
wait_for_test_jobs_completion(){

  local triggers=(${*})
  local count=1
  local error_count
  local trigger_status
  local trigger_retry_count

  log_empty_line
  log_msg "[INFO] wait_for_jobs_completion(): waiting for jobs to complete."

  # error_count is an array of error count for each trigger
  # trigger_status is an array of trigger status
  #   - 0 means assumed to be running
  #   - 1 means assumed to bead dead (ABORTED)
  #   - 2 means assumed to be completed.
  for ((i=0;i<${#triggers[@]};i++))
  {
    error_count[${i}]=1
    trigger_status[${i}]=0
    trigger_retry_count[${i}]=1
  }

  # block here untill TRIGGER_STATUS has no 0
  # refresh status every minute
  # timeout 420*60 seconds (4hours)
  while(true)
  do

    log_empty_line

    # get the status for each trigger (max retry 6) every minute
    for ((i=0;i<${#triggers[@]};i++))
    {
      local trigger_entry=(`key_val_as_list ${triggers[${i}]}`)
      local test_id=${trigger_entry[0]}
      local job_build_number=${trigger_entry[1]}
      local job_url=${TEST_JOB_URL}/${job_build_number}

      # job_build_number == -1 means the trigger was not found
      # mark the trigger_status as ABORTED
      if [ -z "${job_build_number}" ] || [ "${job_build_number}" = "-1" ] ; then
        trigger_status[${i}]=1
        printf "### [JOB_STATUS]     [ERROR] TEST_ID=${test_id} - JOB_URL=${job_url} ###\n\n"
        continue
      fi

      # get the trigger status (running, dead, complete)
      set +e
      local is_building=`is_test_job_building ${job_build_number}`
      local error_code=${?}
      set -e

      # able to get the trigger status
      if [ ${error_code} -eq 0 ] ; then
        if ! ${is_building} ; then
          # job is complete          
          isIntermittent=`cat ${WORKSPACE}/retry_config | ${GREP} ${test_id}` || true
          if [ "${isIntermittent}" != "" ];then
            trigger_retry_buildNumber=`trigger_again_if_unstable ${test_id} ${job_build_number} ${trigger_retry_count[${i}]}`
          else
            trigger_retry_buildNumber=${job_build_number}
          fi
          if [ "$trigger_retry_buildNumber" = "$job_build_number" ];then
            printf "### [JOB_STATUS] [COMPLETED] TEST_ID=${test_id} - JOB_URL=${job_url} ###\n\n"     
            trigger_status[${i}]=2
          else
            printf "### [JOB_STATUS]    [RUNNING] [ATTEMPT-${trigger_retry_count[${i}]}]  TEST_ID=${test_id} - JOB_URL=${TEST_JOB_URL}/${trigger_retry_buildNumber} ###\n\n"
            triggers[${i}]="${test_id}=${trigger_retry_buildNumber}"
            trigger_status[${i}]=0
            ((trigger_retry_count[${i}]++))
          fi
        else
          # job is still running
          printf "### [JOB_STATUS]   [RUNNING] [ATTEMPT-${trigger_retry_count[${i}]}] TEST_ID=${test_id} - JOB_URL=${job_url} ###\n\n"
        fi
      else
        # max retry 6, mark the job ABORTED
        if [ ${error_count[${i}]} -eq 6 ] ; then
          trigger_status[${i}]=1
        fi
        printf "### [JOB_STATUS]     [ERROR] TEST_ID=${test_id} - JOB_URL=${job_url} ###\n\n"
        error_count[${i}]=$((error_count[${i}]+1))
      fi
    }

    log_empty_line

    # keep blocking ?
    local completed=true
    for ((i=0;i<${#trigger_status[@]};i++))
    {
      if [ ${trigger_status[${i}]} -eq 0 ] ; then
        completed=false
        break;
      fi
    }

    # all jobs completed
    if ${completed} ; then

      log_msg "[INFO] wait_for_test_jobs_completion(): all test jobs completed."

      for ((i=0;i<${#triggers[@]};i++))
      {
        local trigger_entry=(`key_val_as_list ${triggers[${i}]}`)
        local test_id=${trigger_entry[0]}
        local job_build_number=${trigger_entry[1]}
        local job_url=${TEST_JOB_URL}/${job_build_number}

        # job is alredy known to be aborted
        if [ ${trigger_status[${i}]} -eq 1 ]; then
          add_to_test_status "${test_id}" "${job_url}" "ABORTED"
        else
          # job is complete
          # get the job status (passed, unstable, aborted, failed)
          local error_count=1
          while(true)
          do

            set +e
            local test_status=`get_test_job_status ${job_build_number}`
            local error_code=${?}
            set -e

            # able to get test_status
            if [ ${error_code} -eq 0 ] ; then
              add_to_test_status "${test_id}" "${job_url}" "${test_status}"
              break
            fi

            # max retry
            if [ ${error_count} -eq 6 ] ; then
              log_msg "[ERROR] wait_for_test_jobs_completion(): unable to get job status for ${job_url}"
              add_to_test_status "${test_id}" "${job_url}" "ABORTED"
              break
            fi

            error_count=$((error_count+1))
            sleep 10
          done
        fi
      }
      break
    fi

    # timeout
    if [ ${count} -gt 420 ] ; then
      for ((i=0;i<${#triggers[@]};i++))
      {
        local trigger_entry=(`key_val_as_list ${triggers[${i}]}`)
        local test_id=${trigger_entry[0]}
        local job_build_number=${trigger_entry[1]}
        local job_url=${TEST_JOB_URL}/${job_build_number}
        if [ ${trigger_status[${i}]} -eq 2 ]; then
          local test_status=`get_test_job_status ${job_build_number}`
          add_to_test_status "${test_id}" "${job_url}" "${test_status}"
        else
          add_to_test_status "${test_id}" "${job_url}" "ABORTED"
        fi
      }
      log_msg "[INFO] wait_for_test_jobs_completion(): timeout 420*60sec."
      break;
    fi

    log_msg "[INFO] wait_for_test_jobs_completion(): sleep 60."
    count=$((count+1))
    sleep 60
  done
}

run_test_jobs ${*}
