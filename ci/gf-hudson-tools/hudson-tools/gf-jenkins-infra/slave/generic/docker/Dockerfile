FROM oraclelinux:latest

RUN mkdir /var/run/sshd
RUN mkdir /scratch

#RUN useradd -d/scratch/java_re -c"Java Release Engineering" -s/bin/bash -u1337 -g10 java_re
#RUN sed s@'^java_re:.*'@'java_re:$5$TzT/gGrX$teXW3yKey7gRv0noPn7cx5kYwUya/sNXx4g3Vexzio3:16569::::::3755344'@g -i /etc/shadow
#RUN echo 'uadmin:x:0:0:Alternate Administrator:/root:/bin/bash' >> /etc/passwd
#RUN echo 'uadmin:v76NXnOK3QcHI:16681::::::' >> /etc/shadow

RUN mkdir /scratch/gf-code
RUN mkdir /scratch/mvn
RUN mkdir /scratch/jdk
RUN mkdir /scratch/BUILD_AREA
RUN mkdir /scratch/gf-hudson-tools/
RUN mkdir /scratch/workspace
RUN mkdir /scratch/host_ssh
RUN mkdir /scratch/free-folder
#RUN chown -R java_re:wheel /scratch/BUILD_AREA
#RUN chown -R java_re:wheel /scratch/jdk
#RUN chown -R java_re:wheel /scratch/mvn
#RUN chown -R java_re:wheel /scratch/gf-hudson-tools
#RUN chown -R java_re:wheel /scratch/gf-code
#RUN chown -R java_re:wheel /scratch/workspace
#RUN chown -R java_re:wheel /scratch/free-folder


ENV TINI_VERSION 0.14.0
ENV TINI_SHA 6c41ec7d33e857d4779f14d9c74924cab0c7973485d2972419a3b7c7620ff5fd

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha256sum -c -
ENTRYPOINT ["/bin/tini", "--"]

RUN echo 'rpc_pipefs  /var/lib/nfs/rpc_pipefs rpc_pipefs  defaults  0 0' > /etc/fstab
RUN echo 'nfsd  /proc/fs/nfsd nfsd  defaults  0 0' >> /etc/fstab
RUN echo '/dev/BUILD_AREA /scratch/BUILD_AREA ext4    barrier=0       1 2' >> /etc/fstab

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN ssh-keygen -f /root/.ssh/ssh_host_rsa_key -N '' -t rsa

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# increase max nproc ulimit for 8GB memory
RUN echo 'root soft nproc 8192' >> /etc/security/limits.conf
RUN echo 'root hard nproc 8192' >> /etc/security/limits.conf


# TODO add epel repo
# wget http://mirror.cs.pitt.edu/epel//epel-release-latest-7.noarch.rpm
# rpm -ivh epel-release-latest-7.noarch.rpm

RUN yum install -y git bc subversion unzip tar wget autofs showmount rng-tools which sendmail bind-utils net-tools whois rusers-server ntp libaio zip libxml2 libXext.x86_64 libXrender.x86_64 libXtst.x86_64

# required for the locale setup, nslookup, iconvconfig and other things..
# need to reinstall, as the package is present but altered by the base container
# See http://unix.stackexchange.com/questions/140299/locale-gen-command-in-centos6
# See https://github.com/docker/docker/blob/master/contrib/mkimage-yum.sh
RUN yum reinstall -y glibc-common glibc

RUN curl -O ftp://rpmfind.net/linux/centos/6.9/os/x86_64/Packages/nc-1.84-24.el6.x86_64.rpm
RUN rpm -ivh nc-1.84-24.el6.x86_64.rpm

RUN chmod u+s /usr/bin/ping

RUN unlink /etc/localtime
RUN ln -s /usr/share/zoneinfo/US/Pacific /etc/localtime

#installing jdk 8 and mvn
RUN wget --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jdk-8u161-linux-x64.tar.gz
RUN tar -xvzf jdk-8u161-linux-x64.tar.gz -C /scratch/jdk
RUN wget http://redrockdigimark.com/apachemirror/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz
RUN tar -xvzf apache-maven-3.5.2-bin.tar.gz -C /scratch/mvn

#adding mirror according to eclipse enviroment
RUN sed -i 's/<id>mirrorId<\/id>/<id>eclipse.maven.central.mirror<\/id>/g' /scratch/mvn/apache-maven-3.5.2/conf/settings.xml
RUN sed -i 's/<mirrorOf>repositoryId<\/mirrorOf>/<mirrorOf>central<\/mirrorOf>/g' /scratch/mvn/apache-maven-3.5.2/conf/settings.xml
RUN sed -i 's/<name>Human Readable Name for this Mirror.<\/name>/<name>Eclipse Central Proxy<\/name>/g' /scratch/mvn/apache-maven-3.5.2/conf/settings.xml
RUN sed -i 's/<url>http:\/\/my.repository.com\/repo\/path<\/url>/<url>https:\/\/repo.eclipse.org\/content\/repositories\/maven_central\/<\/url>/g' /scratch/mvn/apache-maven-3.5.2/conf/settings.xml

COPY ./files/container-init.sh /etc/container-init-testid.sh
COPY ./files/wait.sh /etc/wait.sh
COPY ./files/gfbuildwrapper.sh /etc/gfbuildwrapper.sh
RUN chmod +x /etc/container-init-testid.sh
RUN chmod +x /etc/gfbuildwrapper.sh
EXPOSE 22
CMD ["/bin/bash","-c","/etc/container-init-testid.sh"]
