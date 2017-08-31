#!/usr/bin/perl
use strict;
use warnings;
###############################################################################################################################################################
#
#	Filename: get-vhost.pl
#	Author:	James Anderton
#	Date: 5/5/2012
#	Purpose: Take a list of vm's or hosts and print out important resource or location data about them
#
#
###############################################################################################################################################################


#####Reference vmware sdk module
use FindBin;
use lib "$FindBin::Bin/../";
use lib "/usr/lib/vmware-vcli/apps";
use Data::Dumper;

use VMware::VIRuntime; #***Found out the hard way, VMware broke thread safeness of very basic perl functions by re-writing them in their library***#
use AppUtil::HostUtil;

###########################################
# Debug Printing on/off
#
my $DEBUG=0;
#my $DEBUG=1;
###########################################

############Initialize Variables########################################################
my %opt = (
	host =>{
	type => "",
	variable => "VI_ENTITY",
	help => "This allows you to search for hosts",
	required => 0,
	},#endOpt
	find =>{
	type => "=s",
	help => "Short name of VM or Host you are querying about",
	required => 1,
	},#endOpt
        show_location =>{
        type => "",
        help => "Show the cluster, datacenter, vCenter the item searched resides in.",
        required => 0,
        },#endOpt
	show_resources =>{
        type => "",
        help => "Show the CPUs, Memory, and the Provisioned Storage in MB for a VM or Host and how many VMs are on the host and which ones.",
        required => 0,
        },#endOpt
        output_csv =>{
        type => "=s",
        help => "Name you want for file outputted as csv.",
        required => 0,
        },#endOpt
        show_datastores =>{
        type => "",
        help => "Show the Datastores available in the cluster a host resides in and their available free space.",
        required => 0,
        },#endOpt	
        show_uuid =>{
        type => "",
        help => "Show the UUID of the VM.",
        required => 0,
        }#endOpt
);

######setup commandline args
Opts::add_options(%opt);
Opts::parse();
Opts::validate();
my $find_host = Opts::get_option('host'); 
my $vm_name = Opts::get_option('find');
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $show_location = Opts::get_option('show_location');
my $show_datastores = Opts::get_option('show_datastores');
my $show_resources = Opts::get_option('show_resources');
my $ofname = Opts::get_option('output_csv');
my $show_uuid = Opts::get_option('show_uuid');
my ($entity_type, $vm_view, $vmhost, $vmhostname, $vmDataStore, $host, $host_view, $host_views, $vCenter_view, $vCenterIP, $vCenterHostName, $session1, $DatacenterName, $ClusterName, $DatastoreName, %datastore_map, $datastore_views, $cpu, $memory, $storage, $ipaddress, $vmx_path, $vm_count, $inventory, $vm_inventory,$hbadapters,$host_wwns,$host_cpucount,$host_memcount, $uuid, $fq_name);
my @vCenters = ('vc1', 'vc2');

#####################################################################################################################################
# If the $vm_name is the FQDN this will change it to the short name for VM requests but not for host inquiries  (DKJ)
if(!$find_host) { 
my @fq_name_array = split(/,/,$vm_name);
my @original_vm_name = split(/\./,$vm_name);
$fq_name = $fq_name_array[0];
$vm_name = $original_vm_name[0];
#print "The server FQDN = $fq_name\n";
                }
else {$fq_name = $vm_name}
####################################################################################################################################
#
#	Sub Main
#
#########################################################################################

#dim error checkers
my ($err, $err1, $err2, $err3, $err4, $err5, $err6);
$err=-1;
$err1=-1;
$err2=-1;
$err3=-1;
$err4=-1;
$err5=-1;
$err6=-1;

####If host switch isnt set, default entity_type to VM
if(!$find_host){
	$entity_type = "VM";
} else {
	$entity_type = "HostSystem";
	chomp($vm_name);
	$vmhostname =$vm_name;
	if($DEBUG){print "DEBUG::FIND $vmhostname ::\n"}
	$err=0;
}#endIF

