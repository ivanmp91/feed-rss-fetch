#!/usr/bin/perl

use strict;
use warnings;
use DBI;

package FeedDB;

sub new{
	my $class=shift;
	my $self={
		"database"=>"droid_rss",
		"host"=>"192.168.1.130",
		"user"=>"root",
		"password"=>"rootroot"
		};
	
	bless $self,$class;
	return $self;
}

############# MYSQL Functions #############

#Insert into database all items from one feed
sub feedPersist{
	my $self=shift;
	my @items=@{$_[0]};
	my $channel=$_[1];
	my $db = DBI->connect('DBI:mysql:'.$self->{"database"}.';host='. $self->{"host"}.'', ''.$self->{"user"}.'', ''.$self->{"password"}.'') 
	|| die "Could not connect to database: $DBI::errstr";
	$db->do(qq{SET NAMES 'utf8';});
	my $url;
	my $title;
	my $description;
	my $date;
	my $author;
	
	for(my $i=0;$i<scalar @items;$i++){
		$title= $items[$i]{"title"};
		$url= $items[$i]{"url"};
		$description= $items[$i]{"description"};
		$date= $items[$i]{"date"};
		$author= $items[$i]{"author"};
		
		if($date && $title){
			my $insert= $db->prepare_cached('INSERT INTO feed_item VALUES(NULL,?, ?, ?, ?, ?, ?)');
			$insert->execute($channel, $url, $title,$date,$description,$author) or return 0;
		}
	}
	$db->disconnect();
}

#Return a reference for an array storing the url of all channels in database
sub getUrlChannels{
	my $self=shift;
	my $db = DBI->connect('DBI:mysql:'.$self->{"database"}.';host='. $self->{"host"}.'', ''.$self->{"user"}.'', ''.$self->{"password"}.'') 
	|| die "Could not connect to database: $DBI::errstr";
	$db->do(qq{SET NAMES 'utf8';});
	my @urls;
	my $query = $db->prepare('SELECT url FROM feed_channel');
	$query->execute();
	
	while(my $url = $query->fetchrow_array()){
		push @urls,$url;
	}
	$query->finish();
	$db->disconnect();
	
	return \@urls;
}

#Return the last time updated for one channel
sub getLastFeedModify{
	my $self=shift;
	my $channel=shift;
	my $db = DBI->connect('DBI:mysql:'.$self->{"database"}.';host='. $self->{"host"}.'', ''.$self->{"user"}.'', ''.$self->{"password"}.'') 
	|| die "Could not connect to database: $DBI::errstr";
	$db->do(qq{SET NAMES 'utf8';});
	my $query= $db->prepare("select DATE_FORMAT(pub_date,'%Y-%m-%dT%TZ') from feed_item where channel_url = ? order by pub_date desc limit 1");
	$query->execute($channel);
	my $date=$query->fetchrow_array();
	$query->finish();
	$db->disconnect();
	
	return $date;
}

return 1;
