#!/bin/bash -ex

PY_REQUIRES="requests==2.20.1 robotframework==3.0.4"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/../

if [ "$(uname)" == "Darwin" ]; then
    PLATFORM="darwin"
else
    PLATFORM="linux"
fi

if [ -x "$(command -v busybox)" ]; then
  export IS_BUSYBOX=1
fi

export PATH="$PWD/testbin:$PWD/bin/$PLATFORM/amd64:$PATH"

mkdir -p .robot/

if [ "$IS_BUSYBOX" != "1" ]; then
    export HELM_HOME="$PWD/.helm"
    helm init --client-only
    if [ ! -d .venv/ ]; then
        virtualenv -p $(which python3) .venv/
        .venv/bin/python .venv/bin/pip install $PY_REQUIRES
    fi
    .venv/bin/robot --outputdir=.robot/ acceptance_tests/
else
    robot --outputdir=.robot/ acceptance_tests/
fi
