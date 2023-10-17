#!/bin/bash

set -eo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

FORCE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/common.sh

# Ensure the AWS CLI is authenticated
echo "Verifying AWS Account Information..."
aws sts get-caller-identity

if [ "$FORCE" = false ] ; then
    read -p "Is this the correct AWS account? [y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Exiting due to incorrect AWS account."
        exit 1
    fi
fi

echo "Packaging SAM Application..."
make sam-package

echo "Creating Source Bucket: $SOURCE_BUCKET..."
aws s3api create-bucket --bucket ${SOURCE_BUCKET} --region ${AWS_REGION}

echo "Creating Destination Bucket: $DESTINATION_BUCKET..."
aws s3api create-bucket --bucket ${DESTINATION_BUCKET} --region ${AWS_REGION}

echo "Attempting to delete existing Access Point if it exists..."
aws s3control delete-access-point --account-id $AWS_ACCOUNT_ID --name $ACCESS_POINT_NAME --region $AWS_REGION || true

echo "Creating Access Point for the Destination Bucket..."
export DATA_ACCESS_POINT_ARN=$(aws s3control create-access-point --account-id $AWS_ACCOUNT_ID --bucket $DESTINATION_BUCKET --name $ACCESS_POINT_NAME --region $AWS_REGION | jq -r '.AccessPointArn')

echo "Deploying SAM Application..."
sam deploy \
  --template-file "$PWD/apps/$APP/.aws-sam/build/$AWS_REGION/packaged.yaml" \
  --stack-name "$USER-$APP" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --region $AWS_REGION \
  --parameter-overrides SourceBucketNames="$SOURCE_BUCKET" DestinationUri="s3://$DESTINATION_BUCKET/" DataAccessPointArn="$DATA_ACCESS_POINT_ARN" InstallConfig="false"

echo "Deployment Complete!"
