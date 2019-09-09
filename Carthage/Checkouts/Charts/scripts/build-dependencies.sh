#!/bin/sh

function build_dependencies {
    
    has_dependencies=$(ls Carthage/Build/**/*.framework 2> /dev/null | wc -l)

    if [ $has_dependencies != 0 ]
    then
        echo "Depencies have already been built."
    else
        echo "Building dependencies..."
        carthage bootstrap
    fi
}

function alert_to_install_carthage {
    echo "error: Carthage was not found! In order to build Charts you need to use Carthage to build its dependencies. Carthage can be downloaded from https://github.com/Carthage/Carthage."
    exit 1
}

if hash carthage 2>/dev/null 
then
    build_dependencies
else
    alert_to_install_carthage
fi
