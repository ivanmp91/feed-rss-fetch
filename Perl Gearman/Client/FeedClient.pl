#!/usr/bin/perl

use strict;
use warnings;
use Gearman::Client;

require FeedDB;

my $feedb= FeedDB->new();
my @channels=@{$feedb->getUrlChannels()};

my $client= new Gearman::Client;
$client->job_servers('172.31.4.207:4730','172.31.4.208:4730');

foreach(@channels){
	my $result_ref=$client->do_task('parseChannel',$_);
}
