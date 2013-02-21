#!/usr//bin/perl -w

##############################
##  Pruby Web               ##
##  Etienne Pelaprat        ##
##  etienne@prole.com       ##
##                          ##
## file: perls/read_mail.pl ##
##                          ##
##

use strict;
use diagnostics;

use DBI;
use Encode 'decode';
use Net::SMTP;
use File::Copy;
use XML::Simple;
use HTML::Strip;
use MIME::Parser;
use Text::Quoted;
use Time::ParseDate;
use Mail::Address;
use Mail::Message;
use Mail::IMAPClient;
use IO::Socket::SSL;
use Mail::Message::Body;
use Unicode::Normalize;
use Convert::TNEF;
use Data::Dumper;

############
## Initial
my $file_depot_dir = '/tmp/xmca-mail-parsing';
if( ! -e $file_depot_dir ) {
    mkdir $file_depot_dir, 0755;
}

######################
## Parser settings. ##
my $parser = new MIME::Parser;
   $parser->output_dir( $file_depot_dir );

##########################################
## Make a version of Email::Folder that ##
##  will return MIME:Entity messages.   ##
package Email::Folder::MIME::Entity;
use base 'Email::Folder';
sub bless_message {
    my( $self, $rfc2822 ) = @_;

    #####################################
    ## Do not continue if empty email. ##
    ##
    if( ! defined $rfc2822 || $rfc2822 =~ /^\s*$/ ) {
		&forward_failure( "error: $!\nEncode:Decode error: undefined return.", $rfc2822 );
    } else {
		$rfc2822 = $rfc2822;
    }

    #########################
    ## Decode into Unicode ##
    ##
    $rfc2822 = Encode::decode( 'cp1250', $rfc2822 );

    $rfc2822 = Encode::decode_utf8( $rfc2822 )
		unless Encode::is_utf8( $rfc2822 );

#    $rfc2822 = Encode::decode("iso-8859-1", $rfc2822 );

    #########################################
    ## Only continue if we have real text. ##
    return undef
	if ! defined $rfc2822 || $rfc2822 eq '';

    #########################
    ## And clean the text. ##
    &clean_characters( \$rfc2822 );

    ###############################
    ## Returned the parsed MIME. ##
    return $parser->parse_data( $rfc2822 );
}

##############################
## Load the config file and ##
##  local paths to modules. ##
##
my $db_user = '####';
my $db_pass = '#########';
my $db_name = '############';
my $db_host = 'localhost';

my $inc_mail_user        = '######'
my $inc_mail_pass        = '######'
my $inc_mail_server      = '######'
my $inc_mail_server_port = 993;

my $out_mail_user        = '######';
my $out_mail_pass        = '######';
my $out_mail_server      = '######';
my $out_mail_server_port = 465; ## DH = 587

my $attachment_dir       = '/directory/to/attachments';
my $default_email        = '######';

my $salt                 = 'somestring';

################################
## Current message variables. ##
my $cm_previous = 0;
my $cm_indent   = 0;
my $cm_level    = 0;

###################
## MySQL Tables. ##
##
my $t_messages	= 'messages';
my $t_assets	= 'assets';
my $t_bodies	= 'bodies';
my $t_people	= 'people';
my $t_yarns	= 'yarns';
my $t_emails	= 'emails';

#############################
## Build the basic objects ##
##
my( $try, $good ) = ( 0, 0 );
##my $ensemble      = -1;
my @messages      = ();
my $admin         = 'pelaprat@gmail.com';
my $time          = time;

###############################################
## G E T  M Y  S Q L   C O  N N E C T I O N  ##
###############################################
my $sql = DBI->connect( "DBI:mysql:database=$db_name;host=$db_host;",
			$db_user,
			$db_pass,
			{ RaiseError => 1,
			  AutoCommit => 1 });

############################
## Quit if we don't have  ##
## the variables we need. ##
die "Didn't supply all the variables.\n\n"
    if ! defined $ARGV[0] ||
       ! defined $ARGV[1];

my $mode = $ARGV[0];
my $path = $ARGV[1];

#################################################################################################
## R E T R I E V E   A L L   O F   T H E   N E W   E M A I L   F R O M   T H E   M A I L B O X ##
#################################################################################################