#loop through known vCenters and search for guests and their hosts.
foreach (@vCenters){
	
	#connect to servers one at a time through foreach loop
	$session1 = Vim->new(service_url => 'https://'.$_ .'/sdk');
	$session1->login(
        	user_name => $username,
        	password => $password);
	if ($DEBUG){print "Logged In to $_.\n"}
	
	#######IF_Host then only pull host related info
	if ($find_host){
        	
		####Test if host exists on the network because this script dies if the host is disconnected from vCenter
		#my $test_conn=`ssh root\@$vmhostname -q "uptime"`;
		#if (!$test_conn){ die "Server must be reachable on the network or lookups will fail."};
		system("ping -c 1 -q -W 10 $vmhostname > /dev/null 2>&1") == 0 or die "Server $vmhostname must be reachable on the network or lookups will fail. Failure = $?";		

		####Get Host Name
                if ($DEBUG){print "Calling get_host\n"}
		$err = &get_host();
                if ($DEBUG){print "err = $err . . .\n";}
	   if ($err ==0){	
		####Get Cluster Name that Host Resides in
		if ($show_location){
			####Get vCenter the Host resides in
			if ($DEBUG){print "Calling get_vCenterIP\n"}
			$err1 = &get_vCenterIP();
			
			####Get the Cluster the Host resides in
			if ($DEBUG){print "Calling get_Cluster\n"}
        	        $err2 = &get_Cluster($host_view->parent);
                	if ($DEBUG){print "err1 = $err1 . . . .\n";}
	  	}#endIF

		####Get Host Info like vm count, vm names, mem, cpu, storage counts
		if ($show_resources){
			if ($DEBUG){print "Calling get_hostinfo\n"}
			$err3 = &get_hostinfo();
			if ($DEBUG){print "err2 = $err2 . . .\n";}
		}#endIF

		####Get Cluster Datastores				
		if ($show_datastores){
			$err4 = &get_Datastores();
			if ($DEBUG){print "err5 = $err5 . . . .\n";}
		}#endIF
	   } else {
		next; #####If host isnt found in get_host skip to the next vCenter in the loop
	   }#endIF
	last if $err == 0;
	} else {	

	####If user specified a VM entity pull the VM info, otherwise 
	#if they entered a HostSystem Entity skip to get_Host section
	if($entity_type eq "VM"){
		####Get VM info
		($err) = &get_view();
		if ($DEBUG){print "err0 = $err ...\n";}
	}#endIF
	if($err == 0) {
		####Get Host Name
		$err1 = &get_host();
		if ($DEBUG){print "err1 = $err1 . . .\n";}
		
		#####IF getting the host worked and show_location is set, continue
		if($err1 == 0 && $show_location){
			####Get vCenter IP/Hostname
			$err2 = &get_vCenterIP();
			if ($DEBUG){print "err2 = $err2 . . . .\n";}
				
			####Get Datacenter Name that VM Resides in
			$err3 = &get_Datacenter($host_view->parent);
			if ($DEBUG){print "err3 = $err3 . . . .\n";}

			####Get Cluster Name that VM Resides in
			$err4 = &get_Cluster($host_view->parent);
			if ($DEBUG){print "err4 = $err4 . . . .\n";}

			####Get Cluster Datastores				
			if ($show_datastores){
				$err5 = &get_Datastores();
				if ($DEBUG){print "err5 = $err5 . . . .\n";}
			}#endIF

			#####IF show_resources flag set get them
			if ($show_resources){
				####Get Resources
	                        $err6 = &get_Resources();
	                        if ($DEBUG){print "err6 = $err6 . . . .\n";}
			}#endIF
		}#endIF1

	}else{
		next #####If vm isnt found in get_view skip to the next vCenter in the loop
	}#endIF0

	###If we found our target stop looping
	last if $err1 == 0;
	}#endIF_host
}#endForEach

####If the VM was found, build a printout
if($err == 1 || $err1 == 1){
	print "Server $vm_name  not found in any of the vCenters specified.\n";
} else {
	####if output_csv is set then print records to a file in csv format
	if($ofname){
		&output2csv();
	}else{
		&output2screen();
	}#endIF
}#endIF

