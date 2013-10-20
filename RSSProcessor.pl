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
use LWP::Simple;
use XML::FeedPP;
use POSIX qw(strftime);
use DBI;
use LWP::UserAgent;

#my $url = "http://planetasysadmin.com/rss20.xml";

parseChannels();

#Get all url channels and parse It to DB
sub parseChannels{
	my @channels=@{getUrlChannels()};
	
	foreach(@channels){
		parseFeed($_);
	}
}

#Try http connectivity and valid content-type header. return 1 for success or 0 to fail
sub tryHttpUrl{
	my $ua = new LWP::UserAgent;
	my $url=shift;
	my $request = new HTTP::Request('GET', $url);
	my $response = $ua->request($request);
	
	if ($response->is_success) {
		my $content= $response->content_type();
		if($content =~ "^text/xml" || $content =~ "^application/atom+xml"
		|| $content =~ "^application/rdf+xml" || $content =~ "^application/rss+xml"  
		|| $content =~ "^application/xml" ){
			return 1;
		}
		else{
			return 0;
		}
	} 
	else {
		return 0;
	}
}

#Get all the feeds from a url and return an array of hash with all the entries
sub parseFeed{
	my $source = shift;
	my $httpTest=tryHttpUrl($source);
	
	if($httpTest eq 1){
		my $modify=getLastFeedModify($source);
		if($modify){
			storeLastItems($modify,$source);
		}
		else{
			storeNewItems($source);
		}
	}
}

#Store the last feed items from the last modify date
sub storeLastItems{
	my $modify=shift;
	my $source=shift;
	my $feed = XML::FeedPP->new($source);
	my $url;
	my $title;
	my $description;
	my $date;
	my $author;
	my @entries;
	$feed->normalize();
	foreach my $item ( $feed->get_item() ) {
		$date=$item->pubDate();
		$url=$item->link();
		$title=$item->title();
		$description=$item->description();
		$author=$item->author();
		if($date gt $modify){
			push @entries,{"url"=>$url,"title"=>$title,"date"=>$date,"author"=>$author,"description"=>$description};
		}
	}
	feedPersist(\@entries,$source);
}

#Store the last 4 items of the feed
sub storeNewItems{
	my $source=shift;
	my $feed = XML::FeedPP->new($source);
	my $url;
	my $title;
	my $description;
	my $date;
	my $author;
	my @entries;
	$feed->normalize();
	$feed->limit_item(4);
	foreach my $item ( $feed->get_item() ) {
		$date=$item->pubDate();
		$url=$item->link();
		$title=$item->title();
		$description=$item->description();
		$author=$item->author();
		push @entries,{"url"=>$url,"title"=>$title,"date"=>$date,"author"=>$author,"description"=>$description};
	}
	feedPersist(\@entries,$source);
}

#Get the current time in format ISO8601
sub getCurrentTime{
	my $now = time();
    my $tz = strftime("%z", localtime($now));
    return strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz . "\n";
}

############# MYSQL Functions #############

#Insert into database all items from one feed
sub feedPersist{
	my @items=@{$_[0]};
	my $channel=$_[1];
	my $db = DBI->connect('DBI:mysql:dax2;host=192.168.1.130', 'root', 'rootroot') || die "Could not connect to database: $DBI::errstr";
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
	my $db = DBI->connect('DBI:mysql:dax2;host=192.168.1.130', 'root', 'rootroot') || die "Could not connect to database: $DBI::errstr";
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
#select DATE_FORMAT(pub_date,'%Y-%m-%dT%TZ') from feed_item where url like '%opentodo%' order by pub_date desc;
sub getLastFeedModify{
	my $channel=shift;
	my $db = DBI->connect('DBI:mysql:dax2;host=192.168.1.130', 'root','rootroot') || die "Could not connect to database: $DBI::errstr";
	$db->do(qq{SET NAMES 'utf8';});
	my $query= $db->prepare("select DATE_FORMAT(pub_date,'%Y-%m-%dT%TZ') from feed_item where channel_url = ? order by pub_date desc limit 1");
	$query->execute($channel);
	my $date=$query->fetchrow_array();
	$query->finish();
	$db->disconnect();
	
	return $date;
}
