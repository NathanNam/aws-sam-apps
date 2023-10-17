#!/bin/bash

set -eo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/common.sh

sam delete --stack-name "$USER-$APP" --region $AWS_REGION --no-prompts

aws s3control delete-access-point --region $AWS_REGION --account-id $AWS_ACCOUNT_ID --name $ACCESS_POINT_NAME

aws s3 rm s3://${SOURCE_BUCKET} --recursive
aws s3 rm s3://${DESTINATION_BUCKET} --recursive
aws s3api delete-bucket --bucket ${SOURCE_BUCKET}
aws s3api delete-bucket --bucket ${DESTINATION_BUCKET}
