#!/usr/bin/env python

"""
Boot instances from an image already created containing Docker
in OpenStack infrastructure, and use cloud config to create users
on virtual machines

Script performs these tasks:
  - launch instances from image and manage ssh key
  - create gateway vm
  - check for available floating ip address
  - add it to gateway
  - create users via cloud-init
  - update /etc/hosts on each VM
  - print ssh client config

@author  Oualid Achbal, IN2P3
"""

from __future__ import absolute_import, division, print_function

# -------------------------------
#  Imports of standard modules --
# -------------------------------
import argparse
import logging
import sys

# ----------------------------
# Imports for other modules --
# ----------------------------
import cloudmanager

# -----------------------
# Exported definitions --
# -----------------------


def main():

    userdata = cloudManager.build_cloudconfig()

    # Create instances list
    instances = []
    qserv_instances = []

    if args.cleanup:
        cloudManager.nova_servers_cleanup()

    # Create gateway instance and add floating_ip to it
    instance_name = "gateway"
    gateway_instance = cloudManager.nova_servers_create(instance_name,
                                                        userdata)
    cloudManager.wait_active(gateway_instance)

    # Attach a floating ip address to gateway
    floating_ip = cloudManager.attach_floating_ip(gateway_instance)

    # Manage ssh security group
    if cloudManager.ssh_security_group:
        gateway_instance.add_security_group(cloudManager.ssh_security_group)

    instances.append(gateway_instance)

    instance_name = "master-1"
    instance = cloudManager.nova_servers_create(instance_name,
                                                userdata)
    qserv_instances.append(instance)

    # Create worker instances
    for instance_id in range(1, cloudManager.nbWorker+1):
        instance_name = 'worker-{}'.format(instance_id)
        instance = cloudManager.nova_servers_create(instance_name,
                                                    userdata)
        qserv_instances.append(instance)

    instances = instances + qserv_instances

    # Create orchestration instances
    orch_node_suffix = "orchestra"
    for instance_id in range(1, cloudManager.nbOrchestrator+1):
        instance_name = '{}-{}'.format(orch_node_suffix, instance_id)
        instance = cloudManager.nova_servers_create(instance_name,
                                                    userdata)
        instances.append(instance)
    for instance in instances:
        cloudManager.wait_active(instance)

    envfile_tpl = '''# Parameters related to Openstack instructure
# WARN: automatically generated by provisionning script, do not edit

# All host have same prefix
HOSTNAME_TPL="{hostname_tpl}"

# First and last id for worker node names
WORKER_FIRST_ID=1
WORKER_LAST_ID="{worker_last_id}"

# Used for ssh access
MASTER="${{HOSTNAME_TPL}}master-1"

# Used for ssh access
WORKERS=$(seq --format "${{HOSTNAME_TPL}}worker-%g" \
    --separator=' ' "$WORKER_FIRST_ID" "$WORKER_LAST_ID")

# Used for ssh access to Kubernetes master
ORCHESTRATOR="${{HOSTNAME_TPL}}{orch_node_suffix}-1"
'''

    envfile = envfile_tpl.format(swarm_last_id=cloudManager.nbOrchestrator,
                                 hostname_tpl=cloudManager.get_hostname_tpl(),
                                 orch_node_suffix=orch_node_suffix,
                                 worker_last_id=cloudManager.nbWorker)
    filep = open('env-infrastructure.sh', 'w')
    filep.write(envfile)
    filep.close()

    cloudManager.print_ssh_config(instances, floating_ip)

    # Wait for cloud config completion for all machines
    for instance in instances:
        cloudManager.detect_end_cloud_config(instance)

    cloudManager.check_ssh_up(instances)

    cloudManager.update_etc_hosts(instances)

    # Attach and mount cinder volumes
    if cloudManager.volume_names:
        if len(cloudManager.volume_names) != len(qserv_instances):
            logging.error("Data volumes: %s", cloudManager.volume_names)
            raise ValueError("Invalid number of cinder data volumes")
        for (instance, vol_name) in zip(qserv_instances,
                                        cloudManager.volume_names):
            cloudManager.nova_create_server_volume(instance, vol_name)
        cloudManager.mount_volume(qserv_instances)

    logging.debug("SUCCESS: Qserv Openstack cluster is up")


if __name__ == "__main__":
    try:
        # Define command-line arguments
        parser = argparse.ArgumentParser(
            description='Boot instances from image containing Docker.')

        cloudmanager.add_parser_args(parser)
        args = parser.parse_args()

        cloudmanager.config_logger(args.verbose, args.verboseAll)

        cloudManager = cloudmanager.CloudManager(
            config_file_name=args.configFile,
            add_ssh_key=True)

        main()
    except Exception as exc:
        logging.critical('Exception occurred: %s', exc, exc_info=True)
        sys.exit(1)
