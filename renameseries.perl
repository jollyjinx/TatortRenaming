#!/usr/bin/perl

#tator script
#
#input: <option value="date">date: Name</option>


use strict;
use utf8;
use LWP::UserAgent;
use Encode;
use Data::Dumper;

use JNX::Configuration;

my %commandlineoption = JNX::Configuration::newFromDefaults( {																	
																	'nameofseries'							=>	['','string'],
																	'webname'								=>	['','string'],
																	'verbose'								=>	[0,'flag'],
																	'removematch'							=>	['','string'],
																	'debug'									=>	[0,'flag'],
															 }, __PACKAGE__ );


my $nameofseries = $0;

if( $commandlineoption{nameofseries} )
{
	$nameofseries = $commandlineoption{nameofseries};
}


my %database = undef;

my %fullnameofseries = (	'zeuge'				=>  'Der letzte Zeuge',
							'wickie'			=>	'Wickie und die starken Männer',
							'rockford'			=>	'Detektiv Rockford - Anruf genügt',
							'beck'				=>	'Kommissar Beck',
							'drhouse'			=>	'Dr. House',
							'jasper'			=>	'Jasper der Pinguin',
						);

my %webnameofseries 	= (
							'kommissar beck'	=>	'kommissar beck 1997',
						);

$nameofseries =~ s/^.*\///;
$nameofseries =~ s/\.perl$//;

if( defined $fullnameofseries{$nameofseries} )
{
	$nameofseries = $fullnameofseries{$nameofseries} if defined $fullnameofseries{$nameofseries};
}
else
{
	$nameofseries = ucfirst $nameofseries ;
}

$nameofseries = convertumlauts($nameofseries);

print $nameofseries."\n";

my @filenames;
@filenames = grep { /(\.(?:m4v|mov|mp4|mpeg|mpg)(?:.known)?)$/i && -f $_  } @ARGV;

createDatabase();

#print Data::Dumper->Dumper(\%database);


