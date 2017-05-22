iscentos(){
    arg_version=${1:-none}
    if [ -f /etc/redhat-release ]; then
      version=$(cat /etc/redhat-release | grep -oP "[0-9]+\.[0-9]+")
      version_min=$(cat /etc/redhat-release | grep -oP "[0-9]+" | head -1 )
      RELEASE=centos$version
      if [ $arg_version == "none" ]; then
        return
      elif [[ $arg_version == $version || $arg_version == $version_min ]];then
        return
      else
        false
      fi
    fi
    false
}

isubuntu(){
    arg_version=${1:-none}
    if [ -n $(which lsb_release 2> /dev/null) ] && lsb_release -d 2>/dev/null | grep -q "Ubuntu"; then
      version=$(lsb_release -d | grep -oP "[0-9]+\.[0-9]+")
      version_min=$(lsb_release -d | grep -oP "[0-9]+" | head -1)
      RELEASE=ubuntu$version
      if [ $arg_version == "none" ]; then
        return
      elif [[ $arg_version == $version || $arg_version == $version_min ]];then
        return
      else
        false
      fi
    fi
    false
}
error(){
    echo "use the option -h to learn more" >&2         
}

usage(){
    echo "Usage: source /scripts/toolshed/os_detection.sh"
    echo "--help ou -h : displays help"
    echo "-u : displays ubuntu help" 
    echo "-c : displays centos help"
}

isubuntu_help(){
    echo "You can do:"
    echo "    #version is optional"
    echo "    isubuntu"
    echo "    or"
    echo "    isubuntu 16"
    echo "    or"
    echo "    isubuntu 16.04"
}

iscentos_help(){
    echo "You can do:"
    echo "    #version is optional"
    echo "    iscentos"
    echo "    or"
    echo "    iscentos 7"
    echo "    or"
    echo "    iscentos 7.2"
}

# Pas de paramètre 
[[ $# -lt 1 ]] && error

# -o : options courtes 
# -l : options longues 
options=$(getopt -o h,u,c: -l help -- "$@")

set -- $options 

while true; do
    case "$1" in
        -u) isubuntu_help
            shift;;
        -c) iscentos_help
            shift;;
        -h|--help) usage
            shift;;
        --)
            shift
            break;;
        *) error
            shift;;
    esac
done