#!/bin/bash

export SOURCE_BUCKET=${USER}-source-bucket
export DESTINATION_BUCKET=${USER}-destination-bucket
export ACCESS_POINT_NAME="${USER}-destination-access-point"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export APP=forwarder
