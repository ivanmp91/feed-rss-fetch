#!/usr/bin/perl
# Requires install this modules: 
# perl-HTTP-Request-Params
# perl-LWP-UserAgent-Determined
# perl-XML-FeedPP
# perl-DateTime
# perl-DateTime-Format-W3CDTF (ISO_8601)
# perl-Class-DBI-mysql

use strict;
use warnings;
use POSIX qw(strftime);

require FeedDB;
require FeedParser;

my $feedb= FeedDB->new();
my $parser = FeedParser->new();

parseChannels();

#Get all url channels from database and get the last feed items to store
# in database
sub parseChannels{
	my @channels=@{$feedb->getUrlChannels()};
	my @entries;
	foreach(@channels){
		my $modify=$feedb->getLastFeedModify($_);
		if($modify){
			@entries=$parser->parseFeed($_,$modify);
			if(${entries}[0] ne 0){
				$feedb->feedPersist(@entries,$_);
			}
		}
		else{
			@entries=$parser->parseFeed($_);
			if(${entries}[0] ne 0){
				$feedb->feedPersist(@entries,$_);
			}
		}
	}
}

#Get the current time in format ISO8601
sub getCurrentTime{
	my $now = time();
    my $tz = strftime("%z", localtime($now));
    return strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz . "\n";
}
