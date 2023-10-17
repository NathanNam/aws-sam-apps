#!/bin/bash

set -eo pipefail

if [ -n "${DEBUG:-}" ]; then
    set -x
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/common.sh

echo "Fetching SQS queue URL for $USER-$APP..."
export QUEUE_URL=$(aws sqs get-queue-url --queue-name "$USER-$APP" --region $AWS_REGION | jq -r '.QueueUrl')

echo "Fetching SQS queue ARN..."
export QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names QueueArn --region $AWS_REGION | jq -r '.Attributes.QueueArn')

echo "Configuring S3 bucket notification to SQS..."
aws s3api put-bucket-notification-configuration --bucket $SOURCE_BUCKET --notification-configuration '{
    "QueueConfigurations": [
        {
            "QueueArn": "'$QUEUE_ARN'",
            "Events": ["s3:ObjectCreated:*"]
        }
    ]
}' --region $AWS_REGION

echo "Fetching CloudFormation outputs to get the Lambda function name..."
export FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name "$USER-$APP" --query "Stacks[0].Outputs[?OutputKey=='Function'].OutputValue" --region $AWS_REGION --output text)

echo "Fetching Lambda function role ARN..."
export ROLE_ARN=$(aws lambda get-function-configuration --region ${AWS_REGION} --function-name ${FUNCTION_NAME} --query 'Role' --output text)

echo "Extracting role name from ARN..."
export ROLE_NAME=$(echo $ROLE_ARN | awk -F/ '{print $NF}')

echo "Adding IAM policy to allow Lambda to CopyObject and PutObject..."
aws iam put-role-policy --role-name $ROLE_NAME --policy-name S3AccessPolicy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:CopyObject", "s3:PutObject"],
            "Resource": ["arn:aws:s3:::'$SOURCE_BUCKET'/*", "arn:aws:s3:::'$DESTINATION_BUCKET'/*"]
        }
    ]
}'

echo "Granting Lambda permission to get objects from the source bucket..."
aws s3api put-bucket-policy --bucket $SOURCE_BUCKET --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "'$ROLE_ARN'"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::'$SOURCE_BUCKET'/*"
        }
    ]
}'

echo "Granting Lambda permission to put objects to the destination bucket..."
aws s3api put-bucket-policy --bucket $DESTINATION_BUCKET --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "'$ROLE_ARN'"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::'$DESTINATION_BUCKET'/*"
        }
    ]
}'

echo "Setup complete!"
