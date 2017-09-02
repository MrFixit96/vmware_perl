#!/usr/bin/perl
use strict;
use warnings;
#########################################################################################
#
#	NAME: get-vmwareinfo_threader.pl
#	Date: 12/29/2013
#	Author: James Anderton (anderjc4)
#	Purpose: Take an input list file and create a thread for each item up to
#		 $maxthreads at a time and loop until its done.
#
########################################################################################
use threads;
use threads::shared;
use Thread::Queue;
use FindBin;
use Getopt::Long;

###########Initialize variables
my ($thread_limit,$maxthreads,$batch_list);

###########setup commandline args
GetOptions ("maxthreads=i" => \$maxthreads,
           "input_list=s"   => \$batch_list)
or die("Error in command line arguments\n");


##########################################################################################
#       Sub: Boss_Thread (main script)
#       Purpose: Check if batch mode is enabled and uses a boss/worker thread system to
#               run through the provided list in parallel threads
#########################################################################################
# A new empty queue
my $q = Thread::Queue->new();

#open input file and read it in to be queued up
open FILE, $batch_list or die "Can't open $batch_list: $!";
while(<FILE>){
	chomp($_);
	if ($_){
         	# Send work to the threads waiting
		$q->enqueue($_);
	}#endIF
}#endWHILE
close FILE;

#Set thread_limit to what came in on the commandline or default of 4 threads
if ($maxthreads){
	$thread_limit = $maxthreads;
}else{
	$thread_limit = 4;
}#endIF

#Setup an array of threads and loop while there are things from the list to dequeue
my @thr = map {
    threads->create(sub {
        while (defined (my $item = $q->dequeue_nb())) {		
		#Kick off the worker subroutine in a new thread
		&Worker_Thread($item);
        }#endWHILE
    });#endCreateThread

} 1..$thread_limit; #endThreadMAP

# Sync and terminate the threads
$_->join() for @thr;
# Trash the queue
$q=undef;
########################################################################################

########################################################################################
#
#	SUB: Worker_Thread
#
########################################################################################
sub Worker_Thread(){
	#bring in the search item from the input list
	my $job =shift;
	print  "Starting $job.\n";
	if ($search){
		#Use a system call to kick off the original single threaded single input script as a worker thread
		system("$job");
	}#endIF
}#endIF
