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
use Time::ParseDate;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

use constant WIKI_LOGTIME => '{{subst:CURRENTYEAR}}-{{subst:CURRENTMONTH}}-     {{subst:CURRENTDAY2}} {{subst:CURRENTTIME}}';

# Good for trial runs- set much higher when it is running.
use constant MAX_TO_CHANGE => 2;

# Number of seconds between edits. Running time (in hours) 
# can be approximated by NUM_PAGES * SLEEP_TIME / 3600
use constant SLEEP_TIME    => 2;

# If true, run through the process, but don't acutally output to Wikipedia.
my $NOPOST = 0; 

# Output to the debug location, not the ACTUAL location. Might also cause
# messages to STDOUT/STDERR.
my $DEBUG = 0;

# Log lines
my $LOG = '';
my $OUT = '';

GetOptions ("nopost"    => \$NOPOST,
            "debug"     => \$DEBUG);


my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

$OUT .= qq(
{|class="wikitable sortable"
! Page
! Hours since last edited
|-
);


checkTemplate('Template:Current');
checkTemplate('Template:Current related');

$OUT .= "|}\n";

$tb->replacePage('User:TedderBot/CurrentPruneBot/census', $OUT, "census (bot edit)");

exit;

sub checkTemplate {
  my ($templateName) = @_;

  my $backlist = $mw->list ( { action => 'query',
    list => 'backlinks',
    bltitle => $templateName,
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
    einamespace => '0',
    eititle => $templateName,
    eilimit => '500',
    #ucprop => 'ids|title|timestamp',
    { max => 200, }
    #hook => &process_article
   } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  my $count = 0;
  my %seen;

  foreach my $entry (@$backlist, @$emblist) {
    my $title = $entry->{title};
    next if $seen{$title}++;
    processArticle($entry);
  }

  #print Dumper(\%count);

  _debug(":updated pages: $count\n");
  #$tb->appendPage('User:TedderBot/AnimeVoiceLink/log', $LOG, WIKI_LOGTIME, "update log (bot edit)");

  return undef;
}

sub processArticle {
  my ($entry) = @_;
  my $title = $entry->{title};
  my $dtitle = decode_utf8($title);

  my %count;

  #print "title: $title\n";
  my $page = $mw->get_page( { title => $title } );

  my $c = $page->{'*'};

  if ($c =~ /{{(no)?bots/) {
    ++$count{skip_bots};
    _debug("'''skipping [[$title]], bot exclusion.'''\n");
    next;
  }

  my $sec = delta_seconds($page->{timestamp});
  my $hours = sprintf('%.1f', $sec/3600);
  $OUT .= qq(| [[$title]]
| $hours
|-
);


  # should we be removing the template? Multi-step process:
  # * are we past MAX_CURRENT_NOEDIT_AGE? (specified in hours)
  # * have we removed it in the past 24 hours already?
  #     we don't want to edit war.
  # TODO: left off here.




  #$tb->replacePage($title, $new_c, "link anime voices, see [[User:TedderBot/AnimeVoiceLink]] (bot edit)");
  #_debug(":updated [[$title]]\n");
  #print "updating $title\n";

  # testing: make sure we don't change more than N.
  #if (++$count >= MAX_TO_CHANGE) {
  #  _debug("\nWe've changed the maximum allowed pages. Outta here.\n");
  #  last;
  #}

  return \%count;
}

sub delta_seconds {
  my ($timestamp) = @_;

  my $delta = parsedate(scalar gmtime()) - parsedate($timestamp);
  return $delta;
}


sub _debug {
  $LOG .= join('', @_);
}
sub parseTemplate {
  my ($str) = @_;

#print "PT str: $str\n";
  # break the string apart- shift off the first, since we
  # know what it is.
  my @substr = split('\|', $str);
  shift @substr;
#print "substrs: ", join("--", @substr), "\n";

  my @retbits;
  foreach my $bit (@substr) {
    #print "checking bit: $bit\n";
    # is it already wikilinked? If not, make it so, Scotty.
    if ($bit =~ /^\[\[.+\]\]$/) {
      push @retbits, $bit;
    } elsif ($bit eq '') {
      print "skipping blank bit\n";
    } else {
      push @retbits, '[[' . $bit . ']]';
    }
  }

  # which template? "anime voices" or "anime voice"?
  my $ret = join('|', 'Anime voices', @retbits);
  if (scalar @retbits == 1) {
    $ret = join('|', 'Anime voice', @retbits);
  }

  # build up a replacement string, return it.
  return $ret;
}
