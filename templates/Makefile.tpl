# SPDX-FileCopyrightText: 2022-present Intel Corporation
# SPDX-FileCopyrightText: 2020-present Open Networking Foundation <info@opennetworking.org>
#
# SPDX-License-Identifier: Apache-2.0

# Code generated by model-compiler. DO NOT EDIT.

SHELL = bash -e -o pipefail
DOCKER_REPOSITORY ?= onosproject/
BASE_VERSION ?= $(shell cat ./VERSION)
VERSION           ?= ${BASE_VERSION}-{{ .Name }}-{{ .Version }}
LATEST_VERSION           ?= ${BASE_VERSION}-{{ .Name }}-latest
KIND_CLUSTER_NAME ?= kind
HAS_CHANGED=$(shell git --no-pager diff HEAD~1 HEAD . | wc -l) # check if the content of this folder is different than the parent commit
IS_RELEASED_VERSION=$(shell MY_STRING="${BASE_VERSION}"; MY_REGEX='^([0-9]+)\.([0-9]+)\.([0-9]+)$$'; if [[ $$MY_STRING =~ $$MY_REGEX ]]; then echo true; else echo false; fi)

## Docker labels. Only set ref and commit date if committed
DOCKER_LABEL_VCS_URL       ?= $(shell git remote get-url $(shell git remote | head -n 1))
DOCKER_LABEL_VCS_REF       = $(shell git rev-parse HEAD)
DOCKER_LABEL_BUILD_DATE    ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")
DOCKER_LABEL_COMMIT_DATE   = $(shell git show -s --format=%cd --date=iso-strict HEAD)
DOCKER_BUILD_ARGS = \
	--build-arg org_label_schema_version="${VERSION}" \
	--build-arg org_label_schema_vcs_url="${DOCKER_LABEL_VCS_URL}" \
	--build-arg org_label_schema_vcs_ref="${DOCKER_LABEL_VCS_REF}" \
	--build-arg org_label_schema_build_date="${DOCKER_LABEL_BUILD_DATE}" \
	--build-arg org_opencord_vcs_commit_date="${DOCKER_LABEL_COMMIT_DATE}" \
	--build-arg org_opencord_vcs_dirty="${DOCKER_LABEL_VCS_DIRTY}"

export CGO_ENABLED=0
export GO111MODULE=on

all: help

help: # @HELP Print the command options
	@echo
	@echo "\033[0;31m    Model Plugin: {{ .Name }} \033[0m"
	@echo
	@grep -E '^.*: .* *# *@HELP' $(MAKEFILE_LIST) \
    | sort \
    | awk ' \
        BEGIN {FS = ": .* *# *@HELP"}; \
        {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}; \
    '

mod-update: # @HELP Download the dependencies to the vendor folder
	go mod tidy
	go mod vendor

image: mod-update openapi # @HELP Build the docker image (available parameters: DOCKER_REPOSITORY, VERSION)
	docker build $(DOCKER_BUILD_ARGS) -t ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${VERSION} .
	docker tag ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${VERSION} ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${LATEST_VERSION}

.PHONY: openapi
openapi: mod-update # @HELP Generate OpenApi specs
	go run openapi/openapi-gen.go -o openapi.yaml

test: mod-update # @HELP Run the unit tests
	go test ./...

repo-tag:
ifeq ($(IS_RELEASED_VERSION), true)
ifneq ("$(HAS_CHANGED)", "0 ")
	NEW_VERSION=${VERSION} ../../build/build-tools/tag-collision-reject
	git tag ${VERSION}
	git push origin ${VERSION}
	git tag v${VERSION}
	git push origin v${VERSION}
else
	@echo "No changes, nothing to tag"
endif
else
	@echo "Not a released version, skip tagging"
endif


publish: image repo-tag # @HELP Builds and publish the docker image (available parameters: DOCKER_REPOSITORY, VERSION)
ifneq ("$(HAS_CHANGED)", "0 ")
	docker push ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${VERSION}
	docker push ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${LATEST_VERSION}
else
	@echo "No changes, nothing to push"
endif

kind-only: # @HELP Loads the docker image into the kind cluster  (available parameters: KIND_CLUSTER_NAME, DOCKER_REPOSITORY, VERSION)
	@if [ "`kind get clusters`" = '' ]; then echo "no kind cluster found" && exit 1; fi
	kind load docker-image --name ${KIND_CLUSTER_NAME} ${DOCKER_REPOSITORY}{{ .ArtifactName }}:${VERSION}

kind: # @HELP build the docker image and loads it into the currently configured kind cluster (available parameters: KIND_CLUSTER_NAME, DOCKER_REPOSITORY, VERSION)
kind: image kind-only