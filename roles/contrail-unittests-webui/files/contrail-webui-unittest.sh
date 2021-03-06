#!/usr/bin/env bash

set -o pipefail
set -xe

export LOGDIR="$WORKSPACE"/../logs
export TEST_REPORTS_DIR="$WORKSPACE"/../test-reports
export COVERAGE_REPORTS_DIR="$WORKSPACE"/../coverage-reports
mkdir -p "$LOGDIR"
mkdir -p "$TEST_REPORTS_DIR"
mkdir -p "$COVERAGE_REPORTS_DIR"

export REPO_NAME=$PROJECT_NAME

if [ -z $SCONS_JOBS ]; then
    export SCONS_JOBS=1
fi

if [ -z $USER ]; then
    USER=jenkins
fi

if [ -z $REPO_NAME ]; then
    REPO_NAME=contrail-web-core
    echo "Default Repo Name: $REPO_NAME"
fi

function pre_test_setup() {
    #Update the featurePkg path in contrail-web-core/config/config.global.js  with Controller, Storage and Server Manager features
    cd $WORKSPACE/contrail-web-core

    # Controller
    cat config/config.global.js | sed -e "s%/usr/src/contrail/contrail-web-controller%$WORKSPACE/contrail-web-controller%" > $WORKSPACE/contrail-web-core/config/config.global.js.tmp
    cp $WORKSPACE/contrail-web-core/config/config.global.js.tmp $WORKSPACE/contrail-web-core/config/config.global.js
    rm $WORKSPACE/contrail-web-core/config/config.global.js.tmp
    touch config/config.global.js

    cd $WORKSPACE/contrail-web-core
    #fetch dependent packages
    make fetch-pkgs-dev
}

function run_all_webui_tests() {
    #Setup the Prod Environment
    make prod-env REPO=webController
    #Setup the Test Environment
    make test-env REPO=webController

    # Run Controller related Unit Testcase
    cd $WORKSPACE/contrail-web-controller
    ./webroot/test/ui/run_tests.sh 2>&1 | tee $LOGDIR/web_controller_unittests.log

}

function run_webui_controller_tests() {
    cd $WORKSPACE/contrail-web-core

    #Setup the Prod Environment
    make prod-env REPO=webController
    #Setup the Test Environment
    make test-env REPO=webController

    # Run Controller related Unit Testcase
    cd $WORKSPACE/contrail-web-controller
    ./webroot/test/ui/run_tests.sh 2>&1 | tee $LOGDIR/web_controller_unittests.log
}

# Build unittests
function build_unittest() {
    case "$REPO_NAME" in
        "contrail-web-controller")
            echo "Run all UT for Contrail Web Controller repo."
            run_webui_controller_tests
            ;;
        *)
            echo "Run all UT for Contrail Web * repo"
            run_all_webui_tests
            ;;
    esac
}

function copy_reports(){
    cd $WORKSPACE
    report_dir=webroot/test/ui/reports

    echo "info: gathering XML test reports..."
    cp -p contrail-web*/$report_dir/tests/*-test-results.xml $TEST_REPORTS_DIR || true

    echo "info: gathering XML coverage reports..."
    for p in controller ; do
        src_dir=contrail-web-$p/$report_dir/coverage
        cp -p $src_dir/*/phantomjs/cobertura-coverage.xml $COVERAGE_REPORTS_DIR/${p}-cobertura-coverage.xml || true
    done
}

function main() {
    #This installs node, npm and does a fetch_packages, make prod env, test setup
    pre_test_setup

    # run unit test case
    build_unittest $*

    # copy the generated reports to specific directory
    copy_reports
}

env
main $*
echo Success
