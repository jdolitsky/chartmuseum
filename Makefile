VERSION ?= 0.12.0
REVISION := $(shell git rev-parse --short HEAD;)

BINDIR      := $(CURDIR)/bin
BINNAME     ?= chartmuseum

#TARGETS     := darwin/amd64 linux/amd64 linux/386 linux/arm linux/arm64 linux/mips64le linux/ppc64le linux/s390x windows/amd64
#TARGET_OBJS ?= darwin-amd64.tar.gz darwin-amd64.tar.gz.sha256sum linux-amd64.tar.gz linux-amd64.tar.gz.sha256sum linux-386.tar.gz linux-386.tar.gz.sha256sum linux-arm.tar.gz linux-arm.tar.gz.sha256sum linux-arm64.tar.gz linux-arm64.tar.gz.sha256sum linux-mips64le.tar.gz linux-mips64le.tar.gz.sha256sum linux-ppc64le.tar.gz linux-ppc64le.tar.gz.sha256sum linux-s390x.tar.gz linux-s390x.tar.gz.sha256sum windows-amd64.zip windows-amd64.zip.sha256sum
TARGETS     := darwin/amd64
TARGET_OBJS ?= darwin-amd64.tar.gz darwin-amd64.tar.gz.sha256sum


DIST_DIRS   := find * -type d -exec


GOBIN         = $(shell go env GOBIN)
ifeq ($(GOBIN),)
GOBIN         = $(shell go env GOPATH)/bin
endif
GOX           = $(GOBIN)/gox

#MOD_PROXY_URL ?= https://gocenter.io

CM_LOADTESTING_HOST ?= http://localhost:8080

$(GOX):
	(cd /; GO111MODULE=on go get -u github.com/mitchellh/gox)

.PHONY: bootstrap
bootstrap: export GO111MODULE=on
bootstrap: export GOPROXY=$(MOD_PROXY_URL)
bootstrap:
	@go mod download && go mod vendor

.PHONY: build
build: build-linux build-mac build-windows build-linux-mips

build-windows: export GOOS=windows
build-windows: export GOARCH=amd64
build-windows: export GO111MODULE=on
build-windows: export GOPROXY=$(MOD_PROXY_URL)
build-windows:
	go build -v --ldflags="-w -X main.Version=$(VERSION) -X main.Revision=$(REVISION)" \
		-o bin/windows/amd64/chartmuseum cmd/chartmuseum/main.go  # windows
	sha256sum bin/windows/amd64/chartmuseum || shasum -a 256 bin/windows/amd64/chartmuseum

build-linux: export GOOS=linux
build-linux: export GOARCH=amd64
build-linux: export CGO_ENABLED=0
build-linux: export GO111MODULE=on
build-linux: export GOPROXY=$(MOD_PROXY_URL)
build-linux:
	go build -v --ldflags="-w -X main.Version=$(VERSION) -X main.Revision=$(REVISION)" \
		-o bin/linux/amd64/chartmuseum cmd/chartmuseum/main.go  # linux
	sha256sum bin/linux/amd64/chartmuseum || shasum -a 256 bin/linux/amd64/chartmuseum

build-linux-mips: export GOOS=linux
build-linux-mips: export GOARCH=mips64le
build-linux-mips: export CGO_ENABLED=0
build-linux-mips: export GO111MODULE=on
build-linux-mips: export GOPROXY=$(MOD_PROXY_URL)
build-linux-mips:
	go build -v --ldflags="-w -X main.Version=$(VERSION) -X main.Revision=$(REVISION)" \
		-o bin/linux/mips64/chartmuseum cmd/chartmuseum/main.go  # linux
	sha256sum bin/linux/mips64/chartmuseum || shasum -a 256 bin/linux/mips64/chartmuseum


build-armv7: export GOOS=linux
build-armv7: export GOARCH=arm
build-armv7: export GOARM=7
build-armv7: export CGO_ENABLED=0
build-armv7: export GO111MODULE=on
build-armv7: export GOPROXY=$(MOD_PROXY_URL)
build-armv7:
	go build -v --ldflags="-w -X main.Version=$(VERSION) -X main.Revision=$(REVISION)" \
		-o bin/linux/armv7/chartmuseum cmd/chartmuseum/main.go  # linux

