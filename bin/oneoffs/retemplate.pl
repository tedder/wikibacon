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


use strict;
use Data::Dumper;
use Encode;
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

use constant WIKI_LOGTIME => '{{subst:CURRENTYEAR}}-{{subst:CURRENTMONTH}}-     {{subst:CURRENTDAY2}} {{subst:CURRENTTIME}}';

# Good for trial runs- set much higher when it is running.
use constant MAX_TO_CHANGE => 1;

# Number of seconds between edits. Running time (in hours) 
# can be approximated by NUM_PAGES * SLEEP_TIME / 3600
use constant SLEEP_TIME    => 30;

# Don't include "Template:" namespace. Just the specific template name.
# It'll look for "Template:$CHANGE_FROM" and will change {{$CHANGE_FROM
# to {{$CHANGE_TO. Note it doesn't look for {{WikiProject $CHANGE_FROM.
my $CHANGE_FROM = "Children'sLiteratureWikiProject";
# Again, no namespace. Case is important here.
my $CHANGE_TO   = "WikiProject Children's literature";

# If true, run through the process, but don't acutally output to Wikipedia.
my $NOPOST = 0; 

# Output to the debug location, not the ACTUAL location. Might also cause
# messages to STDOUT/STDERR.
my $DEBUG = 0;

# Log lines
my $LOG = '';

GetOptions ("nopost"    => \$NOPOST,
            "debug"     => \$DEBUG);


my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

my $backlist = $mw->list ( { action => 'query',
  list => 'backlinks',
  bltitle => 'Template:' . $CHANGE_FROM,
  blnamespace => '0',
  bllimit => '500',
  blredirect => '500',
  #ucprop => 'ids|title|timestamp',
  #ucdir => 'newer',  },
  { max => 200, }
  # not using a hook, we want the raw list
  #hook => \&print_articles
} ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

my $emblist = $mw->list ( { action => 'query',
  list => 'embeddedin',
  eititle => 'Template:' . $CHANGE_FROM,
  eilimit => '500',
  #ucprop => 'ids|title|timestamp',
  { max => 200, }
  #hook => &process_article
 } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

print "Collected transcluded pages: ", (scalar @$backlist + scalar @$emblist), " possibilities\n";

my %seen;
my $count = 0;
foreach my $entry (@$backlist, @$emblist) {
  my $title = $entry->{title};
  my $dtitle = decode_utf8($title);

  next if $seen{$title}++;

  my $page = $mw->get_page( { title => $title } );
  my $c = $page->{'*'};

  if ($c =~ /{{(no)?bots/) {
     _debug("'''skipping [[$title]], bot exclusion.'''\n");
     next;
  }

  (my $new_c = $c) =~ s/{{$CHANGE_FROM/{{$CHANGE_TO/g;
  if ($new_c eq $c) {
     _debug(":Couldn't change [[$title]], didn't match regex.\n");
  } elsif (! $NOPOST) {

    # this is a safety trigger to make sure we don't actually edit
    # real articles without approval. Remove before flight.
    print "updating $title\n";
    # Remove exit before flight.
    # exit;


    $tb->replacePage($title, $new_c, "replace [[:Template:$CHANGE_FROM]] with [[:Template:$CHANGE_TO]] (bot edit)");
    _debug(":updated [[$title]]\n");

    # testing: make sure we don't change more than N.
    if (++$count >= MAX_TO_CHANGE) {
      _debug("\nWe've changed the maximum allowed pages. Outta here.\n");
      last;
    }

    # Don't hit the servers too fast, and make sure there is time
    # to fix a problem before it becomes a bigger problem.
    sleep SLEEP_TIME;
  }

  #print "done.";

  #print "\n";
}

$tb->appendPage('User:TedderBot/TranscludeReplace/log', $LOG, WIKI_LOGTIME, "update TranscludeReplace log (bot edit)");

_debug(":updated pages: $count\n");

exit;

sub _debug {
  $LOG .= join('', @_);
}
