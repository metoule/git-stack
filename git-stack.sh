#!/bin/bash

# -----------------------------------------------------------------------
# Function to create a new stack
# -----------------------------------------------------------------------

function usage_create() {
    echo "Usage: $0 create -m <commit message>"
}

function create() {
    local OPTARG
    local msg
    while getopts ":m:" opt; do
        case $opt in
            m)
                msg=$OPTARG
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage_create
                return 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage_create
                return 1
                ;;
        esac
    done
    
    if [ -z "$msg" ]; then
        usage_create
        return 1
    fi

    # replace spaces and special characters with underscores; lowercase
    local branch=$(echo $msg | sed 's/[^a-zA-Z0-9]/_/g' | tr -dc '[:alnum:]_' | tr '[:upper:]' '[:lower:]')

    branch="${GIT_STACK_PREFIX}${branch}"
    
    echo "Creating git branch $branch"
    git checkout -b $branch

    echo "Adding all files and committing changes"
    git add . && git commit -m "$msg"
}

# -----------------------------------------------------------------------
# Check the prerequisites to ensure the script will run properly
# -----------------------------------------------------------------------
function check_prerequisites() {
    # check for environment variable name GIT_STACK_PREFIX
    if [ -z "$GIT_STACK_PREFIX" ]; then
        echo "GIT_STACK_PREFIX is not set. Set it to your branches prefix (e.g. yourname/)"
        return 1
    fi

    if ! [ -x "$(command -v git)" ]; then
        echo "git is not installed"
        return 1
    fi
    
    if ! [ -x "$(command -v gh)" ]; then
        echo "GihHub CLI is not installed. See https://github.com/cli/cli#installation"
        return 1
    fi

    return 0
}

if ! check_prerequisites; then
    exit 1
fi

# -----------------------------------------------------------------------
# Parse the command and delegate to the appropriate function
# -----------------------------------------------------------------------

function usage() {
    echo "Usage: $0 <command> [options]"
    echo "Commands:"
    echo "  create"
}

case "$1" in
    create)
        shift
        create "$@"
        ;;
    *)
        usage
        exit 1
        ;;
esac