#run Garbage Collection
&clean_objects();

#disconnect from server
Util::disconnect();

#########################################################################################
#
#	Sub get_view
#
#########################################################################################
sub get_view(){

	#connect to vCenter or host specified with --server arg
	#Util::connect();
	
	#####Pull the inventory of the VirtualMachine entities and filter for the vm specified via commandline
	##### and set a variable equal to the view object it returns
	$vm_view = $session1->find_entity_view(
	view_type => 'VirtualMachine',
	filter => {'name' => qr/^$vm_name$/i},
	properties => ["name", "runtime", "datastore", "summary", "guest"],
	);
	#####Take the view object and pull the reference to the host that the vm is sitting on and print it.
	if ($vm_view){
		$vmhost = $vm_view->runtime->host;
		$vmhostname = $session1->get_view(mo_ref => $vmhost)->name;
		
		######Pull all the Datastores that the VM has Disks stored on
		my $vmDatastore_view = $session1->get_views(mo_ref_array => $vm_view->get_property('datastore'));
		foreach (@$vmDatastore_view){
			my $vmSummary=$_->summary;
			$vmDataStore.=$_->name . "\t  ";   # added 2 spaces after the tab so the datastores will have spaces between them in a csv file (DKJ)
		}#endForEach
		
		####Pull the path to the vmx file and ipaddress
		$vmx_path=$vm_view->summary->config->vmPathName;
		$ipaddress=$vm_view->summary->guest->ipAddress;
		$uuid=$vm_view->summary->config->instanceUuid;
		if ($DEBUG){
			print "The guest $vm_name resides on $vmhostname\n";
		}#endIF
	}#endIF

	if ($vmhostname){
		return("0");
	} else {
		return("1");
	}#endIF
}#endSub
###########################################################################################

###########################################################################################
#
#	Sub get_host
#
###########################################################################################
sub get_host(){
#Purpose:Take the hostname and pull the view object for it

	#####If the --host flag was not set just process it using the moref passed from the get_view for the virtual machine
	if ($vmhostname ne "" ){
		if (!$find_host){
			$host_view = $session1->get_view(mo_ref => $vmhost);
			return("0");
		}else{		
			if ($DEBUG){   
	                        print "DEBUG::hostname $vmhostname ::\n";
			}#endIF

		######Otherwise connect to the current vCenter and look for a host with the name provided in the --find field from the command line
			if ($vmhostname eq "ALL"){
				$host_views = $session1->find_entity_views(
                                                view_type => 'HostSystem',
                                                properties=>["name", "parent", "datastore","vm","systemResources","configManager","hardware"]);
			}else{
				$host_views = $session1->find_entity_views(
						view_type => 'HostSystem', 
						filter => {'name' => qr/^$vmhostname$/i}, 
						properties=>["name", "parent", "datastore","vm","systemResources","configManager","hardware"]);	
				if ($DEBUG){
					print "DEBUG::Host_Views @$host_views ::\n";
				}#endIF

				####### For each host found see if its name property matches the --find field from the command line and return 0 if successful or 1 for fail
				foreach (@$host_views){
					if ($DEBUG){
						#print "DEBUG entity:: " . Dumper(\%$_) . " ::\n";	
						print "DEBUG::Host_Views " . $_->name . " ::\n";
					}#endIF

					if ($_->name =~ /$vmhostname/i){
						$host_view=$_;
						if ($DEBUG){
							print "found the host view $host_view ::\n";
							print "Searching hostname ",  $host_view->name, "\n";
						}#endIF
					
						return("0");
					} else {
						if ($DEBUG){
							print "host_view not found\n";
						}#endIF
						$host="FAIL"	
					}#endIF
				}#endFOREACH				
			}#endIF
		}#endIF
	}#endif		
	
	if (lc($host) eq lc( $vmhostname)){
		return ("0");
	} else {
		return ("1");
	}#endIF
}#endSub
###########################################################################################

