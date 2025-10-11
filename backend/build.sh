#!/bin/bash
RUN_NAME=hertz_service
mkdir -p output/bin
cp script/* output 2>/dev/null
chmod +x output/bootstrap.sh
CGO_ENABLED=0 go build -ldflags="-s -w -X 'share-my-status/version.SysVersion=$(git describe --tags)'" -o output/bin/${RUN_NAME}