if( $mode eq 'imap' ) {

    ############################
    ## Build the IMAP Client. ##
    my $imap = Mail::IMAPClient->new(	Server   => $inc_mail_server,
				      					User     => $inc_mail_user,
				      					Password => $inc_mail_pass,
				      					Socket   => IO::Socket::SSL->new
				      					(	Proto    => 'tcp',
											PeerAddr => $inc_mail_server,
											PeerPort => $inc_mail_server_port
				      					))
		or die "Cannot connect to $inc_mail_server as $inc_mail_user: $@\n";

#    $imap->Port( $inc_mail_server_port );

    ####################
    ## Read the Inbox. ##
    $imap->Peek();
    $imap->select('INBOX');

    ##############################
    ## Get our unread messages. ##
    my @unread = $imap->unseen( Uid => 1 )
	or warn "No messages to download.\n";

    #@unread = $imap->seen( Uid => 1 );

    ########################
    ## Read the messages. ##
    foreach my $msg ( @unread ) {

	print "Reading message #$msg\n";

	######################
	## Get the message. ##
	my $rfc2822 = $imap->message_string( $msg ) 
	  or die "Could not message_string: $@\n";

	#####################################
	## Do not continue if empty email. ##
	##
	if( ! defined $rfc2822 || $rfc2822 =~ /^\s*$/ ) {
	    &forward_failure( "Error: $!\nEncode:Decode error: undefined return.", $rfc2822 );
	} else {
	    $rfc2822 = $rfc2822;
	}

	#########################
	## Decode into Unicode ##
	##
	$rfc2822 = Encode::decode( 'cp1250', $rfc2822 );

	$rfc2822 = Encode::decode_utf8( $rfc2822 )
	    unless Encode::is_utf8( $rfc2822 );

	#########################################
	## Only continue if we have real text. ##
	return undef
	    if ! defined $rfc2822 || $rfc2822 eq '';

	#########################
	## And clean the text. ##
	&clean_characters( \$rfc2822 );

	#################################
	## Save the message for later. ##
	push( @messages, $parser->parse_data( $rfc2822 ));

    }

    #################
    ## Disconnect. ##
    $imap->disconnect()
	or warn "Could not disconnect: $@\n";
}

##########################################################################################
## R E T R I E V E   A L L   O F   T H E   M E S S A G E S   F R O M   T H E   F I L E  ##
##########################################################################################

if( $mode eq 'file' ) {

    ###############
    ## NOW BEGIN ##
    my $folder = Email::Folder::MIME::Entity->new( $path );

    foreach my $entity ( $folder->messages ) {

	############################################
	## Only continue if we have MIME::Entity. ##
	next unless defined $entity;

	push @messages, $entity;
    }
}

#############################################################################
##   G O T   T H R O U G H   E A C H   M E S S A G E   O N   B Y   O N E   ##
#############################################################################
my $current_global_entity = undef;

foreach my $entity ( @messages ) {

    $try++;

    #####################
    ## Get the header. ##
    my $header = $entity->head();


    ########################################
    ## Based on the email address of this ##
    ##  message we should see if we can   ##
    ##  find the right ensemble to load.  ##
#    my @addresses = ();

#    my $to = $header->get('To');
#    my $cc = $header->get('CC');
#    my $fr = $header->get('From');
#    my $fg = $header->get('>From');

#    push( @addresses, Mail::Address->parse( $to )) if defined $to;
#    push( @addresses, Mail::Address->parse( $cc )) if defined $cc;
#    push( @addresses, Mail::Address->parse( $fr )) if defined $fr;
#    push( @addresses, Mail::Address->parse( $fg )) if defined $fg;

    ########################################
    ## Find the ensembles for this email. ##
#    if( @addresses ) {

	####################################
	## Make the string safe and good. ##
#	my $addresses = join( "','", map { $prole->safe_single_quotes( $_->address )} @addresses );

	#####################################
	## See if we can find this mailing ##
	##  list in the database.          ##
#	my $query   = ( 'select el.ensemble from wEnsembleListener el ' .
#			' join pPerson p on el.listener = p.id        ' .
#			" where p.email in ( 'addresses'  )          " .
#			' group by ensemble                           ');

	######################
	## Get the results. ##
#	my @results = $sql->complex_results( $query );
#	foreach my $row ( @results ) {
#	    push( @ensembles, $row->{ensemble} );
#	}
#    }

    ###########################################
    ## Exit if we don't have a mailing list. ##
##    my @ensembles = ( 1 );

##   if( scalar( @ensembles )  <= 0 ) {

	#######################################################
	## Send administrator an email; attach botched mail. ##
##	&forward_failure( "No mailing list for this address.\n\n", $entity->stringify() );
##	next;
##    }

    ##############################
    ## Get the ensemble object. ##
##    foreach my $ensemble ( @ensembles ) {

	####################################
	## Local versions of the rfc2822. ##
	my $lentity = $entity;
	my $lheader = $lentity->head();

	#####################
	## From addresses. ##
	my $from = $lheader->get('From');
	   $from = $lheader->get('>From') if ! defined $from;
	my @from = Mail::Address->parse( $from ) or
	    die "Error parsing the address: $from\n";
	$from = pop( @from );

        $current_global_entity = $lentity;

	#################################
	## Attempt to add the message. ##
	eval{ &mail_read_message( $lentity, $lheader, $from );};

	if( $@ ) {

	    #######################################
	    ## Send the administrator a message. ##
	    &forward_failure( "Error: $!\nBotched mail_read_message()\n\n", $entity->stringify() );
	    next;

	} else {
	    $good++;
	}
##	    }
}