print "Filenames:@filenames\n";
foreach my $filename (@filenames)
{
	my $suffix = $1 if $filename =~ /(\.(?:m4v|mov|mp4|mpeg|mpg)(?:.known)?)$/;
	
	my $directory = './';
	
	if( $filename =~ m#^(.*\/)([^\/]+)$# )
	{
		$directory 	= $1;
		$filename	= $2;
	}

	my $testname = $filename;
	
	if( $commandlineoption{removematch} )
	{
		$testname =~ s/$commandlineoption{removematch}//;
	}
	
	$testname =~ s/[\_\s+]/ /g;
	$testname =~ s/^S\d+E\d+\.?\s*//;								#	S01E10
	$testname =~ s/(\.(?:m4v|mov|mp4|mpeg|mpg)(?:.known)?)//;	
	$testname =~ s/[,_.\-\s]\d\d\d\d-\d\d-\d\d\s*$//;				# 	2012-01-02
	$testname =~ s/\d+\s*[_\-\:\/]\s*(\d{2})//;						#	2-22
	$testname =~ s/[,_.\-\s]+(\s*[A-Z]{0,4}\s*,)*\s*[A-Z]{1,4}\s*(?:19|20)\d\d/ /;	# D, DK 2010
	
	$testname =~ s/[\-\s+]/ /g;
	$testname =~ s/[\s+\,]Teil\s*(\d+)(\s+|$)/ $1 /gi;
	$testname =~ s/[,\.\s]+(spielfilm|fernsehfilm|krimi|drama|polizeifilm|thriller)([,\.\s]+|$)//gi;
	$testname =~ s/^\d{4}\.\d{2}\.\d{2}-[^\-]+\-//;
	$testname =~ s/^\d+,\s+//;
	
	{
		my $quicknameofseries = quickname($nameofseries);
		
		$quicknameofseries	=~ s/[^a-zA-Z\d]/ /g;		
		$quicknameofseries	=~ s/(^\s+|\s+$)//;
		$quicknameofseries	=~ s/\s+/\\s\+/g;
		
		$testname = quickname($testname);
		$testname =~ s/^\s*$quicknameofseries+//i;
	}
		
	
	print STDERR "Testing: $testname\n";
	my $quickname = quickname($testname);

	
	if( $testname =~ m/(\d+)p\-ithd\-(\d+)/i  )
	{
		my $name = $database{overallepisode}{$2};

		$name .= $suffix?$suffix:'.m4v';
		
		if( $filename ne $name )
		{
			print "Renaming $filename -> $name\n";
			rename($directory.$filename,$directory.$name) ||die "Can't rename:$!";
		}
	}
	elsif( my $name = $database{quickname}{$quickname} )
	{
		$name .= $suffix?$suffix:'.m4v';
		
		if( $filename ne $name )
		{
			print "Renaming $filename -> $name\n";
			rename($directory.$filename,$directory.$name) ||die "Can't rename:$!";
		}
	
	}
	else
	{
		print STDERR "Can't find $quickname / $filename\n";
	}	
}

exit;



sub createDatabase
{	
	return undef if exists $database{episode};
	
	
	my $season = undef;
	
	my $filename = lc $0;
	chomp $filename;
	$filename =~ s/\.perl$//;
	$filename = $filename.'.episodes.txt';
	print $filename."\n";
	
	my @filecontent;
	
	if( ! -e $filename )
	{
		my $webnameofseries = lc $nameofseries;
		
		if( defined $webnameofseries{$webnameofseries} )
		{
			$webnameofseries =$webnameofseries{$webnameofseries};
		}
		
		
		if( $commandlineoption{webname} )
		{
			$webnameofseries = $commandlineoption{webname};
		}


		$webnameofseries =~ s/[^\da-z]+/ /gi;
		$webnameofseries =~ s/\s+/\-/g;
		
		
		my $url = "http://www.fernsehserien.de/$webnameofseries/episodenguide";
		
		print STDERR "Can't find episodes file - using $url to get them\n";

		open(WEB,"curl '$url' |");
		
		$/ = undef;
		my $websitecontent = <WEB>;
		
#		print $websitecontent."\n";
		my @lines;

		while( $websitecontent =~ m#(<tr.*?itemtype="http://schema.org/TVEpisode".*?</tr>)#gs )
		{
			my $line = $1;
			print "Match:$line\n" if $commandlineoption{verbose};
			push(@lines,$1);

			$line	=~ s/<[^>]+class="episodenliste-([^"]+)"[^>]+>/,$1=/g;
			$line	=~ s/<.*?>//g;
			$line	=~ s/episodennummer/overallepisode/;
			$line	=~ s/episodennummer/season/;

			my %linecontent;
			print "Split:$line\n"if $commandlineoption{verbose};

			foreach my $part (split(/,/,$line))
			{
				if( $part =~ m/^([^=]+)=(.+)\s*$/ )
				{
					$linecontent{lc $1}=$2;
				}
			}

			print Data::Dumper->Dumper(\%linecontent);# if $commandlineoption{verbose};

			if( length $linecontent{titel} )
			{
				print Data::Dumper->Dumper(\%linecontent);# if $commandlineoption{verbose};

				# next if $linecontent{titel} =~ m/\[?TBA\]?/i;
				next if length($linecontent{titel}) < 3;
				
				$linecontent{overallepisode} = $1	if $linecontent{overallepisode} =~ m/(\d+)/;
				$linecontent{season} = $1			if $linecontent{season} =~ m/(\d+)/;

				my $quickname = quickname($linecontent{titel});
				
				my $resultingtitle	= sprintf "S%02dE%02d.%s - %s",$linecontent{season},$linecontent{episodennummer},$nameofseries,$linecontent{titel};
				printf STDERR "%s -> %s\n",$resultingtitle,$quickname; # if $commandlineoption{verbose};
				
				$database{quickname}{$quickname}	 						= $resultingtitle;
				$database{overallepisode}{$linecontent{overallepisode}}		= $resultingtitle;
			}
		}

		if(!@lines)
		{
			die "Can't extract episodes from website:".$websitecontent."\n";
		}

		# print "Lines:\n".join("\n",@lines) if $commandlineoption{verbose};

		close(WEB);
		return;
	}
	else
	{	
		open(FILE,$filename);
		$/ = undef;
		
		@filecontent = split(/\n/,<FILE>);
		close(FILE);
	}
	
	while( @filecontent )
	{
		my $line = shift @filecontent;
		
		chomp($line);
		$line =	convertumlauts($line);
		my @columns = split(/\t/,$line);
		
		if( $line =~ /^\s*Staffel\s*(\d+)\s*$/ )
		{
			$season = $1;
		}	
		elsif( @columns >=3 )
		{
			my($overallepisode,$episode,$title,$originaltitle,$date,$originaldate) = @columns;
				
			#print STDERR "Line: $episode $title @columns".@columns."\n";
			next if $title =~ m/\[?TBA\]?/i;
			next if length($title) < 3;
			
			$overallepisode =~ s/[\[\]]//g;
			my $quickname = quickname($title);
			
			my $resultingtitle	= sprintf "S%02dE%02d.%s - %s",$season,$episode,$nameofseries,$title;
			printf STDERR "%s -> %s\n",$resultingtitle,$quickname;
			
			$database{quickname}{$quickname}	 			= $resultingtitle;
			$database{overallepisode}{$overallepisode}		= $resultingtitle;
		}
		else
		{
			print STDERR "Wrong format: $line\n";
		}
	}
}





sub convertumlauts
{
	my $name = shift;

	$name =~ s/\xc3\x84/ae/g;
	$name =~ s/\xc3\x9c/ue/g;
	$name =~ s/\xc3\x96/oe/g;
	
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

	$name =~ s/A\xCC\x88/ae/gi;
	$name =~ s/U\xCC\x88/ue/gi;
	$name =~ s/O\xCC\x88/oe/gi;

	return $name;
}

sub quickname($)
{
	my $name = shift;
	
	$name = lc convertumlauts($name);


	$name =~ s/([aou])e/$1/g;
	$name =~ s/[^\da-z]+/ /gi;
	
	$name =~ s/(^|\s)(der|die|das)(\s|$)/ /g;
	$name =~ s/\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;
	
	return $name;
}
