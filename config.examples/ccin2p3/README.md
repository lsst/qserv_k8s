# Pre-requisites

## Clone qserv_deploy on a non-afs filesystem

```shell
git clone https://github.com/lsst/qserv_deploy.git $QSERV_DEPLOY
```

## Setup configuration

```shell
export QSERV_CFG_DIR=/qserv/kubernetes/desc
mkdir -p $QSERV_CFG_DIR 
cp -r $QSERV_DEPLOY/config.examples/ccin2p3/* $QSERV_CFG_DIR 
```

Set nodes names in `/qserv/kubernetes/upper/env-infra.sh`

Create gnu-parallel configuration file:
```shell
$QSERV_DEPLOY/rootfs/opt/sysadmin/create-gnuparallel-slf.sh
```

# Setup Kubernetes

Because of Kerberos, the scrips below must be run directly on the host and
not inside the qserv-deploy container.

```
# Source configuration
. $QSERV_CFG_DIR/env_nocontainer.sh

# Create cluster
$QSERV_DEPLOY/rootfs/opt/sysadmin/kube-create.sh

# Destroy cluster
$QSERV_DEPLOY/rootfs/opt/sysadmin/kube-destroy.sh
```