############
## Stats. ##
if( $mode eq 'file' ) {
    print "$path\n\t";
}
print "Total: $good / $try\n\n";

############
## FINISH ##
$sql->disconnect();
exit(0);

###########################################################
##  F U N C T I O N S   T O   R E P O R T   E R R O R S. ##
###########################################################

sub forward_failure( $$ ) {
    my( $error, $original ) = @_;

    ###################
    ## Use Net::SMTP ##
#    my $smtp = Net::SMTP->new(         $out_mail_server,
#			       PORT => $out_mail_server_port )
#	or die "Couldn't connect to server.\n\n";

    ########################
    ## Authenticate SMTP. ##
#    $smtp->auth( $out_mail_user,
#		 $out_mail_pass )
#	or die "Could not authenticate $!";

    ####################################
    ## Specify who from and where to. ##
#    $smtp->mail( $default_email );
#    $smtp->recipient( $admin );

    #################################
    ## Write and send the message. ##
#    $smtp->data();
#    $smtp->datasend( "From: XMCA Resources <webmaster\@lchc-resources.org>\n" );
#    $smtp->datasend( "Subject: Email Scanning Error ($time)\n" );
#    $smtp->datasend( "\n" );
#    $smtp->datasend( "Got this error: $error\n" );
#    $smtp->datasend( "\n\n$original\n\n" );
#    $smtp->datasend( "\n" );
#    $smtp->dataend();
#    $smtp->quit();

    print "Forward failure: $error\n";
}

#####################
## Text Processing ##
sub clean_characters( $ ) {
    my( $text ) = @_;

    ########################
    ## Clean up the text. ##
    ##
    ##  Take from: http://ahinea.com/en/tech/accented-translate.html
    ##   by Ivan Kurmanov, kurmanka@yandex.ru
    ##
    $$text =~ s/\xe4/ae/g;  ## 
    $$text =~ s/\xf1/ny/g;  ## This was wrong in previous version of this doc.
    $$text =~ s/\xf6/oe/g;
    $$text =~ s/\xfc/ue/g;
    $$text =~ s/\xff/yu/g;

    $$text =  Unicode::Normalize::NFD( $$text ); ## Decompose (Unicode Normalization Form D)
    $$text =~ s/\pM//g;

    $$text =~ s/\x{00df}/ss/g;  ##  German beta âÃâ -> âssâ
    $$text =~ s/\x{00c6}/AE/g;  ##  Ã
    $$text =~ s/\x{00e6}/ae/g;  ##  Ã
    $$text =~ s/\x{0132}/IJ/g;  ##  Ä
    $$text =~ s/\x{0133}/ij/g;  ##  Ä
    $$text =~ s/\x{0152}/Oe/g;  ##  Å
    $$text =~ s/\x{0153}/oe/g;  ##  Å
    $$text =~ s/\x{096}//g;  ##  Å

    $$text =~ tr/\x{00d0}\x{0110}\x{00f0}\x{0111}\x{0126}\x{0127}/DDddHh/; # ÃÄÃ°Ä
    $$text =~ tr/\x{0131}\x{0138}\x{013f}\x{0141}\x{0140}\x{0142}/ikLLll/; # Ä±Ä¸Ä¿ÅÅÅ
    $$text =~ tr/\x{014a}\x{0149}\x{014b}\x{00d8}\x{00f8}\x{017f}/NnnOos/; # ÅÅÅÃÃ
    $$text =~ tr/\x{00de}\x{0166}\x{00fe}\x{0167}/TTtt/;                   # ÃÅ¦

    $$text =~ s/[^\0-\x80]//g;  ## Clear everything else; optional.
}

