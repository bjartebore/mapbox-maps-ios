#!/usr/bin/env bash

set -eo pipefail

#
# Usage:
#   ./scripts/ios/maps-api-check.sh <current release tag (empty for branches)> <path to current MapboxMaps.zip> <optional, path to previous MapboxMaps.zip>
#

TAGGED_RELEASE_VERSION=$1
TAGGED_RELEASE_VERSION=${TAGGED_RELEASE_VERSION:6}

if [[ ! -f $2 ]]
then
  echo "Please provide path to the current MapboxMaps.zip file"
  exit 1
fi

CURRENT_DIR=$(dirname "$0")
ROOT_DIR="${CURRENT_DIR}/../.."
REPORT_DIR=${ROOT_DIR}/api_compat_report
mkdir -p ${REPORT_DIR}

TMPDIR=`mktemp -d`
mkdir ${TMPDIR}/current ${TMPDIR}/previous
cp $2 ${TMPDIR}/current/MapboxMaps.zip
CURRENT_RELEASE=${TMPDIR}/current/MapboxMaps.zip
PREVIOUS_RELEASE=${TMPDIR}/previous/MapboxMaps.zip
CURRENT_RELEASE_DIR=$(dirname ${CURRENT_RELEASE})
PREVIOUS_RELEASE_DIR=$(dirname ${PREVIOUS_RELEASE})

if [[ -z ${TAGGED_RELEASE_VERSION} ]]; then
    LAST_VERSION=$(git describe --tags $(git rev-list --tags --max-count=1))
else
    LAST_VERSION=$(git describe --tags $(git rev-list --tags --max-count=1 --skip=1 --no-walk))
fi
LAST_VERSION=${LAST_VERSION:1}

if [[ -z $3 ]]; then
  echo "Path to previous version of MapboxMaps.zip is not set, using ${LAST_VERSION}"
  aws s3 cp s3://mapbox-api-downloads-production/v2/mobile-maps-ios/releases/ios/${LAST_VERSION}/MapboxMaps.zip ${PREVIOUS_RELEASE}
else
  cp $3 ${TMPDIR}/previous/MapboxMaps.zip
fi

if [[ ! -d ~/mapbox-apidiff ]]; then
    git clone --depth 1 https://github.com/mapbox/apidiff ~/mapbox-apidiff
    pushd ~/mapbox-apidiff/apple/diffreport > /dev/null
    swift build
    popd > /dev/null
fi

# Generates sourcekitten json doc
generateSourceKittenDoc() {
    set -eo pipefail
    OUT_DIR=$(dirname $1)
    pushd ${OUT_DIR} > /dev/null
    mkdir MapboxMaps
    unzip -qq MapboxMaps.zip -d .
    cp -r artifacts/MapboxMaps.xcframework/ios-arm64/MapboxMaps.framework/* ./MapboxMaps/

    # Generate doc for public headers
    sourcekitten doc --module-name sourcekitten doc -- -workspace Apps/Apps.xcworkspace \
        -scheme MapboxMaps -sdk iphonesimulator > swift_public.json

    # Merge the output for the public and external modules
    jq -s \
        '[ .[0] + .[1] | .[] | {name: keys[0], data: .[keys[0]]} ] | group_by(.name) | [.[] | add | {(.name): .data}]' \
        ./swift_public.jsonn > swift_api.json

    if [[ $(jq length objc_api.json) == 0 ]]; then
        echo "sourcekitten output is empty" >&2
        exit 1
    fi

    popd > /dev/null
}

parse_json_report() {
    set -eo pipefail
    node - <<'EOF' "$1"
const fs = require('fs');
const data = fs.readFileSync(process.argv[2]).toString();
const report = JSON.parse(data);
const issues = Object.keys(report).reduce((acc, k) => {
    return report[k].reduce((acc, entry) => {
        const hasDuplicate = (diffType) => {
            return report[k].find(e => e.name === entry.name && e.diff === diffType);
        }
        if (entry.diff === "addition" && !hasDuplicate("deletion")) {
            acc.minor++;
        }
        if (entry.diff === "deletion" && !hasDuplicate("addition")) {
            acc.major++;
        }
        if (entry.diff === "modification") {
            acc.unknown++;
        }
        return acc;
    }, acc);
}, {minor: 0, major: 0, unknown: 0});
console.log(`MAJOR_PROBLEMS=${issues.major}`);
console.log(`MINOR_PROBLEMS=${issues.minor}`);
console.log(`UNKNOWN_PROBLEMS=${issues.unknown}`);
EOF
}

compareAPI() {
    set -eo pipefail
    JSON_TMP_FILE=$(mktemp)

    pushd ~/mapbox-apidiff/apple/diffreport > /dev/null
    swift run diffreport $1/swift_api.json $2/swift_api.json --json > "${JSON_TMP_FILE}"
    popd > /dev/null

    eval "$(parse_json_report ${JSON_TMP_FILE})"
    mv "${JSON_TMP_FILE}" ${REPORT_DIR}/api_compat.json

    if (( MAJOR_PROBLEMS > 0 )); then
        echo major
    elif (( MINOR_PROBLEMS > 0 )); then
        echo minor
    else
        echo patch
    fi
}

generateSourceKittenDoc ${CURRENT_RELEASE}
generateSourceKittenDoc ${PREVIOUS_RELEASE}
api_compat=$(compareAPI ${PREVIOUS_RELEASE_DIR} ${CURRENT_RELEASE_DIR})
rm -rf ${TMPDIR}

${CURRENT_DIR}/semver-check.sh "${TAGGED_RELEASE_VERSION}" "${LAST_VERSION}" "${api_compat}"