#!/usr/bin/perl


use MediaWiki::API;
use strict;

print "hello world!\n";

  my $mw = MediaWiki::API->new();
  $mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';


# process the first 400 articles in the main namespace in the category "Surnames".
# get 100 at a time, with a max of 4 and pass each 100 to our hook.

my $count  = 0;

# TODO: check uclimit to make sure we haven't gone over the permissible,
# tune down as necessary.
$mw->list ( { action => 'query',
              list => 'usercontribs',
              ucuser => 'Tedder',
              uclimit =>'50',
              ucprop => 'ids|title|timestamp', 
              ucdir => 'newer',  },
            { max => 1, hook => \&print_articles } )
|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

exit;

# print the name of each article
sub print_articles {
  my ($ref) = @_;

  # ns is namespace: 0 for articles
  foreach (@$ref) {
    print $count++, " title: $_->{title}\n";
    print " timestamp: $_->{timestamp}\n";
    print " ns: $_->{ns}\n";
    #print join(' ', keys %$_), "\n\n";
    print "\n";
  }

}