##################################
## Read a message that you then ##
##  put into a mailing-list     ##
##  thread.                     ##
##                              ##
##  This function expects an    ##
##   Email::MIME object.        ##
##
sub mail_read_message( $$$ ) {
    my( $message, $header, $from ) = @_;

    ##################################
    ## Retrieve some message values ##
    ##
    my $name      = $from->name();
    my $address   = $from->address;
    my $subject   = $header->get('Subject');
    my $date      = $header->get('Date');
    my $person    = -1;
	my $email	  = -1;
    my $thread    = -1;
    my $threadObj = undef;
    my $id        = -1;

    ########################################
    ## Do some checks on the variables    ##
    ##  from the head of the email before ##
    ##  continuing.                       ##
    ##
    return -2  if   ! defined $address;
    $name = '' if   ! defined $name;

    $subject = 'no subject' if
		( ! defined $subject || $subject eq '' );
    $subject =  &safe_re_fwd( $subject );
    $subject =~ s/\n//g;
    $subject =~ s/\r//g;
    $subject =~ s/\t/ /g;

    ##################################
    ## Remove the name of the list. ##
    $subject =~ s/^\s*\[\w+\]\s*//;

    #################################################
    ## Always look again in the db for the thread. ##
    ##
#    my $search_subject =  join('%', split( '', $subject ));
#       $search_subject =~ s/\s//g;
#       $search_subject =  &safe_single_quotes( $search_subject );

#    $self->load_thread_data({ 'wt.name' => "'$search_subject'" },
#			    { 'wt.name' => 'like'              });

	########################################
	## First Handle the Date / Timestamp. ##
	########################################

	############################
	## Convert the timestamp. ##
	$date = Time::ParseDate::parsedate( $date, ZONE => 'PDT', PREFER_PAST => 1 );

	#######################################################
	## Failed parse? Try different headers or solutions. ##
	if( $date <= 0 || $date eq '' ) {

		########################################
		## Try to use the Resent-Date header. ##
		$date = $header->get('Resent-Date');
		$date = Time::ParseDate::parsedate( $date, ZONE => 'PDT', PREFER_PAST => 1 );
	}

    ########################################
    ## Second: Handle the Name / Address. ##
    ########################################

    ######################################
    ## Get the author for this message. ##
    ( $person, $email ) = &mail_find_person_by_email( $address );

	#########################################
	## Add the person first if we need to. ##
    if( $person <= 0 ) {

		###############################
		## Get the parts of the name ##
		my( $first, $middle, $last ) = &parse_name( $name );

		######################################
		## See if this person is in the DB. ##
		$person = &mail_find_person_by_name({	first  		=> $first,
												last   		=> $last });

		if( $person <= 0 ) {
			##########################
			## Now create the user. ##
			$person =  &add_person({	first  		=> $first,
				 						middle 		=> $middle,
										last   		=> $last,
										email		=> $address,
										pass		=> lc( "hi.$first" ),
										created_at	=> $date,
										updated_at	=> $date });
		}
    } else {

		#####################################
		## No error code:                  ##
		##  the information simply         ##
		##  has to be put in the database. ##

    }

	######################################
	## Now add the email if we need to. ##
	if( $email <= 0 && $address ne '' && $person > 0 ) {
		$email = &add_email({	email	=> 	$address,
								person	=>	$person,
								created_at	=> $date,
								updated_at	=> $date });
	}

    ##########################################
    ## Make sure the person is in the group ##
    ##  for this mailing list.              ##
#    my $groups = $self->{groups};
#    foreach my $group ( @$groups ) {
#	$self->{prole}->add_person_to_group( $person, $group->[0] );
#    }


    ###############################
    ## Third: Handle the Thread. ##
    ###############################

    #######################################
    ## Now retrieve the right thread for ##
    ##  this mail message.               ##
    $thread = &mail_find_thread( $subject );

    ###################################
    ## Add the thread if we need to. ##
    if( $thread <= 0 ) {

		##############################
		## Use the Ensemble object. ##
		$thread = &add_thread({
			name    	=> $subject,
			items   	=> 0,

			person_id	=> $person,
			updated_at 	=> $date,

			first		=> '',
			middle		=> '',
			last		=> '' });

#				groups         => $groups,
#				object         => undef,
#				return         => 'object' });

#    } elsif( ! defined $self->{data}->{$thread} ) {
	}

    ##################################
    ## Just grab the thread object. ##
#    $threadObj    = $self->get_thread_object( $thread );

    ########################################
    ## Fourth: Handle the Message itself. ##
    ########################################

    #############################################
    ##  Proceed to enter this message into the ##
    ##  database, not forgetting the various   ##
    ##  attachments, if they exist.            ##
    ##
    if( $person > 0 && $thread > 0 ) {

		#######################################
		## Add the message using the thread. ##
		$id = &add_email_message({	thread    => $thread,     # id
						author    => $person,     # id
						message   => $message,    # object
						timestamp => $date,    	  # string
						subject   => $subject }); # string

    } else {

		########################
		## We throw an error. ##
		return -3;
    }

    ############################################
    ## Fifth: Link the message to the thread. ##
    ##   And link the thread to the ensemble. ##
    ############################################
##    my $sth = $sql->prepare( "insert into $t_yarns_message ( id, message_id, yarn_id ) values ( ?, ?, ? )" );
##       $sth->execute( undef, $id, $thread );
##       $sth->finish;

    ######################################
    ## Get rid of anything on the disk. ##
    $message->purge();

    return 1;
}

##################################
##
sub mail_find_person_by_email( $ ) {
    my( $address ) = @_;
	my $person	= -1;
    my $email	= -1;

    my $query = "select person_id, id from $t_emails where email = ?";
    my $sth   = $sql->prepare( $query );
       $sth->execute( $address );

    while( my $row = $sth->fetchrow_hashref ) {
		$person = $row->{person_id};
		$email  = $row->{id};
		
    }

    $sth->finish();

    return ($person, $email);
}

