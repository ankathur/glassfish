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

LOCAL_GF_GIT_REPO="${GF_ROOT}/.git"
export PATH=/gf-hudson-tools/bin:${PATH}

# Incremental workspace cleanup
# Keep GlassFish (Git repository)
# Keep repository (Maven local repository)
for file in `ls ${WORKSPACE}`
do
  if [ "${file}" != "." ] && [ "${file}" != ".." ] \
    && [ "${file}" != "GlassFish" ] && [ "${file}" != "repository" ] \
    && [ "${file}" != "debug.log" ]; then
    rm -rf ${file}
  fi
done

# Prune the local repository of the in-house groupIds
# To ensure local dependencies are built
if [ -d "${WORKSPACE}/repository" ] ; then
  rm -rf "${WORKSPACE}/repository/org/glassfish"
  rm -rf "${WORKSPACE}/repository/com/sun"
fi

# Incremental fetch
# I.e git clone the first time
#     git pull otherwise
if [ "$(ls -A ${LOCAL_GF_GIT_REPO})" ]; then
  cd ${GF_ROOT}
  git pull origin master
else
  pwd
  id
  ls -l
  git clone ${GF_WORKSPACE_URL_SSH} /scratch/gf-code
 ls	 
 ls /scratch/gf-code
  cd ${GF_ROOT}
fi

/bin/bash -ex /scratch/gf-hudson-tools/hudson-tools/build-tools/glassfish/gfbuild.sh build_re_dev 2>&1
cp /scratch/gf-hudson-tools/hudson-tools/build-tools/glassfish/retry_config $CONTAINER_WORKSPACE/retry_config
#if [ -z "${JENKINS_HOME}" ] && [ -z "${JENKINS_URL}" ]; then
# LINUX_LARGE_POOL="POOL-1-LINUX-LARGE"
# SOLARIS_POOL="solaris-sparc"
# test_ids=`/bin/bash -ex .${GF_ROOT}/appserver/tests/gftest.sh list_test_ids ${1} | sed s/security_all/security_all\=$SOLARIS_POOL/g |sed s/findbugs_all/findbugs_all\=$LINUX_LARGE_POOL/g | sed s/findbugs_low_priority_all/findbugs_low_priority_all\=$LINUX_LARGE_POOL/g`
#else
  #test_ids=`ql_gf_full_profile_all`
#fi  




bash -ex /scratch/gf-hudson-tools/hudson-tools/build-tools/trigger_and_block.sh ql_gf_full_profile_all
cp -r /scratch/free-folder/test-results ${CONTAINER_WORKSPACE}/
bash -ex /scratch/gf-hudson-tools/hudson-tools/build-tools/glassfish/checkJobStatus.sh
