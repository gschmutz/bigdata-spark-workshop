#!/bin/bash

#
# Download connector maven dependencies
#
# Author: Guido Schmutz <https://github.com/gschmutz>
#
set -e

# If there's not maven repository url set externally,
# default to the ones below
MAVEN_REPO_CENTRAL=${MAVEN_REPO_CENTRAL:-"https://repo1.maven.org/maven2"}
MAVEN_REPO_CONFLUENT=${MAVEN_REPO_CONFLUENT:-"https://packages.confluent.io/maven"}

maven_dep() {
    local repo="${1:-https://repo1.maven.org/maven2}"
    local mvnCoords="$2"
    local outputDir="$3"

    for i in $(echo $mvnCoords | sed "s/,/ /g")
    do
      local mvnCoord=$i

      local group=$(echo $mvnCoord | cut -d: -f1)
      local groupId=${group//.//}
      local artifactId=$(echo $MVN_COORD | cut -d: -f2)
      local version=$(echo $MVN_COORD | cut -d: -f3)

    ./mvnw dependency:get \
        -DgroupId=$groupId \
        -DartifactId=$artifactId \
        -Dversion=$version \
        -Dpackaging=$packaging \
        -DrepoUrl=$repo

    ./mvnw dependency:copy \
        -Dartifact=$groupId:$artifactId:$version:$packaging \
        -DoutputDirectory=$outputDir
    done
}

maven_central_dep() {
    maven_dep $MAVEN_REPO_CENTRAL $1 $2 $3
}

maven_confluent_dep() {
    maven_dep $MAVEN_REPO_CONFLUENT $1 $2 $3
}

case $1 in
    "central" ) shift
            maven_central_dep ${@}
            ;;
    "confluent" ) shift
            maven_confluent_dep ${@}
            ;;

esac
