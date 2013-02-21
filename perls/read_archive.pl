#!/usr/bin/perl -w

#################################
## Fieldnotes Database         ##
##  Etienne Pelaprat           ##
##  etienne@prole.com          ##
##                             ##
## file: perls/read_archive.pl ##
##                             ##
##

use strict;
use diagnostics;

############################
## Quit if we don't have  ##
## the variables we need. ##
die "Didn't supply all the variables.\n\n"
    if ! defined $ARGV[0];

#########################
## Load the variables. ##
my $path     = $ARGV[0];
my $readMbox = '/Users/web/Sites/edu.ucsd.xmca/perls/read_mail.pl';

&runDirectory( $path );

exit(0);

##############################
## Run and read a directory ##
##  of mail spools.         ##
## Recurses down all of the ##
##  directories.            ##
##
sub runDirectory( $ ) {
    my( $dir ) = @_;

    #########################
    ## Open the directory. ##
    opendir( D, $dir ) ||
	die "Not file: $dir\n\n";

    ###########################
    ## Grab the files there. ##
    my @files = grep(!/^\.+/, readdir(D));

    ##########################################
    ## Go through each file and run this    ##
    ##  function on sub-dirs; otherwise     ##
    ##  call x_import_mbox.pl on that file. ##
    foreach my $file ( sort ( @files )) {

	############################
	## Absolute path to file. ##
        my $abs = "$dir/$file";

	#############
	## Switch. ##
        if( -d $abs ) {
	    &runDirectory($abs);

        } elsif(-f $abs && $abs !~ m|\.corrupt$| ) {

	    ##############################
	    ## Run the readMbox.pl on   ##
	    ##  this file as a separate ##
	    ##  process.                ##
	    system( "$readMbox file $abs" );
        }
    }

    ######################
    ## Close directory. ##
    closedir(D);
}