##########################################################################################
#
#       Sub get_hostinfo
#
###########################################################################################
sub get_hostinfo(){
	#####Take the hostname and pull the view object for it
	if ($vmhostname ne "" ){
	
		if ($DEBUG){
			print "found the host view $host_view\n";
			print "Searching hostname ",  $host_view->name, "\n";
		}#endIF
	  
		#####Take the vm array and loop through it to get resource usage info
		$inventory=$host_view->vm;
		foreach (@$inventory){
			my $vm = $session1->get_view(mo_ref => $_);
			$vm_count++;
			if ($DEBUG){
				print "Name " . $vm->name . " CPU_num " . $vm->summary->config->numCpu . " Memory " . $vm->summary->config->memorySizeMB/1024 . "GB" . " Storage " . $vm->summary->storage->committed/1024/1024/1024 . "GB ". "VM Number " . $vm_count."\n";
			}#endIF
			$vm_inventory.=$vm->name . ",";
			$memory+=$vm->summary->config->memorySizeMB/1024;
			$cpu+=$vm->summary->config->numCpu;
			$storage+=$vm->summary->storage->committed/1024/1024/1024;     
		}#endForEach
		
		######Get the HBA wwn info
		my $storageSystem=$session1->get_view(mo_ref => $host_view->configManager->storageSystem);
		$hbadapters=$storageSystem->storageDeviceInfo->hostBusAdapter;
		
		foreach (@$hbadapters){
			if ($_->key =~ /FibreChannel/i){
				if ($DEBUG){print "WWN: ".$_->nodeWorldWideName."\n"};
				$host_wwns.= $_->nodeWorldWideName . ",";
			}#endIF
		}#endForEach
		
		#####Get cpu and memory count for host
		$host_cpucount=$host_view->hardware->cpuInfo->numCpuCores;
		$host_memcount=$host_view->hardware->memorySize/1024/1024/1024;
	
		return("0");
	} else {
		return ("1");
	}#endIF
}#endSub
##########################################################################################

###########################################################################################
#
#	Sub get_Datastores
#
###########################################################################################
sub get_Datastores(){
	my $Datastore_view = $session1->get_views(mo_ref_array => $host_view->get_property('datastore')); 

	foreach (@$Datastore_view){
		my $storeSummary = $_->summary;

		if($storeSummary->type eq "VMFS" || $storeSummary->type eq "NFS"){
			if ($_->name  !~ /local/){
				$DatastoreName .= "\t\t" . $_->name . " " . $storeSummary->type . " " . $storeSummary->freeSpace/1024/1024 . " FreeMB\n";
			}#endIF
		}#endIF

	}#endForEach	
	if($DatastoreName){
		return("0");
	} else {
		return("1");
	}#endIF

}#endSub
##########################################################################################

###########################################################################################
#
#       Sub get_Cluster
#
###########################################################################################
sub get_Cluster(){

	my ($entity) = @_;#shift;
	
	if($DEBUG){
		#my $Cluster_view = $session1->get_view(mo_ref => $entity);
		print "DEBUG entity:: ".$entity->type." and ".$entity->value." ::\n";
		
		#print "DEBUG entity:: ".$Cluster_view->type." ::\n";
		print "DEBUG entity:: " . Dumper(\%$entity) . " ::\n";
	}#endIF

	unless ( defined $entity ){
		print "Root folder reached and Cluster not found!\n";
		return;
	}#endUnless
	
	if($entity->type eq "ClusterComputeResource"){
		my $Cluster_view = $session1->get_view(mo_ref => $entity, properties =>  ['name']);
		$ClusterName = $Cluster_view->name;
		if($DEBUG){
				print "Cluster for HostSystem $vmhostname  = $ClusterName \n";
		}#endIF
		return("0");
	}#endIF

	my $entity_view =$session1->get_view(mo_ref => $entity, properties => ['parent']);
	&get_Cluster($entity_view->parent);

	if($ClusterName || $entity){
		return("0");
	} else {
		return("1");
	}#endIF

}#endSub
###########################################################################################

