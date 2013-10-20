#!/usr/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use XML::FeedPP;

package FeedParser;

sub new{
	my $class=shift;
	my $self={};
	bless $self,$class;
	
	return $self;
}

#Try http connectivity and valid content-type header. return 1 for success or 0 to fail
sub tryHttpUrl{
	my $ua = new LWP::UserAgent;
	my $url=shift;
	chomp(${$url});
	if(${$url} !~/^http:\/\// && ${$url} !~/^https:\/\//){
		${$url}="http://".${$url};
	}
	my $request = new HTTP::Request('GET', ${$url});
	my $response = $ua->request($request);
	if ($response->is_success) {
		my $content= $response->content_type();
		if($content eq "text/xml" || $content eq "application/atom+xml"
		|| $content eq "application/rdf+xml" || $content eq "application/rss+xml"  
		|| $content eq "application/xml" ){	
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
	my $self=shift;
	my $source = shift;
	my $httpTest=tryHttpUrl(\$source);
	my $modify=shift;
	
	if($httpTest ==1){
		if($modify){
			return getLastItems($modify,$source);
		}
		else{
			return getNewItems($source);
		}
	}
	else{
		return 0;
	}
}

# Get the last items from the last time, and return an array reference 
# with all the feeds items
sub getLastItems{
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
	return \@entries;
}

#Store the last 4 items of the feed
sub getNewItems{
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
	return \@entries;
}

return 1;
