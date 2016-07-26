#!/bin/bash

get_project_dir() {
  local root_project_dir="$1"
  local repo_name="$2"
  echo "$root_project_dir/$repo_name"
}

change_dir_magic() {
  local project_dir="$1"
  cd "$project_dir"; exec "$SHELL"
}

check_master(){
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

fireup_repo() {
  local root_project_dir="$1"
  local github_owner="$2"
  local repo_name="$3"
  local project_dir="$(get_project_dir "$root_project_dir" "$repo_name")"
  if [ ! -d "$project_dir" ]; then
    git clone "git@github.com:$github_owner/$repo_name.git" "$project_dir" || return 1
  fi
  cd "$project_dir"
}

open_in_atom() {
  local project_dir="$1"
  atom "$project_dir"
}

update_node_project() {
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
  echo 'USAGE: fireup <repo-name>'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help      print this help text'
  echo '  -v, --version   print the version'
  echo ''
  echo 'Enviroment:'
  echo '  FIREUP_ROOT_PROJECT_DIR="/path/to/projects" - defaults to "$HOME/Projects/Octoblu"'
  echo '  FIREUP_GITHUB_OWNER="github-user-name" - defaults to "octoblu"'
  echo 'But what does it do? It will:'
  echo '  1. Clone the repo if needed'
  echo '  2. Make sure the project is update to date'
  echo '  3. Open in ATOM'
  echo '  4. Update dependencies'
  echo '     - If node project, remove node_modules, run npm install, and npm-check -u'
}

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

version(){
  local directory="$(script_directory)"
  local version=$(cat "$directory/VERSION")

  echo "$version"
  exit 0
}

main(){
  local cmd="$1"
  local cmd2="$2"

  if [ "$cmd" == '--help' -o "$cmd" == '-h' ]; then
    usage
    exit 0
  fi

  if [ "$cmd" == '--version' -o "$cmd" == '-v' ]; then
    version
    exit 0
  fi

  local repo_name="$cmd"

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

  fireup_repo "$root_project_dir" "$github_owner" "$repo_name"
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

  open_in_atom "$project_dir"

  local project_type="$(get_project_type "$project_dir")"
  if [ "$project_type" == 'node' ]; then
    update_node_project
  fi
  
  change_dir_magic "$project_dir"
}

main "$@"
