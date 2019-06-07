#!/bin/bash

# determine the root directory of the package repo

REPO_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
if [ ! -d  "${REPO_DIR}/.git" ]; then
    2>&1 echo "${REPO_DIR} is not a git repository"
    exit 1
fi

# the first and the only argument should be the version of flink

NAME=$(basename ${BASH_SOURCE[0]})


### move previous repository temporarily

if [ -d ${HOME}/.m2/repository ]; then
    mv ${HOME}/.m2/repository ${HOME}/.m2/repository.backup.$$
fi

### fetch the flink sources and unpack


cd "${REPO_DIR}"
ant -d -autoproxy
# remove previously created artifacts
rm -f sources.txt install.txt files.txt metadata-*.patch

### make the list of the dependencies
DEPENDENCIES=($(find ${HOME}/.m2/repository -type f -name \*.jar -o -name \*.pom))
#METADATA=($(find ${HOME}/.m2/repository -type f -name maven-metadata\*.xml))

### create pieces of the spec (SourceXXX definitions and their install actions)

# some of the maven repositories do not allow direct download, so use single
# repository instead: https://repo1.maven.org/maven2/ . It the same as
# https://central.maven.org, but central.maven.org uses bad certificate (FQDN
# mismatch).
REPOSITORY_URL=https://repo.maven.apache.org/maven2/

SOURCES_SECTION=""
INSTALL_SECTION=""
FILES_SECTION=""
warn=
n=0

for dep in ${DEPENDENCIES[@]}; do
    dep=${dep##${HOME}/.m2/repository/}
    dep_bn=$(basename "$dep")
    dep_dn=$(dirname "$dep")
    dep_url=${REPOSITORY_URL}${dep}
    SOURCES_SECTION="${SOURCES_SECTION}
Source${n} : ${dep_url}"
    INSTALL_SECTION="${INSTALL_SECTION}
mkdir -p %{buildroot}/usr/share/cassandra/.m2/repository/${dep_dn}
cp %{SOURCE${n}} %{buildroot}/usr/share/cassandra/.m2/repository/${dep_dn}"
    FILES_SECTION="${FILES_SECTION}
/usr/share/cassandra/.m2/repository/${dep}"
    let n=${n}+1
done

cd "${REPO_DIR}"

echo "${SOURCES_SECTION}" | sed -e '1d' > sources.txt
echo "${INSTALL_SECTION}" | sed -e '1d' > install.txt
echo "${FILES_SECTION}" | sed -e '1d' > files.txt

cat <<EOF

sources.txt     contains SourceXXXX definitions for the spec file (including
                patches for metadata).
install.txt     contains %install section.
files.txt       contains the %files section.
EOF

if [ -n "${METADATA}" ]; then
    echo Metadata patches:
    ls -1 metadata-*.patch
fi

# restore previous .m2
rm -rf ${HOME}/.m2/repository
if [ -d ${HOME}/.m2/repository.backup.$$ ]; then
    mv ${HOME}/.m2/repository.backup.$$ ${HOME}/.m2/repository
fi
