#!/bin/bash

set -eo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/common.sh

echo "Uploading event.json to the source bucket: s3://${SOURCE_BUCKET}/..."
aws s3 cp $SCRIPT_DIR/../apps/forwarder/events/event.json s3://${SOURCE_BUCKET}/

# Wait for a short duration to allow the Lambda to trigger
echo "Waiting for the Lambda function to process the event..."
sleep 10  # You might need to adjust this delay based on how long the Lambda function typically takes.

echo "Fetching the most recent log stream for the Lambda function..."
export LOG_STREAM_NAME=$(aws logs describe-log-streams --region ${AWS_REGION} --log-group-name /aws/lambda/${FUNCTION_NAME_SIMPLE} --order-by LastEventTime --descending | jq -r '.logStreams[0].logStreamName')

echo "Displaying the Lambda function logs for the past 30 seconds..."
aws logs get-log-events --region ${AWS_REGION} --log-group-name /aws/lambda/${FUNCTION_NAME_SIMPLE} --log-stream-name ${LOG_STREAM_NAME}

echo "Listing all objects in the destination bucket: ${DESTINATION_BUCKET}..."
aws s3 ls s3://${DESTINATION_BUCKET} --recursive

echo "Downloading the processed event.json from the destination bucket..."
aws s3 cp s3://${DESTINATION_BUCKET}/event.json ./event_from_destination.json

md5sum event_from_destination.json
md5sum $SCRIPT_DIR/../apps/forwarder/events/event.json
