#!/bin/bash

set -e

MAX_BRANCH_LENGTH=50

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
    
    # replace all non-alphanumeric characters with an underscore
    # convert to lowercase
    # remove leading and trailing underscores
    local branch=$(echo $msg \
        | sed 's/[^a-zA-Z0-9]/_/g' \
        | tr -dc '[:alnum:]_' \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/^_*//' \
        | sed 's/_$//' \
    )
    
    # prefix with the branch prefix and append the date
    branch="${GIT_BRANCH_PREFIX}$(date +%Y%m%d)_${branch}"

    # if branch is longer than maximum length in characters, truncate it with a 8 character MD5 hash
    if [ ${#branch} -gt $MAX_BRANCH_LENGTH ]; then
        branch="${branch:0:$MAX_BRANCH_LENGTH}_$(echo $msg | md5sum | cut -c1-8)"
    fi

    # replace multiple underscores with a single underscore
    branch=$(echo $branch | tr -s '_')
       
    echo "Creating git branch $branch"
    git checkout -q -b $branch

    echo "Adding all files and committing changes"
    git add . && git commit -q -m "$msg"
}

# -----------------------------------------------------------------------
# Function to submit a stack
# -----------------------------------------------------------------------
function usage_submit() {
    echo "Usage: $0 submit"
}

function submit() {
    local OPTARG
    while getopts ":" opt; do
        case $opt in
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage_submit
                return 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage_submit
                return 1
                ;;
        esac
    done

    echo "Pushing branch to remote"
    git push -q -u origin $(git branch --show-current)

    echo "Creating pull request"
    gh pr create --fill -w
}

# -----------------------------------------------------------------------
# Check the prerequisites to ensure the script will run properly
# -----------------------------------------------------------------------
function check_prerequisites() {
    # check for environment variable name GIT_BRANCH_PREFIX
    if [ -z "$GIT_BRANCH_PREFIX" ]; then
        echo "GIT_BRANCH_PREFIX is not set. Set it to your branches prefix (e.g. yourname/)"
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
    
    if ! gh auth status &>/dev/null; then
        echo "GitHub CLI is not authenticated. Please run 'gh auth login' to authenticate."
        return 1
    fi

    return 0
}

if ! check_prerequisites; then
    exit 1
fi

# -----------------------------------------------------------------------
# Function to sync and close branches with closed PRs
# -----------------------------------------------------------------------
function usage_sync() {
    echo "Usage: $0 sync"
}

function sync() {
    local OPTARG
    while getopts ":" opt; do
        case $opt in
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage_sync
                return 1
                ;;
        esac
    done

    echo "Fetching latest changes from remote"
    git fetch -q --all --prune

    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

    echo "Checking for closed PRs and removing corresponding local branches"
    for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
        # Skip master branch
        if [[ "$branch" == "$main_branch" ]]; then
            continue
        fi

        # Check if the branch has a closed PR
        pr_info=$(gh pr view "$branch" --json state,url -q '{state: .state, url: .url}' 2>/dev/null || echo '{"state":"LOCAL"}')
        pr_state=$(echo $pr_info | jq -r '.state')
        pr_url=$(echo $pr_info | jq -r '.url // ""')
        
        if [[ "$pr_state" == "CLOSED" || "$pr_state" == "MERGED" ]]; then
            echo "  $branch [$pr_state] $pr_url"
            
            if [[ "$branch" == "$(git rev-parse --abbrev-ref HEAD)" ]]; then
                echo "    -> Closed PR: switching to $main_branch."
                git checkout -q $main_branch
            fi

            echo "    -> Closed PR: removing local branch"
            git branch -q -D "$branch"
        fi
    done

    echo "Pulling latest changes from remote"
    git pull -q --prune

    echo "Sync complete"
}

# -----------------------------------------------------------------------
# Parse the command and delegate to the appropriate function
# -----------------------------------------------------------------------

function usage() {
    echo "Usage: $0 <command> [options]"
    echo "Commands:"
    echo "  create"
    echo "  submit"
    echo "  sync"
}

case "$1" in
    create)
        shift
        create "$@"
        ;;
    submit)
        shift
        submit "$@"
        ;;
    sync)
        shift
        sync "$@"
        ;;
    *)
        usage
        exit 1
        ;;
esac
