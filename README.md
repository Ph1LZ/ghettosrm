GHETTO-SRM
Version 1.0
Author: Phil Leblond

This script will be use for Testing our DR recovery plan.
A Primary and a Secondary Site needs to be setted up with Netapp Snapmirror configured on both sites.
The script will break the snapmirror relationships at the Secondary Site.
It will add the replicated Datastores on the Secondary Site ESXi Servers.
It will register all replicated Virtual Machines automatically on the VMWare Cluster.

DR Site is now Ready.