###########################################################################################
#
#	Sub get_Datacenter
#
###########################################################################################
sub get_Datacenter(){

	my ($entity) = shift;
	
	unless ( defined $entity ){
		print "Root folder reached and datacenter not found!\n";
	return;
	}#endUnless

	if($entity->type eq "Datacenter"){
		my $datacenter_view = $session1->get_view(mo_ref => $entity, properties =>  ['name']);
		$DatacenterName = $datacenter_view->name; 
		if($DEBUG){
			print "Datacenter for HostSystem $vmhostname  = $DatacenterName \n";
		}#endIF
		return("0");
	}#endIF
 
	my $entity_view =$session1->get_view(mo_ref => $entity, properties => ['parent']);
	&get_Datacenter($entity_view->parent);

	
	if($DatacenterName || $entity_view){
		return("0");
	} else {
		return("1");
	}#endIF

}#endSub
###########################################################################################

###########################################################################################
#
#	Sub get_vCenterIP
#
###########################################################################################
sub get_vCenterIP(){
		$vCenter_view = $host_view->QueryHostConnectionInfo;
	if(defined($vCenter_view)){	
	  	
		$vCenterIP = $vCenter_view->serverIp;
		#$vCenterIP = $session1->get_view(mo_ref => $host_view->get_property('serverIP'));
		if($DEBUG){
			print "$vCenterIP \n";
		}#endIF
	
		#####Translate the vCenter IP to a DNS address
		$vCenterHostName = `nslookup $vCenterIP |grep 'name ='| awk '{print \$4}'`;
		chomp($vCenterHostName);
	
		if ($DEBUG){
			print "$vm_name is located in $vCenterHostName \n";
		}#endIF
		
		if ($vCenterHostName){
			return("0");
		} else {
			return("1");
		}#endIF	
	}#endIF

}#endSub
###########################################################################################

###########################################################################################
#
#       Sub get_Resources
#
###########################################################################################
sub get_Resources(){

	if ($DEBUG){
                        print "DEBUG:: get_Resources :: \n";
        }#endIF

	$memory=$vm_view->summary->config->memorySizeMB/1024 . "GB";
	$cpu=$vm_view->summary->config->numCpu;
	$storage=$vm_view->summary->storage->committed/1024/1024/1024;
	$storage=sprintf("%.2f", $storage)."GB";
	if ($storage){
	        return("0");
        } else {
                return("1");
        }#endIF

}#endSUB
###########################################################################################

###########################################################################################
#
#       Sub output2csv
#
###########################################################################################
sub output2csv(){
	if ($DEBUG){
                        print "DEBUG:: output2csv :: \n";
        }#endIF
	# Check the variables to ensure none are undefined.
	# If any variables are added to this subroutine add them to the checkvars subroutine also
	&checkvars();
	###Read the file into an array
	$ofname=">>$ofname.csv";
	open (FILE1, $ofname) or die "file $ofname not there";
        if($find_host){
			print FILE1 ("$vmhostname,$ClusterName,$host_wwns");
			if($show_resources){
				print FILE1 (",$vm_count,$host_cpucount,$cpu,$host_memcount,$memory,$storage,$vm_inventory");
			}#endIF
        } else {

		if($show_location){
	        if ($DEBUG){
                print "DEBUG:: show_location :: \n";
       	 	}#endIF
			print FILE1 ("$vm_name,$uuid,$vCenterHostName,$DatacenterName,$ClusterName,$vmhostname,$vmx_path,$ipaddress");	
		}#endIF
		if($show_resources){
			if ($DEBUG){
				print "DEBUG:: show_resources :: \n";
            }#endIF
			print FILE1 (",$cpu,$memory,$storage,$vmDataStore");
		}#endIF
    }#endIF
	print FILE1 ("\n");
	close (FILE1);
}#endSUB
###########################################################################################

