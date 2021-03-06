#!/bin/bash

# LSST Data Management System
# Copyright 2014 LSST Corporation.
#
# This product includes software developed by the
# LSST Project (http://www.lsst.org/).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the LSST License Statement and
# the GNU General Public License along with this program.  If not,
# see <http://www.lsstcorp.org/LegalNotices/>.

# Launch Qserv pods on Kubernetes cluster

# @author  Fabrice Jammes, IN2P3/SLAC

set -e

DIR=$(cd "$(dirname "$0")"; pwd -P)

. "$QSERV_CFG_DIR/env-infra.sh"
. "$QSERV_CFG_DIR/env.sh"

CFG_DIR="${DIR}/yaml"

OUTDIR=$(mktemp -d --tmpdir="/tmp/qserv-deploy" --suffix="-qserv-yaml")

usage() {
  cat << EOD

  Usage: $(basename "$0") [options]

  Available options:
    -h          this message

  Launch Qserv service and pods on Kubernetes

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

"$DIR"/update-configmaps.sh "$OUTDIR"
"$DIR"/create-secrets.sh "$OUTDIR"

echo "Create headless and nodeport services for Qserv"
cp ${CFG_DIR}/qserv-services.yaml "$OUTDIR"

echo "Create statefulsets for Qserv"

# Convert to python by setting first letter to uppercase letter
if [ $KIND ]; then
    INI_KIND="True"
else
    INI_KIND="False"
fi
if [ $GKE ]; then
    INI_GKE="True"
else
    INI_GKE="False"
fi

INI_FILE="${OUTDIR}/statefulset.ini"
WORKER_COUNT=${SIZE_WORKER:-$(echo $WORKERS | wc -w)}
cat << EOF > "$INI_FILE"
[spec]
gke: $INI_GKE
storage_size: $STORAGE_SIZE
mariadb_image: $MARIADB_IMAGE
czar_db_mem_request: $CZAR_DB_MEM_REQUEST
qserv_image: $QSERV_IMAGE
kind: $INI_KIND
replicas: $WORKER_COUNT
repl_image: $REPL_IMAGE
wkr_xrootd_mem_limit: $WKR_XROOTD_MEM_LIMIT
wkr_xrootd_mlock: $WKR_XROOTD_MLOCK
EOF

for service in "czar" "worker" "repl-ctl" "repl-db" "xrootd-mgr"
do
    YAML_TPL="${CFG_DIR}/${service}.tpl.yaml"
    YAML_FILE="${OUTDIR}/${service}.yaml"
    "$DIR"/yaml-builder.py -i "$INI_FILE" -t "$YAML_TPL" -o "$YAML_FILE"
done

kubectl apply -f "${OUTDIR}"