build-mac: export GOOS=darwin
build-mac: export GOARCH=amd64
build-mac: export CGO_ENABLED=0
build-mac: export GO111MODULE=on
build-mac: export GOPROXY=$(MOD_PROXY_URL)
build-mac:
	go build -v --ldflags="-w -X main.Version=$(VERSION) -X main.Revision=$(REVISION)" \
		-o bin/darwin/amd64/chartmuseum cmd/chartmuseum/main.go # mac osx
	sha256sum bin/darwin/amd64/chartmuseum || shasum -a 256 bin/darwin/amd64/chartmuseum

.PHONY: clean
clean:
	@git status --ignored --short | grep '^!! ' | sed 's/!! //' | xargs rm -rf

.PHONY: setup-test-environment
setup-test-environment:
	@./scripts/setup_test_environment.sh

.PHONY: test
test: export CGO_ENABLED=0
test: export GO111MODULE=on
test: export GOPROXY=$(MOD_PROXY_URL)
test: setup-test-environment
	@./scripts/test.sh

.PHONY: startloadtest
startloadtest:
	@cd loadtesting && pipenv install
	@cd loadtesting && pipenv run locust --host $(CM_LOADTESTING_HOST)

.PHONY: covhtml
covhtml:
	@go tool cover -html=.cover/cover.out

.PHONY: acceptance
acceptance: setup-test-environment
	@./scripts/acceptance.sh

.PHONY: run
run:
	@rm -rf .chartstorage/
	@bin/darwin/amd64/chartmuseum --debug --port=8080 --storage="local" \
		--storage-local-rootdir=".chartstorage/"

.PHONY: tree
tree:
	@tree -I vendor

# https://github.com/hirokidaichi/goviz/pull/8
.PHONY: goviz
goviz:
	#@go get -u github.com/RobotsAndPencils/goviz
	@goviz -i helm.sh/chartmuseum/cmd/chartmuseum -l | dot -Tpng -o goviz.png

.PHONY: release-latest
release-latest:
	@scripts/release.sh latest

.PHONY: release-stable
release-stable:
	@scripts/release.sh $(VERSION)

.PHONY: version-released
version-released:
	@scripts/version_released.sh $(VERSION)

.PHONY: get-version
get-version:
	@echo $(VERSION)

.PHONY: build-cross
build-cross: LDFLAGS += -extldflags "-static"
build-cross: $(GOX)
	GO111MODULE=on CGO_ENABLED=0 $(GOX) -parallel=3 -output="_dist/{{.OS}}-{{.Arch}}/$(BINNAME)" -osarch='$(TARGETS)' $(GOFLAGS) -tags '$(TAGS)' -ldflags '$(LDFLAGS)' ./cmd/chartmuseum

.PHONY: dist
dist:
	( \
		cd _dist && \
		$(DIST_DIRS) cp ../LICENSE {} \; && \
		$(DIST_DIRS) cp ../README.md {} \; && \
		$(DIST_DIRS) tar -zcf chartmuseum-${VERSION}-{}.tar.gz {} \; && \
		$(DIST_DIRS) zip -r chartmuseum-${VERSION}-{}.zip {} \; \
	)

.PHONY: fetch-dist
fetch-dist:
	mkdir -p _dist
	cd _dist && \
	for obj in ${TARGET_OBJS} ; do \
		curl -sSL -o chartmuseum-${VERSION}-$${obj} https://get.helm.sh/chartmuseum-${VERSION}-$${obj} ; \
	done

# The contents of the .sha256sum file are compatible with tools like
# shasum. For example, using the following command will verify
# the file chartmuseum-3.1.0-rc.1-darwin-amd64.tar.gz:
#   shasum -a 256 -c chartmuseum-3.1.0-rc.1-darwin-amd64.tar.gz.sha256sum
.PHONY: checksum
checksum:
	for f in $$(ls _dist/*.{gz,zip} 2>/dev/null) ; do \
		echo "Creating $${f}.sha256sum" ; \
		shasum -a 256 "$${f}" | sed 's/_dist\///' > "$${f}.sha256sum" ; \
	done

.PHONY: sign
sign:
	for f in $$(ls _dist/*.{gz,zip,sha256sum} 2>/dev/null) ; do \
		gpg --armor --detach-sign $${f} ; \
	done

.PHONY: release-notes
release-notes:
	@if [ ! -d "./_dist" ]; then \
		echo "please run 'make fetch-dist' first" && \
		exit 1; \
	fi
	@if [ -z "${PREVIOUS_RELEASE}" ]; then \
		echo "please set PREVIOUS_RELEASE environment variable" \
		&& exit 1; \
	fi

	@./scripts/release-notes.sh ${PREVIOUS_RELEASE} ${VERSION}
