#!/bin/bash -ex

REQUIRED_ARCHIVE_ENV_VARS=(
    "ARCHIVE_AMAZON_BUCKET"
    "ARCHIVE_AMAZON_REGION"
    "ARCHIVE_AMAZON_PREFIX"
)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/../

main() {
    check_archive_env_vars
    archive_artifacts
}

check_archive_env_vars() {
    set +x
    for VAR in ${REQUIRED_ARCHIVE_ENV_VARS[@]}; do
        if [ "${!VAR}" == "" ]; then
            echo "Missing env var $VAR"
            exit 1
        fi
    done
    set -x
}

archive_artifacts() {
    local S3_PATH="s3://$ARCHIVE_AMAZON_BUCKET/$ARCHIVE_AMAZON_PREFIX"
    set +e
    aws s3 cp goviz.png $S3_PATH/goviz.png --region $ARCHIVE_AMAZON_REGION
    aws s3 cp --recursive .cover/ $S3_PATH/.cover/ --region $ARCHIVE_AMAZON_REGION
    aws s3 cp --recursive .robot/ $S3_PATH/.robot/ --region $ARCHIVE_AMAZON_REGION
    aws s3 cp --recursive bin/ $S3_PATH/bin/ --region $ARCHIVE_AMAZON_REGION
    set -e
}

main
