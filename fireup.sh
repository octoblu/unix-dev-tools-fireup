#!/bin/bash

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"

  echo "$dir"
}

get_project_dir() {
  local root_project_dir="$1"
  local repo_name="$2"
  echo "$root_project_dir/$repo_name"
}

change_dir_magic() {
  echo '* magically changing to project directory'
  local project_dir="$1"
  cd "$project_dir"; exec "$SHELL"
}

check_master(){
  echo '* checking if master'
  CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
  if [ "$CURRENT_BRANCH" != "master" ]; then
    echo ''
    echo 'ERROR: this project is not in the master branch!'
    echo `git status | head -1`
    echo ''
    exit 1
  fi
}

check_git(){
  echo '* checking git'
  git fetch origin
  local get_log="$(git log HEAD..origin/master --oneline)"
  if [[ -n "$get_log" ]]; then
    echo ''
    echo 'WARNING: this project is behind remote!'
    echo "$get_log"
    echo ''
    local git_pull=''
    read -s -p "press 'y' to pull, any other key to exit"$'\n' -n 1 git_pull
    if [[ "$git_pull" == 'y' ]]; then
      echo 'pulling...'
      git pull
    else
      exit 1
    fi
  fi
}

init_repo() {
  local project_dir="$1"
  local repo_name="$2"
  cat > "$project_dir/LICENSE" <<- EOM
The MIT License (MIT)

Copyright (c) 2016 Octoblu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOM

  echo "# ${repo_name}" > "$project_dir/README.md"
}

create_repo() {
  local create="$1"
  local github_owner="$2"
  local repo_name="$3"
  local project_dir="$4"
  if [ "$create" == "false" ]; then
    echo '* not creating'
    return 1
  fi
  echo '* creating repo'
  mkdir -p "$project_dir" && \
    cd "$project_dir" && \
    git init && \
    init_repo "$project_dir" "$repo_name" && \
    hub create "$github_owner/$repo_name" && \
    git add . && \
    git commit -m "initial commit" && \
    git push --set-upstream origin master
}

clone_repo() {
  local github_owner="$1"
  local repo_name="$2"
  local project_dir="$3"
  git clone "git@github.com:$github_owner/$repo_name.git" "$project_dir" 2> /dev/null
}

fireup_repo() {
  local root_project_dir="$1"
  local github_owner="$2"
  local repo_name="$3"
  local create="$4"
  echo '* firing up'
  local project_dir="$(get_project_dir "$root_project_dir" "$repo_name")"
  if [ ! -d "$project_dir" ]; then
     clone_repo "$github_owner" "$repo_name" "$project_dir" || \
      create_repo "$create" "$github_owner" "$repo_name" "$project_dir" || return 1
  fi
  cd "$project_dir"
}

open_in_atom() {
  local project_dir="$1"
  local add_to_atom="$2"
  if [ "$add_to_atom" == "true" ]; then
    echo '* adding to atom window'
    atom "$project_dir" --add
  else
    echo '* opening in atom window'
    atom "$project_dir"
  fi
}

update_node_project() {
  echo '* updating node project'
  rm -rf node_modules && \
    npm install && \
    npm-check -u
}

get_project_type() {
  local project_dir="$1"
  if [ -f "$project_dir/package.json" ]; then
    echo 'node'
    return 0
  fi
  echo 'other'
}

usage(){
  echo 'USAGE: fireup <repo-name> [options]'
  echo ''
  echo 'Arguments:'
  echo '  -a, --add          add project to the last open atom window'
  echo '  -c, --create       create a public project if it does not exist'
  echo '  -s, --skip-upgrade skip upgrading project'
  echo '  -h, --help         print this help text'
  echo '  -v, --version      print the version'
  echo ''
  echo 'Enviroment:'
  echo '  FIREUP_ROOT_PROJECT_DIR="/path/to/projects" - defaults to "$HOME/Projects/Octoblu"'
  echo '  FIREUP_GITHUB_OWNER="github-user-name" - defaults to "octoblu"'
  echo 'But what does it do? It will:'
  echo '  1. Clone the repo if needed'
  echo '  1. Create repo if "--create", or "-c" is set. This will be public.'
  echo '  2. Make sure the project is update to date'
  echo '  3. Open in ATOM window'
  echo '     - if "--add" or "-a" is set it will add to the latest atom window'
  echo '  4. Update dependencies unless "--skip-upgrade", or "-s" is set.'
  echo '     - If node project, remove node_modules, run npm install, and npm-check -u'
}

version(){
  local directory="$(script_directory)"
  local version=$(cat "$directory/VERSION")

  echo "$version"
  exit 0
}

main(){
  local add_to_atom="false"
  local skip_upgrade="false"
  local create="false"
  local repo_name="$1"; shift;
  while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      -a | --add)
        add_to_atom="true"
        ;;
      -s | --skip-upgrade)
        skip_upgrade="true"
        ;;
      -c | --create)
        create="true"
        ;;
      *)
        echo "ERROR: unknown parameter \"$PARAM\""
        usage
        exit 1
        ;;
    esac
    shift
  done

  if [ -z "$(which hub)" ]; then
    echo 'Missing required dependency "hub"'
    exit 1
  fi

  if [ -z "$repo_name" ]; then
    usage
    echo 'Missing repo-name as first argument'
    exit 1
  fi

  local root_project_dir="$FIREUP_ROOT_PROJECT_DIR"
  if [ -z "$root_project_dir" ]; then
    root_project_dir="$HOME/Projects/Octoblu"
  fi

  if [ ! -d "$root_project_dir" ]; then
    echo "Invalid Root Project directory, $root_project_dir"
    exit 1
  fi

  local github_owner="$FIREUP_GITHUB_OWNER"
  if [ -z "$github_owner" ]; then
    github_owner='octoblu'
  fi

  local project_dir="$(get_project_dir "$root_project_dir" "$repo_name")"

  fireup_repo "$root_project_dir" "$github_owner" "$repo_name" "$create"
  local fireup_repo_okay="$?"
  if [ "$fireup_repo_okay" != "0" ]; then
    echo 'Unable to fireup the project'
    exit 1
  fi

  check_master
  local master_okay="$?"
  if [ "$master_okay" != "0" ]; then
    echo '[WARNING] You are not on the master branch'
  fi

  check_git
  local git_okay="$?"
  if [ "$git_okay" != "0" ]; then
    echo 'Git syncing error, exiting'
    exit 1
  fi

  open_in_atom "$project_dir" "$add_to_atom"

  if [ "$skip_upgrade" != "true" ]; then
    local project_type="$(get_project_type "$project_dir")"
    if [ "$project_type" == 'node' ]; then
      update_node_project
    fi
  fi

  change_dir_magic "$project_dir"
}

main "$@"
