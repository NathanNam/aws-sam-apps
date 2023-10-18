# Integration tests

This directory contains integration tests for our apps. Tests are written using the [terraform test framework](https://developer.hashicorp.com/terraform/language/tests)

To run the full test suite, run:

```
terraform init
terraform test
```

## Walkthrough

The following is a naive explanation of what `terraform test` is doing under the hood

The first thing `test/forwarder.tftest.hcl` does is

```shell
run "setup" {
  module {
    source = "./tests/setup"
  }
}
```

Which we can do ourselves

```shell
pushd test/setup
terraform init
terraform apply
popd
```

Next up the test will install the forwarder which requires some outputs from `setup`

```shell
run "install_forwarder" {
  variables {
    name = run.setup.id
    app = "forwarder"
    parameters = {
      DataAccessPointArn = run.setup.destination.arn
      DestinationUri     = "s3://${run.setup.destination.alias}"
      SourceBucketNames  = run.setup.source.bucket
    }
    capabilities = [
      "CAPABILITY_NAMED_IAM",
      "CAPABILITY_AUTO_EXPAND",
    ]
  }
}
```

To do the install manually first we need to get some values from the `terraform apply` we did during setup

```shell
pushd test/setup
export TEST_ID=$(terraform output -json id | jq -r '.')
export SOURCE_BUCKET_NAME=$(terraform output -json source | jq -r '.bucket')
export DESTINATION_ACCESS_POINT_ARN=$(terraform output -json destination | jq -r '.arn')
export DESTINATION_BUCKET=$(terraform output -json destination | jq -r '.bucket')
popd
```

Next we send those variables to the installation terraform `main.tf`

```shell
terraform init

terraform apply \
  -var "name=$TEST_ID" \
  -var "app=forwarder" \
  -var "parameters={DataAccessPointArn=$DESTINATION_ACCESS_POINT_ARN, DestinationUri=s3://$DESTINATION_BUCKET, SourceBucketNames=$SOURCE_BUCKET_NAME}" \
  -var "capabilities=[\"CAPABILITY_NAMED_IAM\", \"CAPABILITY_AUTO_EXPAND\"]"
```
