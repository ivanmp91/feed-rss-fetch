#!/usr/bin/perl
# Requires install this modules: 
# perl-Gearman-Server
# perl-Gearman
# perl-LWP-UserAgent-Determined
# perl-XML-FeedPP
# perl-DateTime
# perl-DateTime-Format-W3CDTF (ISO_8601)
# perl-Class-DBI-mysql

use strict;
use warnings;
use Gearman::Worker;

require FeedDB;
require FeedParser;

my $feedb= FeedDB->new();
my $parser = FeedParser->new();
my $worker= new Gearman::Worker;

$worker->job_servers('192.168.1.133:4730');
$worker->register_function(parseChannel=>\&parseChannel);
$worker->work() while 1;

#Parse the last feed items from a channel and store it to the database 
sub parseChannel{
	my $job=shift;
	my $channel=$job->arg;
	my @entries;
	my $modify=$feedb->getLastFeedModify($channel);
	if($modify){
		@entries=$parser->parseFeed($channel,$modify);
		if(${entries}[0] ne 0){
			$feedb->feedPersist(@entries,$channel);
			return 1;
		}
		else{
			return 0;
		}
	}
	else{
		@entries=$parser->parseFeed($channel);
		if(${entries}[0] ne 0){
			$feedb->feedPersist(@entries,$channel);
			return 1;
		}
		else{
			return 0;
		}
	}
}