###########################################################################################
#
#       Sub output2screen
#
###########################################################################################
sub output2screen(){
        if ($DEBUG){
                        print "DEBUG:: output2screen :: \n";
        }#endIF

        print '##############################'."\n";
	
	# Check the variables to ensure none are undefined.
        # If any variables are added to this subroutine add them to the checkvars subroutine also
        &checkvars();

        ###############IF --host parameter was used at commandline then skip to host section of printout 

	if(!$find_host){ ################VM Printout Section
                print "VM:\t$fq_name\n";
        	if($show_location){
			print "UUID:\t$uuid\n";                
			print "vCenter:\t$vCenterHostName\n";
	                print "DATACENTER:\t$DatacenterName\n";
	                print "CLUSTER:\t$ClusterName\n";
	                print "HOST:\t$vmhostname\n";
	                print "VMX file location:\t$vmx_path\n";
	                print "IP Address:\t$ipaddress\n";
        	}#endIF

	        if($show_resources){
	                print "CPU:\t$cpu\n";
	                print "MEMORY:\t$memory\n";
	                print "Provisioned Storage:\t$storage\n";
	                print "Datastores Used:\t$vmDataStore\n";
	        }#endIF
	} else { #################### HOST Printout Section

		print "HOST:\t$vmhostname\n";

		if($show_location){
			print "vCenter:\t$vCenterHostName\n";
			print "CLUSTER:\t$ClusterName\n";
		}#endIF

		if($show_resources){
                	print "VM Count:\t$vm_count\n";
			print "VMs on Host:\t$vm_inventory\n";
			print "HOST CPUS:\t$host_cpucount\n";
			print "CPUS ALLOCATED:\t$cpu\n";
	        	$host_memcount=sprintf("%.2f", $host_memcount)." GB";
		        print "HOST MEMORY:\t$host_memcount \n";
			print "MEMORY ALLOCATED:\t$memory GB\n";
			$storage=sprintf("%.2f", $storage)." GB";
        	        print "STORAGE USED by VMS:\t$storage\n";
			print "Host WWNS:\t$host_wwns\n";
		}#endIF
        }#endIF

	######Printout all Datastores available in the cluster if --show_datastores parameter was used at commandline
        if($show_datastores){
                print "Cluster Datastore List:\n$DatastoreName";
        }#endIF

        print '##############################'."\n";

}#endSUB
###########################################################################################

###########################################################################################
#
#	Sub clean_objects
#
###########################################################################################
sub clean_objects{

	$vm_view="";
	 $vmhost="";
	 $vmhostname="";
	 $host="";
	 $host_view="";
	 $vCenter_view="";
	 $vCenterIP="";
	 $vCenterHostName="";

}#endSub
###########################################################################################
#
#       Sub check the variables prior to printing and make any undefined variables
#	equal to 'N/A' so the Print fuction will work. (DKJ)
#
###########################################################################################
sub checkvars() {

	if(not(defined($vmhostname))) {$vmhostname = 'N/A'}
	if(not(defined($ClusterName))) {$ClusterName = 'N/A'}
	if(not(defined($host_wwns))) {$host_wwns = 'N/A'}
	if(not(defined($vm_count))) {$vm_count = 'N/A'}
	if(not(defined($vm_inventory))) {$vm_inventory = 'N/A'}
	if(not(defined($host_cpucount))) {$host_cpucount = 'N/A'}
	if(not(defined($cpu))) {$cpu = 'N/A'}
	if(not(defined($host_memcount))) {$host_memcount = 'N/A'}
	if(not(defined($memory))) {$memory = 'N/A'}
	if(not(defined($storage))) {$storage = 'N/A'}
	if(not(defined($uuid))) {$uuid = 'N/A'}
	if(not(defined($vCenterHostName))) {$vCenterHostName = 'N/A'}
	if(not(defined($DatacenterName))) {$DatacenterName = 'N/A'}
	if(not(defined($ClusterName))) {$ClusterName = 'N/A'}
	if(not(defined($vmhostname))) {$vmhostname = 'N/A'}
	if(not(defined($vmx_path))) {$vmx_path = 'N/A'}
	if(not(defined($ipaddress))) {$ipaddress = 'N/A'}
	if(not(defined($vmDataStore))) {$vmDataStore = 'N/A'}

}#endSUB

