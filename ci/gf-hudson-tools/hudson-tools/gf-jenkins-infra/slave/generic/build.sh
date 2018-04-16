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

set -e
print_usage()
{
 echo "Usage: $0  <Image Version>"
 echo "Example: $0 v10" 
}	

# Get  image version name to use
if [ $# -lt 1 ]; then
 print_usage
 exit 1
fi

VERSION="${1}"
IMAGE_GRP="gf-jenkins"
IMAGE_SHORT_NAME="generic-slave"
IMAGE_NAME=${IMAGE_GRP}/${IMAGE_SHORT_NAME}:${VERSION}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCK_DIR="${SCRIPT_DIR}/docker"
IMAGE_TAR="/gf-hudson-tools/jenkins-slave/${IMAGE_SHORT_NAME}-${VERSION}.tar"

#rm -rf ${IMAGE_TAR}
if [ -f ${IMAGE_TAR} ]; then
	echo "Seems the image is already built with this version. Please either delete ${IMAGE_TAR} or try with updated version"
	exit 1
fi

echo "Building Image:  ${IMAGE_NAME}"
echo "Docker File Location: ${DOCK_DIR}/Dockerfile"
ARG=""
if  [ ! -z "${DOCKER_ARG}" ]; then
 ARG="${DOCKER_ARG}"
 echo "Build arguments: ${ARG} "
fi
sudo docker build ${ARG} -t ${IMAGE_NAME} ${DOCK_DIR} 
sudo docker images | grep ${IMAGE_SHORT_NAME} | grep ${VERSION}

sudo docker save -o ${IMAGE_TAR} ${IMAGE_NAME}

set +e
commit=`git log -n 1`
echo $commit

echo "Image ${IMAGE_NAME} is saved as ${IMAGE_TAR}"
ls -l ${IMAGE_TAR}
