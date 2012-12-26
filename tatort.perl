#!/usr/bin/perl

#tator script
#
#input: <option value="date">date: Name</option>


use strict;
use utf8;
use LWP::UserAgent;
use Encode;
use Data::Dumper;

my %database = undef;


my @filenames;

@filenames = grep { /\.(m4v|mov|mp4|mpeg|mpg)$/i && -f $_  } @ARGV;

createDatabase();

#print Data::Dumper->Dumper(\%database);


print "Filenames:@filenames\n";
foreach my $filename (@filenames)
{
	my $path = undef;

	if( $filename =~ m#(.*\/)([^\/]+)$# )
	{
		$path 		= $1;
		$filename	= $2;
	}
	
	

	my $testname = $filename;
	$testname =~ s/\.(m4v|mov|mp4|mpeg|mpg)$//;
	$testname =~ s/^\s*Tatort[\_\-\t ]+//;
	$testname =~ s/[\-\_\t ]+(Spielfilm|Fernsehfilm|Krimi)\s.*//;
	$testname =~ s/^\d{4}\.\d{2}\.\d{2}-[^\-]+\-//;
	$testname =~ s/^\d+,\s+//;
	
	my $quickname = quickname($testname);
	
	if( exists $database{episode}{$quickname}{date} )
	{
		if( !exists $database{episode}{$quickname}{detective} )
		{
			updateEpisode($quickname);
		}
		
	
		my $name = $database{episode}{$quickname}{date}.'-'.$database{episode}{$quickname}{detective}.'-'.$database{episode}{$quickname}{name}.'.m4v';
	
		$name =~ s/\xE4/ä/g;
		$name =~ s/\xFC/ü/g;
		$name =~ s/\xF6/ö/g;
		
		$name =~ s/\xC4/Ä/g;
		$name =~ s/\xDC/Ü/g;
		$name =~ s/\xD6/Ö/g;
		
		$name =~ s/\xDF/ß/g;

        $name =~ s/\xc3\xa4/ae/g;
        $name =~ s/\xc3\xbc/ue/g;
        $name =~ s/\xc3\xb6/oe/g;
        $name =~ s/\xc3\x9f/ss/g;


		if( $filename ne $name )
		{
			print "Renaming $filename -> $name\n";
			rename($path.$filename,$path.$name) ||die "Can't rename:$path$filename -> $path$name due to:$!";
		}
	
	}
	else
	{
		print STDERR "Can't find $quickname / $filename\n";
	}	
}

exit;





sub getUrl($)
{
	my($url) = (@_);

	my $userAgent	= LWP::UserAgent->new;
	
	$userAgent->agent("JNXTatortScript/0.1");

	my $request		= HTTP::Request->new(GET => $url);
	my $response	= $userAgent->request($request);

	if( $response->is_success )
	{
		my $isodata	= $response->content();

		my $data = Encode::decode('iso-8859-1', $isodata);

		$data =~ s/\xE4/ä/g;
		$data =~ s/\xFC/ü/g;
		$data =~ s/\xF6/ö/g;
		
		$data =~ s/\xC4/Ä/g;
		$data =~ s/\xDC/Ü/g;
		$data =~ s/\xD6/Ö/g;
		
		$data =~ s/\xDF/ß/g;
		
		return $data;
	}
	else
	{
		print STDERR "Got invalid response:".Data::Dumper->Dumper($response);
	
	}
	return undef;
}


sub createDatabase
{	
	return undef if exists $database{episode};
	
	my $data	=	getUrl('http://www.daserste.de/unterhaltung/krimi/tatort/sendung/index.html');


	printf STDERR "Got data from url, length:%d\n",length($data);	
	
	if( $data =~ m#<select name="filterBoxGroup"(.*?)</select>#s )
	{
		my $options = $1;
	
		print STDERR "Got detectives.\n";
		
		while( $options =~ m#<option value="([^"]+)">(.*?)</option>#gs )
		{
			my ($detectiveurl,$detectives) = ($1,$2);

			$detectives =~ s/\s+und\s+.*//;
						
			if( $detectives =~ m/(\S+)\s*$/ )
			{
				my $quickdetective = quickname($1);
				print STDERR "Got detective:$quickdetective = $1\n";
				
				$database{detective}{$quickdetective} = $1;
			}
		}
	}
	
	if( $data =~ m#<select name="filterBoxDate"(.*?)</select>#s )
	{
		my $options = $1;
		print STDERR "Got episodes.\n";
		

		while( $options =~ m#<option\s+value="([^"]+)">(\d{2})\.(\d{2})\.(\d{4}):\s*(.*?)</option>#gs )
		{
			my($urlname,$day,$month,$year,$name) = ($1,$2,$3,$4,$5);
			
			my $quickname = quickname($name);
			
			# my $test = $name;
			# $test =~ s/[A-Za-z\s-\d]//g;
			# print STDERR "Quickname:".$quickname.":".$name.':'.unpack('H*',$test)."\n";
			
			
			if( exists $database{episode}{$quickname}{date} )
			{
				print "name already known $quickname $name\n";
				delete $database{episode}{$quickname};
			}
			else
			{
				$database{episode}{$quickname}{name}		= $name;
				$database{episode}{$quickname}{urlname}		= $urlname;
				$database{episode}{$quickname}{date}		= $year.'.'.$month.'.'.$day;
				$database{episode}{$quickname}{episodedate}	= $day.'.'.$month.'.'.$year;
				$database{episode}{$quickname}{episodeyear}	= $year;
			}
		}
	}
}



sub updateEpisode($)
{
	my ($quickepisodename) = (@_);
	
	if( ! exists $database{episode}{$quickepisodename}{urlname} )
	{
		print STDERR "Did not find episode: $quickepisodename\n";
		return undef;
	}

	my $detailurl = 'http://www.daserste.de/unterhaltung/krimi/tatort/sendung/'.$database{episode}{$quickepisodename}{episodeyear}.'/'.$database{episode}{$quickepisodename}{urlname}.'.html';
	
	# print STDERR "Detail url:$detailurl\n";
	
	my $data	=	getUrl($detailurl);
	
	# print "Found $data";
	
	if( $data =~ m#<table\s+class="besetzungTabelle">(.*?)</table>#s )
	{
		my $rows = $1;

		# print STDERR "Got artists and roles.\n";
		
		ARTISTS: while( $rows =~ m#<td\s+class="block1"\s+scope="row">(.*?)</td>#sg )
		{
			my @namingparts = split( /\s+/ ,$1);
			
			# print STDERR "Detective name parts: ".join(',',@namingparts)."\n";
			
			foreach my $detective (@namingparts)
			{
				my $quickdetective = quickname($detective);
				
				if( exists $database{detective}{$quickdetective} )
				{
					$database{episode}{$quickepisodename}{detective}	= $database{detective}{$quickdetective};
					last ARTISTS;
				}
			}
		}
	}
}





sub quickname($)
{
	my $name = shift;
	
	$name =~ s/\xc3\xa4/ae/g;
	$name =~ s/\xc3\xbc/ue/g;
	$name =~ s/\xc3\xb6/oe/g;
	$name =~ s/\xc3\x9f/ss/g;
	
	$name =~ s/\xE4/ae/g;
	$name =~ s/\xFC/ue/g;
	$name =~ s/\xF6/oe/g;
	
	$name =~ s/\xC4/ae/g;
	$name =~ s/\xDC/ue/g;
	$name =~ s/\xD6/oe/g;
	
	$name =~ s/\xDF/ss/g;

	$name =~ s/\%E4/ae/g;
	$name =~ s/\%FC/ue/g;
	$name =~ s/\%F6/oe/g;
	
	$name =~ s/\%C4/ae/g;
	$name =~ s/\%DC/ue/g;
	$name =~ s/\%D6/oe/g;
	
	$name =~ s/\%DF/ss/g;

	$name =~ s/ä/ae/g;
	$name =~ s/ö/oe/g;
	$name =~ s/ü/ue/g;
	$name =~ s/Ä/Ae/g;
	$name =~ s/Ö/Oe/g;
	$name =~ s/Ü/Ue/g;
	$name =~ s/ß/ss/g;	

	$name =~ s/([aou])e/$1/g;
	$name =~ s/ss//g;
	
	$name =~ s/[^a-z]//gi;
	
	return lc $name;
}
