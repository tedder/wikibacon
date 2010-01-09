#!/usr/bin/perl

###############################################################################
#
# Copyright (c) 2009 Ted Timmons  <ted-bacon@perljam.net>
# This software is released under the MIT license, cited below.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################


use Data::Dumper;
use CGI qw/-utf8/;
use Unicode::UCD 'charinfo';
use Encode 'decode_utf8';

use strict;

use lib '/home/tedt/git/wikibacon/';
use TedderBot::UserContribs;

binmode STDOUT, ":utf8";
print "hello world!\n";

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 1 );
my $mw = $tb->getMWAPI();


my $backlist = $mw->list ( { action => 'query',
  list => 'embeddedin',
  eititle => 'Template:R uncategorized',
  eilimit => '5',
  #ucprop => 'ids|title|timestamp',
  { max => 2, }
  #hook => &process_article
 } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

my $count = 0;
foreach my $entry (@$backlist) {
  my $namespace = $entry->{ns};
  my $title = $entry->{title};
  ++$count;

  #process_article($ref);
  process_article($title);

#if ($count > 5) { die "seen 5."; }

}


print "count: $count\n";

exit;

sub process_article {
  my ($title) = @_;

  my $page = $mw->get_page( { title => $title } );
  my $content = $page->{'*'};
  if ($content =~ m/{{bots/) {
    print "exclusion page, skipping: $title\n";
    return 0;
  }

  $content =~ s/\s*{{R (uncategorized|from \.\.\.).*?}}\s*//ig;

  #print "title: $title .. content: $content\n";

  if ($content =~ m/\#redirect\s*\[\[(.*?)\]\]/ig) {
    my $target = $1;

print "comparing $title / $target\n";
    if (lc $title eq lc $target) {
      print "resort to alternative capitalization: $title / $target\n";
    } elsif (lc $title eq strip_diacritics(lc $target)) {
      print "resort to stripped diacritics: $title / $target\n";
    }
  } else {
    print "couldn't find redirect: $title / $content\n";
    exit;
  }

  if ($content eq $page->{'*'}) {
    print "no change on page: '$title'\n";
  }

  my $es = 'Removing [[:Template:R uncategorized]] per [[Wikipedia:Templates for discussion/Log/2009 December 1#Template:R uncategorized|TfD]]';

  #print "final content: |$content|\n";
}


# diacritics code stolen (and modified) from here:
# http://www.lemoda.net/perl/strip-diacritics/index.html
sub strip_diacritics
{
    my ($diacritics_text) = @_;
    my @characters = split '', $diacritics_text;
    for my $character (@characters) {
        # Reject non-word characters
        next unless $character =~ /\w/;
        my $decomposed = decompose($character);
    }
    my $stripped_text = join '', @characters;
    return $stripped_text;
}

# Decompose one character. This is the core part of the program.

sub decompose
{
    my ($character) = @_;
    # Get the Unicode::UCD decomposition.
    my $charinfo = charinfo (ord $character);
    my $decomposition = $charinfo->{decomposition};
    # Give up if there is no decomposition for $character
    return $character unless $decomposition;
    # Get the first character of the decomposition
    my @decomposition_chars = split /\s+/, $decomposition;
    $character = chr hex $decomposition_chars[0];
    # A character may have multiple decompositions, so repeat this
    # process until there are none left.
    return decompose ($character);
}

