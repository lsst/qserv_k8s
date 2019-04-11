#!/bin/sh

# Start cmsd and xrootd inside pod
# Launch as qserv user

# @author  Fabrice Jammes, IN2P3/SLAC

set -e
# set -x

# Source pathes to eups packages
. /qserv/run/etc/sysconfig/qserv

CONFIG_DIR="/config-etc"
XROOTD_CONFIG="$CONFIG_DIR/xrootd.cf"
XRDSSI_CONFIG="$CONFIG_DIR/xrdssi.cf"
DATA_DIR="/qserv/data"
MYSQLD_DATA_DIR="$DATA_DIR/mysql"
MYSQLD_SOCKET="$MYSQLD_DATA_DIR/mysql.sock"

# INSTANCE_NAME is required by xrdssi plugin to
# choose which type of queries to launch against metadata
if [ "$INSTANCE_NAME" = 'worker' ]; then

    # Wait for mysql to be configured and started
    while true; do
        if mysql --socket "$MYSQLD_SOCKET" --user="$MYSQLD_USER_QSERV"  --skip-column-names \
            -e "SELECT CONCAT('Mariadb is up: ', version())"
        then
            break
        else
            echo "Wait for MySQL startup"
        fi
        sleep 2
    done

    # Write worker id to file
    while true
    do
        WORKER=$(mysql --socket "$MYSQLD_SOCKET" --batch \
        --skip-column-names --user="$MYSQLD_USER_QSERV" -e "SELECT id FROM qservw_worker.Id;")
        if [ -n "$WORKER" ]; then
            break
        fi
    done
    echo "$WORKER" > "/qserv/data/mysql/worker_id.txt"

    # Wait for xrootd master reachability
    until timeout 1 bash -c "cat < /dev/null > /dev/tcp/${XROOTD_DN}/1094"
    do
        echo "waiting for xrootd master (${XROOTD_DN})..."
        sleep 2
    done
    OPT_XRD_SSI="-l @libXrdSsiLog.so -+xrdssi $XRDSSI_CONFIG"
fi


# When at least one of the current pod's containers
# readiness health check pass, then dns name resolve.
until ping -c 1 ${HOSTNAME}.${QSERV_DOMAIN}; do
    echo "waiting for DNS (${HOSTNAME}.${QSERV_DOMAIN})..."
    sleep 2
done

# Start xrootd
#
echo "Start xrootd"
xrootd -c "$XROOTD_CONFIG" -n "$INSTANCE_NAME" -I v4 $OPT_XRD_SSI
