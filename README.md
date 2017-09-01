# vmware_perl
# Perl scripts for VMware environments

====================================================================================================================
## Filename: get-vmwareinfo.pl
## Author: James Anderton
## Date: 5/5/2012
## Purpose: Take a list of hosts or vm's and print out info about them to either the screen or a csv file

## SETUP REQUIRED:
Edit the line "my @vCenters = ('vc1', 'vc2');" to include your vCenters in fqdn format

'''
Commandline options are as follows:
--host <-Switch from default of looking for vm's to looking for a host
--find $1 <- Tells the script the name of the vm/host to look up
--username <- vCenter username
--password <- password for the user above
--show_location <-Add in vCenter, vDC, Cluster, and host a VM/HOST lives on 
--show_datastores <-Add in the Datastores a host is using or the VM lives on
--show_resources <-Add in CPU, MEMORY, and Storage info about VM/host
--show_uuid <-Add in the unique identifier for the VM 
--output_csv $2 <- Spits out a file named what you tell it

## ================= VM Printout Section
VM:			fq_name
UUID:			uuid
vCENTER:		vCenterHostName
DATACENTER:		DatacenterName
CLUSTER:		ClusterName
HOST:			vmhostname
VMX FILE LOCATION:	vmx_path
IP ADDRESS:		ipaddress
CPU:			cpu
MEMORY:			memory
PROVISIONED STORAGE:	storage
DATASTORES USED:	vmDataStore

## ================ HOST Printout Section

HOST:			vmhostname
VCENTER:		vCenterHostName
CLUSTER:		ClusterName
VM Count:		vm_count
VMS ON HOST:		vm_inventory
HOST CPUS:		host_cpucount
CPUS ALLOCATED:		cpu
HOST MEMORY:		host_memcount
MEMORY ALLOCATED:	memory GB
STORAGE USED by VMS:	storage
HOST WWNS:		host_wwns
'''
======================================================================================================================
