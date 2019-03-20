#!/bin/sh

# Resize node pools for GKE cluster

# @author  Fabrice Jammes, IN2P3/SLAC

set -e
set -x

DIR=$(cd "$(dirname "$0")"; pwd -P)
. "$QSERV_CFG_DIR/env-infra.sh"

usage() {
  cat << EOD

  Usage: $(basename "$0") [options]

  Available options:
    -h          this message

  Resize qserv node pools to value set in $\\SIZE_WORKER \\SIZE_CZAR \
  (see /etc/qserv-deploy/) for GKE cluster

EOD
}

# get the options
while getopts h c ; do
    case $c in
        h) usage ; exit 0 ;;
        \?) usage ; exit 2 ;;
    esac
done
shift "$((OPTIND-1))"

if [ $# -ne 0 ] ; then
    usage
    exit 2
fi

"$DIR/resize-nodepool.sh" "pool-czar" "$SIZE_CZAR" 
"$DIR/resize-nodepool.sh" "default-pool" "$SIZE_WORKER"