##################################
##
sub mail_find_person_by_name( $ ) {
    my( $params ) = @_;
	my $person	= -1;

    my $query = "select id from $t_people where lower(first) = lower(?) and lower(last) = lower(?) ";
    my $sth   = $sql->prepare( $query );
       $sth->execute( $params->{first}, $params->{last} );

    while( my $row = $sth->fetchrow_hashref ) {
		$person  = $row->{id};
		
    }

    $sth->finish();

    return $person;
}

##################################
## Based on the subject of the  ##
##  mail find the right thread. ##
##
sub mail_find_thread( $ ) {
    my( $subject ) = @_;
    my  $threads          = undef;
    my  $convertedSubject = '';
    my  $id = -1;

    my $sth = $sql->prepare( "select id from $t_yarns where name = ?" );
       $sth->execute( $subject );

    while( my $row = $sth->fetchrow_hashref ) {
		$id = $row->{id};
    }
    $sth->finish();

    #######################################
    ## Create a local converted subject. ##
#    $convertedSubject =  lc( $subject );
#    $convertedSubject =~ s/[^\w]//g;

    #######################################################
    ## Search through all of this ensemble's the threads ##
    ##  for the one that matchines the subject of this   ##
    ##  message.                                         ##
    ##
#    foreach my $thread ( sort {$b <=> $a} keys( %$threads )) {
#	my $data = $threads->{$thread};

	###########################################
	## Create a local converted thread name. ##
#	my $convertedThreadname =  lc( $data->{thread_name} );
#	   $convertedThreadname =~ s/[^\w]//g;

	##############################
	## See if there is a match. ##
#	if( $convertedSubject eq $convertedThreadname ) {
#	    return $data->{thread_id};
#	}
#    }

    return $id;
}

################################
## Removes the Re's and Fwd's ##
##  from the string.          ##
sub safe_re_fwd( $$ ) {
    my( $string ) = @_;

    ################################
    ## Cleanup the string to get ##
    ##  rid of the re:'s.         ##
    if( defined $string && $string ne '' ) {
		$string =~ s/re:\s+//gi;
		$string =~ s/re\(\d+\):\s+//gi;
		$string =~ s/fw:\s+//gi;
		$string =~ s/fw\(\d+\):\s+//gi;
		$string =~ s/fwd:\s+//gi;
		$string =~ s/fwd\(\d+\):\s+//gi;
		$string =~ s/res:\(\d+\):\s+//gi;
		$string =~ s/res\(\d+\):\s+//gi;
    }

    return $string;
}

sub parse_name($) {
    my( $name ) = @_;
    my( $first, $middle, $last ) =
	('', '', '');

    ########################################
    ## Get the first, middle, last names. ##
    if( defined $name && $name =~ m|^([\-\w]+)\s*(.*)\s+([\-\w]+)$| ) {

		$first  = $1;
		$middle = $2;
		$last   = $3;

    } elsif( defined $name ) {

		$first = $name;
    }

    return ( $first, $middle, $last );
}

########################################
## Methods for adding various basic   ##
##  elements of the Prole web system. ##
##
sub add_person($) {
    my( $params )   = @_;
    my( $sth, $id ) = ( undef, undef );

    ################################
    ## Make sure we have the data ##
    ##  we want available.        ##
    ##
    if(	defined $params->{first} && defined $params->{middle} &&
		defined $params->{last}  && defined $params->{email}  &&
		defined $params->{pass}                              ) {

		########################
		## Insert the person. ##
		$sth = $sql->prepare(	"insert into $t_people ( id, first, middle, last, password, salt, created_at, updated_at ) " .
			     				" values( ?, ?, ?, ?, md5(?), ?, from_unixtime(?), from_unixtime(?) )                      ");
		$sth->execute(	undef, $params->{first}, $params->{middle}, $params->{last},
		       			"$params->{pass}$salt", $salt, $params->{created_at}, $params->{updated_at} );
		$id  = $sth->{mysql_insertid};

		return $id;
    }

    return -1;
}

