#!/usr/bin/env bash

##########################################################################
# install.sh
# for centos 7.x
# author : yong.ran@cdjdgm.com
# require : docker and docker-compose
##########################################################################

# set -x
set -e

# set author info
date1=`date "+%Y-%m-%d %H:%M:%S"`
date2=`date "+%Y%m%d%H%M%S"`
author="yong.ran@cdjdgm.com"

set -o noglob

# font and color 
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
white=$(tput setaf 7)

# header and logging
header() { printf "\n${underline}${bold}${blue}> %s${reset}\n" "$@"; }
header2() { printf "\n${underline}${bold}${blue}>> %s${reset}\n" "$@"; }
info() { printf "${white}➜ %s${reset}\n" "$@"; }
warn() { printf "${yellow}➜ %s${reset}\n" "$@"; }
error() { printf "${red}✖ %s${reset}\n" "$@"; }
success() { printf "${green}✔ %s${reset}\n" "$@"; }
usage() { printf "\n${underline}${bold}${blue}Usage:${reset} ${blue}%s${reset}\n" "$@"; }

trap "error '******* ERROR: Something went wrong.*******'; exit 1" sigterm
trap "error '******* Caught sigint signal. Stopping...*******'; exit 2" sigint

set +o noglob

# entry base dir
pwd=`pwd`
base_dir="${pwd}"
source="$0"
while [ -h "$source" ]; do
    base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$base_dir/$source"
done
base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
cd "${base_dir}"

# envirionment
if [ -r "${base_dir}/.env" ]; then
    while read line; do
        eval "$line";
    done < "${base_dir}/.env"
fi
if [ -r "${base_dir}/keepalived.env" ]; then
    while read line; do
        eval "$line";
    done < "${base_dir}/keepalived.env"
fi

# args flag
arg_help=
arg_install=
arg_uninstall=
arg_empty=true

# parse parameter
# echo $@
# define options, -o : short options, -a : simple mode for long options (starts with -), -l : long options
# no colon after, indicating no parameter
# followed by a colon to indicate that there is a required parameter
# followed by two colons to indicate that there is an optional parameter (the optional parameter must be next to the option)
# -n information on error
# -- it is also an option. for example, to create a directory named "-f", "mkdir -- -f" will be used
# $@ take the parameter list from the command line
# args=`getopt -o ab:c:: -a -l apple,banana:,cherry:: -n "${source}" -- "$@"`
args=`getopt -o h -a -l help,install,uninstall -n "${source}" -- "$@"`
# terminate the execution when there is an error in the execution of getopt
if [ $? != 0 ]; then
    error "terminating..." >&2
    exit 1
fi
# echo ${args}
# reorder parameters(The purpose of using eval is to prevent the shell command in the parameter from being extended by mistake)
eval set -- "${args}"
# handling specific options
while true
do
    case "$1" in
        -h | --help | -help)
            info "option -h|--help"
            arg_help=true
            arg_empty=false
            shift
            ;;
        --install | -install)
            info "option --install"
            arg_install=true
            arg_empty=false
            shift
            ;;
        --uninstall | -uninstall)
            info "option --uninstall"
            arg_uninstall=true
            arg_empty=false
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            error "Internal error!"
            exit 1
            ;;
    esac
done
# display parameters other than options (parameters without options will be last)
# arg is the built-in variable of getopt. the value in arg is $@ (the parameter passed in from the command line) after processing
for arg do
   warn "$arg";
done

##########################################################################

# show usage
usage=$"`basename $0` [-h|--help] [--install] [--uninstall]
       [-h|--help]
                  show help info.
       [--install]
                  install application.
       [--uninstall]
                  uninstall application.
"

# install
fun_install() {
    header "install application : "

    info "deploy application"
    "${base_dir}"/deploy.sh --init
    "${base_dir}"/deploy.sh --load="${base_dir}"/images.tgz

    info "config keepalived.conf"
    cp -f "${base_dir}"/volume/keepalived/conf/keepalived.tmpl "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_BIND_INTERFACE}/${KEEPALIVED_BIND_INTERFACE}/g"        "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_MASTER_STATE}/${KEEPALIVED_MASTER_STATE}/g"            "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_BACKUP_STATE}/${KEEPALIVED_BACKUP_STATE}/g"            "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_VIRTUAL_ROUTER_ID}/${KEEPALIVED_VIRTUAL_ROUTER_ID}/g"  "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_MASTER_PRIORITY}/${KEEPALIVED_MASTER_PRIORITY}/g"      "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_BACKUP_PRIORITY}/${KEEPALIVED_BACKUP_PRIORITY}/g"      "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_MASTER_IP}/${KEEPALIVED_MASTER_IP}/g"                  "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "s/{KEEPALIVED_BACKUP_IP}/${KEEPALIVED_BACKUP_IP}/g"                  "${base_dir}"/volume/keepalived/conf/keepalived.conf
    sed -i "/ens33:vip:/d"                                                       "${base_dir}"/volume/keepalived/conf/keepalived.conf
    OLD_IFS="$IFS" && IFS="," && VIP_ARR=(${KEEPALIVED_VIRTUAL_IPS}) && IFS="$OLD_IFS"
    for idx in ${!VIP_ARR[@]}; do
        OLD_IFS="$IFS" && IFS=":" && DEV_IP=(${VIP_ARR[${idx}]}) && IFS="$OLD_IFS"
        if [ ${#DEV_IP[@]} -ne 2 ]; then
            continue;
        fi
        sed -i "/ens33:vip$/ a \        ${DEV_IP[1]} dev ${DEV_IP[0]} label ${DEV_IP[0]}:vip:${idx}" "${base_dir}"/volume/keepalived/conf/keepalived.conf
    done

    #info "setup application"
    #"${base_dir}"/compose.sh --setup

    echo ""
    success "successfully installed application."

    return 0
}

# uninstall
fun_uninstall() {
    header "uninstall application : "

    info "down application"
    "${base_dir}"/compose.sh --down

    #info "remove images"
    #result=$(docker images -q --filter reference="registry.cdjdgm.com/*/*:*")
    #if [ ! "x${result}" == "x" ]; then
    #    docker images -q --filter reference="registry.cdjdgm.com/*/*:*" | xargs docker rmi -f || true
    #fi

    echo ""
    success "successfully uninstalled application."

    return 0
}

##########################################################################

# argument is empty
if [ "x${arg_empty}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# show usage
if [ "x${arg_help}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# either install or uninstall must be entered
if [[ "x${arg_install}" == "xfalse" && "x${arg_uninstall}" == "xfalse" ]]; then
    error "either install or uninstall must be entered"
    usage "$usage";
    exit 1
fi

# cannot enter install and uninstall at the same time
if [[ "x${arg_install}" == "xtrue" && "x${arg_uninstall}" == "xtrue" ]]; then
    error "cannot enter install and uninstall at the same time"
    usage "$usage";
    exit 1
fi

# install
if [ "x${arg_install}" == "xtrue" ]; then
    fun_install;
fi

# uninstall
if [ "x${arg_uninstall}" == "xtrue" ]; then
    fun_uninstall;
fi

echo ""

# exit $?
