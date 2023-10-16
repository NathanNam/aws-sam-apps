SHELL := /bin/bash
.DEFAULT_GOAL := help
.ONESHELL:

REGIONS := us-west-1 us-east-1
VERSION ?= unreleased
# leave this undefined for the purposes of development
S3_BUCKET_PREFIX ?= 

define check_var
	@if [ -z "$($1)" ]; then
		echo >&2 "Please set the $1 variable";
		exit 2;
	fi
endef

SUBDIR = $(shell ls apps)

clean-aws-sam:
	rm -rf apps/*/.aws-sam/*

## help: shows this help message
help:
	@echo "Usage: make [target]"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## go-lint: runs linter for a given directory, specified via PACKAGE variable
go-lint:
	$(call check_var,PACKAGE)
	docker run --rm -v "`pwd`:/workspace:cached" -w "/workspace/$(PACKAGE)" golangci/golangci-lint:latest golangci-lint run

## go-lint-all: runs linter for all packages
go-lint-all:
	docker run --rm -v "`pwd`:/workspace:cached" -w "/workspace/." golangci/golangci-lint:latest golangci-lint run

## go-test: run go tests
go-test:
	go build ./...
	go test -v -race ./...

## sam-lint: validate and lint cloudformation templates
sam-lint:
	$(call check_var,APP)
	sam validate --lint --template apps/$(APP)/template.yaml

.PHONY: sam-build-all
## sam-build-all: build assets for all SAM applications across all regions
sam-build-all:
	@ for app in $(SUBDIR); do \
		for region in $(REGIONS); do \
			APP=$$app AWS_REGION=$$region $(MAKE) sam-build || exit 1; \
		done \
	done

## sam-build: build assets
sam-build:
	$(call check_var,APP)
	$(call check_var,AWS_REGION)
	cd apps/$(APP) && sam build --region $(AWS_REGION) --build-dir .aws-sam/build/$(AWS_REGION)


## sam-publish: publish serverless repo app
sam-publish: sam-package
	$(call check_var,AWS_REGION)
	sam publish \
	    --template-file apps/$(APP)/.aws-sam/build/$(AWS_REGION)/packaged.yaml \
	    --region $(AWS_REGION)

## sam-package: package cloudformation templates and push assets to S3
sam-package: sam-build
	$(call check_var,APP)
	$(call check_var,AWS_REGION)
	$(call check_var,VERSION)
	echo "Packaging for app: $(APP) in region: $(AWS_REGION)"
ifeq ($(S3_BUCKET_PREFIX),)
	sam package \
		--template-file apps/$(APP)/.aws-sam/build/$(AWS_REGION)/template.yaml \
		--output-template-file apps/$(APP)/.aws-sam/build/$(AWS_REGION)/packaged.yaml \
		--resolve-s3 \
		--region $(AWS_REGION)
else
	sam package \
	    --template-file apps/$(APP)/.aws-sam/build/$(AWS_REGION)/template.yaml \
	    --output-template-file apps/$(APP)/.aws-sam/build/$(AWS_REGION)/packaged.yaml \
	    --s3-bucket $(S3_BUCKET_PREFIX)-$(AWS_REGION) \
	    --s3-prefix apps/$(APP)/$(VERSION) \
	    --region $(AWS_REGION)
endif

# Generalized pattern for "*-all" tasks
%-all:
	for dir in $(SUBDIR); do \
		APP=$$dir $(MAKE) $* || exit 1; \
	done

# Generalized pattern for "*-all-regions" tasks
%-all-regions:
	@ for app in $(SUBDIR); do \
		for region in $(REGIONS); do \
			APP=$$app AWS_REGION=$$region $(MAKE) $* || exit 1; \
		done \
	done

## release: make sure S3_BUCKET_PREFIX isn't empty, run sam-package, then set the s3 acl
release:
ifeq ($(S3_BUCKET_PREFIX),)
	$(error S3_BUCKET_PREFIX is empty. Cannot proceed with release.)
endif
	$(MAKE) sam-package
	echo "Copying packaged.yaml to S3"
	aws s3 cp apps/$(APP)/.aws-sam/build/$(AWS_REGION)/packaged.yaml s3://$(S3_BUCKET_PREFIX)-$(AWS_REGION)/apps/$(APP)/$(VERSION)/
	echo "Fetching objects with prefix: apps/$(APP)/$(VERSION)/"
	objects=`aws s3api list-objects --bucket $(S3_BUCKET_PREFIX)-$(AWS_REGION) --prefix apps/$(APP)/$(VERSION)/ --query "Contents[].Key" --output text`; \
	for object in $$objects; do \
		echo "Setting ACL for object: $$object"; \
		aws s3api put-object-acl --bucket $(S3_BUCKET_PREFIX)-$(AWS_REGION) --key $$object --acl public-read; \
	done

build-App:
	$(call check_var,APP)
	$(call check_var,ARTIFACTS_DIR)
	GOARCH=arm64 GOOS=linux go build -tags lambda.norpc -o ./bootstrap cmd/$(APP)/main.go
	cp ./bootstrap $(ARTIFACTS_DIR)/.

build-Forwarder:
	APP=forwarder $(MAKE) build-App

.PHONY: help go-test clean-aws-sam go-lint go-lint-all sam-lint sam-lint-all %-all %-all-regions