########################################
## Add a new thread to this ensemble. ##
sub add_thread( $ ) {
    my( $data ) = @_; 
    my ( $sth ) = ( undef, () );

    ############################################
    ## Throw an error if we are missing data. ##
#    $self->{prole}->throw_error( 220 ) if
#	! defined $data->{thread_type} ||
#	! defined $data->{thread_name};

    ##############################################
    ## Make sure the name has not null-padding. ##
    $data->{name} = 'no subject' if
	( ! defined $data->{name}            ||
	            $data->{name} =~ /^\s*$/ );

    $data->{name} =~ s/^\s+//g;
    $data->{name} =~ s/\s+$//g;

    ################################################
    ## Take care of some default values if blank. ##
    $data->{items}  = 0  if ! defined $data->{items};

    $data->{person_id}   = -1 		if ! defined $data->{person_id};
    $data->{updated_at} = 'NOW()'	if ! defined $data->{updated_at};

    $data->{first}  = '' if ! defined $data->{first};
    $data->{middle} = '' if ! defined $data->{middle};
    $data->{last}   = '' if ! defined $data->{last};

##    $data->{ensembles}      = [()]  if ! defined $data->{ensembles};
##    $data->{groups}         = [()]  if ! defined $data->{groups};
##    $data->{object}         = undef if ! defined $data->{object};

##    $ensembles              = $data->{ensembles};
#    $groups                 = $data->{groups};

    ########################################
    ## Make sure this ensemble is part of ##
    ##  the thread's general ensembles.   ##
#    push( @$ensembles, $self->{ensemble_id} )
#	unless $self->{prole}->in( $self->{ensemble_id}, @$ensembles );
 
    #################################################
    ## Set the default group as the Ensemble's     ##
    ##  group if no groups are set for the thread. ##
#    foreach my $g ( @$groups ) { push( @groups, $g->[0] ); }
#    push( @$groups, [ $self->{ensemble_group}, 1, 1, 1 ] ) 
#	unless $self->{prole}->in( $self->{ensemble_group}, @groups );

    ####################################
    ## Insert the thread into the DB. ##
    $sth = $sql->prepare( "INSERT INTO $t_yarns                        " .
			  ' ( id, name, items, person_id, created_at, updated_at ) ' .
			  ' values( ?, ?, ?, ?, from_unixtime(?), from_unixtime(?) )              ');

    $sth->execute(	undef,
		   			$data->{name},
		   			$data->{items},
		   			$data->{person_id},
		   			$data->{updated_at},
		   			$data->{updated_at} );

    $data->{thread_id} = $sth->{mysql_insertid};
    $sth->finish;

    ########################################
    ## Match the thread to this ensemble. ##
##    foreach my $ensemble ( @$ensembles ) {
##		$sth = $sql->prepare( "INSERT INTO $t_yarns_ensemble ( id, yarn_id, ensemble_id ) values ( ?, ?, ? )" );
##		$sth->execute( undef, $data->{thread_id}, $ensemble );
##		$sth->finish;
##    }

    ####################################
    ## Add the group matches for this ##
    ##  ensemble to the database.     ##
#    foreach my $set ( @$groups ) {

	####################################
	## Add ensemble-group to the db. ##
#	$sth = $sql->prepare( "insert into $tg                      " .
#			      ' ( wThread, pGroup, r, w, m ) values ' .
#			      ' ( ?, ?, ?, ?, ? )                   ');

#	$sth->execute( $data->{thread_id}, $set->[0], $set->[1], $set->[2], $set->[3] );
#	$sth->finish;
#    }

    return $data->{thread_id};
}

###################################
## ADD MESSAGES, BUT NOT EMAILS, ##
##   VIA THESE METHODS           ##
##
sub add_message( $ ) {
    my( $params ) = @_;
    my $sth = undef;

    $sth = $sql->prepare(	"insert into $t_messages ( id, yarn_id, person_id, subject, created_at, updated_at ) " .
				" values( ?, ?, ?, ?, from_unixtime(?), from_unixtime(?) )                           ");
    
    $sth->execute(	undef,
					$params->{yarn_id},
					$params->{person_id},
		          	$params->{subject},
					$params->{timestamp},
					$params->{timestamp} );

    my $id = $sth->{mysql_insertid};
    $sth->finish;

    return $id;
}

########################################
## This function inserts a message    ##
##  body, which is part of a message. ##
##  This means you must have already  ##
##  created a message for this part   ##
##  of the body.                      ##
##
sub add_message_body( $ ) {
    my( $params ) = @_;
    my $sth = undef;

    ########################################
    ## Only if we have defined variables. ##
    ##
    if(	defined $params->{message_id}   && 
		defined $params->{level}     	&& 
		defined $params->{original}  	&& 
		defined $params->{formatted} 	) {

		my $o = $params->{original};
		my $f = $params->{formatted};

		$sth = $sql->prepare(	"insert into $t_bodies 													" .
					"( id, message_id, level, original, formatted, created_at, updated_at )	" .
					" values( ?, ?, ?, ?, ?, from_unixtime(?), from_unixtime(?) )      		");
		
		$sth->execute(	undef,
						$params->{message_id},
						$params->{level},
						$$o, $$f, $params->{created_at}, $params->{updated_at} );

		my $id = $sth->{mysql_insertid};
		$sth->finish;

		return $id;
    }

    return -1;
}

################################
## Add email to the database. ##
sub add_email($) {
    my( $params )   = @_;
    my( $sth, $id ) = ( undef, undef );

    ################################
    ## Make sure we have the data ##
    ##  we want available.        ##
    ##
    if(	defined $params->{email} && defined $params->{person} ) {

		########################
		## Insert the person. ##
		$sth = $sql->prepare(	"insert into $t_emails ( id, email, person_id, created_at, updated_at ) " .
			     				" values( ?, ?, ?, from_unixtime(?), from_unixtime(?) )                 ");
		$sth->execute(	undef, $params->{email}, $params->{person}, $params->{created_at}, $params->{updated_at} );
		$id  = $sth->{mysql_insertid};

		return $id;
    }

    return -1;
}


##############################
## Add a message to thread. ##
sub add_email_message( $ ) {
    my( $params ) = @_;
    my  $subject = $params->{subject};
    my( $query, $sth );

#	$id = &add_email_message({	thread    => $thread,     # id
#								author    => $author,     # id
#								message   => $message,    # object
#								timestamp => $date,       # string
#								subject   => $subject }); # string
								
    ################################
    ## We throw an error if there ##
    ##  is some missing data.     ##
    if(	! defined $params->{thread}   || ! defined $params->{author}    ||
		! defined $params->{message}  || ! defined $params->{timestamp} ||
		! defined $params->{subject}     								) {

		################################
		## Throw an error.            ##
		## Critical data is missing.  ##
		return -1;
    }

	#############################
	## Reset global variables. ##
	my $cm_previous = 0;
	my $cm_indent   = 0;

    ############################
    ## Get the right subject. ##
    $subject = $params->{subject} if
		defined $params->{subject} && $params->{subject} ne '';

    ##############################
    ## Insert the message here! ##
    my $message = &add_message({	yarn_id		=> $params->{thread},
					person_id	=> $params->{author},
					subject   	=> $subject,
					timestamp 	=> $params->{timestamp} });

    ############################
    ## Insert the email here. ##
#    my $text  = $params->{message}->as_string();
#	my $email = &add_email({	message =>  $message,
#			     				text    => \$text });

    ########################################
    ## Now traverse through the message   ##
    ##  and put the body in the database. ##
    ########################################
    &email_read_message_part(	$message,
				$params->{author},
				$params->{timestamp},
				$params->{message} );

    ##################################################
    ## Now merge together adjacent quoted sections. ##
#    $self->merge_adjacent_quoted( $message );

    ########################################
    ## Set a number of thread specific    ##
    ##  details that change as a function ##
    ##  of messages being added.          ##
    $sth = $sql->prepare(	"update $t_yarns set items     = items  + 1, " .
				"                   updated_at = from_unixtime(?), " .
				"                   person_id  = ?  " .
				"                     where id = ?            ");

    $sth->execute( $params->{timestamp}, $params->{author}, $params->{thread} );
    $sth->finish();

    return $message;
}

#####################################
## After we have divided the       ##
##  message into separate parts,   ##
##  we read each here individually ##
##  and toggle on their kind.      ##
##
sub email_read_message_part( $$$$ ) {
    my( $id, $author, $timestamp, $message ) = @_;
    my( $sth );

    #######################################################
    ## Toggle content type based on the kind of message. ##
    my $header = $message->head();
    my $body   = $message->bodyhandle();
    my $type   = $message->effective_type();

    ##################################
    ## Return -1 if we don't have a ##
    ##  good content type.          ##
    if( ! defined $type || $type eq '' ) {
	#print "No content type on message $id.\n";
	$type = 'text/plain';
    }

    #######################################
    ## Switch through the kind of type!! ##
    if( $type =~ /^text/i ) {

	#####################################
	## First strip HTML if we need to. ##
	my $ct = '';
	if( $type =~ /^text\/html/i ) {
	    my	$hs = HTML::Strip->new();
	    $ct = $hs->parse( $body->as_string() );
	    $hs->eof();
	} else {
	    $ct = $body->as_string();
	}

	#########################
	## Handle normal text. ##
	my $tree = Text::Quoted::extract( $ct );
	&email_traverse_message_part( $id, $timestamp, $tree );

    } elsif( $type =~ /^multipart\/mixed/i    ||
	     $type =~ /^multipart\/related/i      ||
	     $type =~ /^multipart\/report/i       ||
	     $type =~ /^multipart\/rfc822/i       ||
	     $type =~ /^multipart\/appledouble/i  ||
	     $type =~ /^multipart\/alternative/i  ||
	     $type =~ /^message\/rfc822/i        ) {

	########################################
	## Handle a message with attachments. ##
	foreach my $part ( $message->parts() ) {
	    &email_read_message_part( $id, $author, $timestamp, $part );
	}

    } elsif(	$type =~ /^application/i ||
		$type =~ /^audio/i       ||
		$type =~ /^video/i       ||
		$type =~ /^image/i      ) {

	################
	## Attachment ##
	if( $type eq 'application/ms-tnef' ) {
	    ## Skip this kind of attachment
	} else {

	    ####################################################
	    ## Get the attachment information as best we can. ##
	    my( $name, $ext, $bytes, $path, $historical ) = ( '', '', 0, '', 0 );

	    ###################
	    ## Name of file. ##
	    $name = $header->recommended_filename();
	    if( ! defined $name ||  $name eq '' ) { $name = 'noname'; }
	    chomp $name;
	    if( defined $name && $name =~ m|\.(\w+)$| ) { $ext = $1; }

	    my $attachment = $body->as_string;

	    ####################
	    ## Size in bytes. ##
	    if( $header->count( 'Content-Length' ) > 0 ) {
		$bytes = $header->get( 'Content-Length' );
	    } else {
		$bytes = length( $attachment );
	    }

	    #####################
	    ## Something else. ##
	    if( $type ne '' && $type =~ m/^(application\/[^;]+);\s+name=\"(.+\.(\w+))\"$/ ) {
		$type = $1;
		$name = $2;
		$ext  = $3;
	    }

	    ####################
	    ## Add the asset. ##
	    $sth = $sql->prepare( "insert into assets( id, message_id, name, content_type, size, created_at, updated_at ) " .
				  " values ( ?, ?, ?, ?, ?, from_unixtime(?), from_unixtime(?) )                          ");
	    $sth->execute( undef, $id, $name, $type, $bytes, $timestamp, $timestamp );
	    my $file = $sth->{mysql_insertid};
	    $sth->finish;
		
	    ############################################
	    ## Make the directory for the attachment. ##
	    ##  And then copy it over.                ##
	    mkdir( "$attachment_dir/$file" , 0777);

	    open FH, "> $attachment_dir/$file/$name"
		|| die "cannot open FH ($!)\n\tFile: $attachment_dir/$file/$name\n";
	    print FH $attachment;
	    close FH;
	}

    } elsif( $type =~ /^message/i ) {
	## Do nothing.

    } else {
	die "Error: unhandled type: $type.\n";
    }

    return 1;
}

#################################
## Traverse a plain/text part  ##
##  of the message, that has   ##
##  been extracted via         ##
##  Text::Quoted.              ##
##
sub email_traverse_message_part( $$$ ) {
    my( $id, $timestamp, $root ) = @_;

    foreach my $ptr ( @$root ) {

	################################
	## Toggle on the type of ref. ##
	##
	if( ref($ptr) eq 'ARRAY' ) {

	    &email_traverse_message_part( $id, $timestamp, $ptr );

	} elsif( ref( $ptr ) eq 'HASH' ) {

	    ########################################
	    ## 'text', 'quoter', 'raw'            ##
	    ##                                    ##
	    ## Here, I guess, is where we insert  ##
	    ##  message parts and where we do     ##
	    ##  some additional figuring out      ##
	    ##  of the structure.                 ##
	    ##

	    ########################################
	    ## Do we have a quoted block?         ##
	    ##
	    my $quoteLevel = 0;
	    if( defined $ptr->{quoter} && $ptr->{quoter} ne '' ) {

			$ptr->{quoter} =~ s/\s//g;
			$quoteLevel = length( $ptr->{quoter} );
	    }

	    ########################################
	    ## Do we have an empty line.          ##
	    ##
	    if( ! defined $ptr->{text}     ||
			$ptr->{text} =~ m|^\s+$|   ||
			$ptr->{text} eq ''         ) {
		
			#################
			## Do nothing. ##
		
	    } else {

			###########################################
			## Now we split the lines and go through ##
			##  each so that we can get signatures.  ##
			##
#			$ptr->{text} =~ s/\n/ /g;
		
			####################################
			##  Do some formatting first.     ##
			##
			$ptr->{text} =~ s/^\s+//g;
			$ptr->{text} =~ s/\s+$//g;

			#############################
			## Do we have a signature? ##
			if( $ptr->{text} =~ m|^xmca mailing list| ) {
				my @lines = split( /\n/, $ptr->{text} );
				if( defined $lines[1] && $lines[1] =~ m|xmca\@weber.ucsd.edu| && 
					defined $lines[2] && $lines[2] =~ m|http://dss.ucsd.edu/| ) {
						$quoteLevel = 999;
				}
			}

			#################################
			## Do we have a neglible line? ##
			if( $ptr->{text} !~ m|[A-Za-z0-9]| ) {
				# If we have no numbers or letters here, skip it.
			} else {

				###########################################
				## Add the message part to the database. ##
				##
				my $mb = &add_message_body({	message_id	=> $id,
								level     	=> $quoteLevel,
								original  	=> \$ptr->{raw},
								formatted 	=> \$ptr->{text},
								created_at	=> $timestamp,
								updated_at	=> $timestamp });

				#############################
				## Update global variable. ##
				my $cm_previous = $ptr->{text};
			}
	    }

	} else {

#	    print 'Error on parsing: Did not understanding ';
#	    print 'the ref() of message part.';
#	    print "\n\n";

	}
    }

    return 1;
}

