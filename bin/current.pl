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

die "hey! don't run this until it is approved.\n";

# how many 'idle' hours should the template stay up before we remove it?
use constant CURRENT_THRESHOLD_HOURS => 2;

# how long since we last removed the template until we remove it again?
# be aware of edit warring before dialing this down.
use constant OUR_THRESHOLD_HOURS => 24;

use constant WIKI_LOGTIME => '{{subst:CURRENTYEAR}}-{{subst:CURRENTMONTH}}-{{subst:CURRENTDAY2}} {{subst:CURRENTTIME}}';

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

  # skip this page if it's marked NoBot.
  return undef if isBotExclusion($c);

  # old way of doing it- keeping for now.
  #if ($c =~ /{{(no)?bots/) {
  #  ++$count{skip_bots};
  #  _debug("'''skipping [[$title]], bot exclusion.'''\n");
  #  next;
  #}

  my $sec = delta_seconds($page->{timestamp});
  my $hours = sprintf('%.1f', $sec/3600);
  $OUT .= qq(| [[$title]]
| $hours
|-
);


  # see if we need to remove the tag, and then do it.
  if (checkRemoval($title, $page, $hours)) {
    removeCurrentTemplate($title, $c);
  }



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

sub checkRemoval {
  my ($title, $page, $last_edit_hours) = @_;

  # should we be removing the template? Multi-step process:
  # * are we past MAX_CURRENT_NOEDIT_AGE? (specified in hours)
  # * have we removed it in the past 24 hours already?
  #     we don't want to edit war.
  #delete $page->{'*'}; print Dumper($page); exit;

  # last edit time in hours, -1 if we didn't find it.
  my $our_last_edit_hours = last_tedderbot_edit($title);

  if ($last_edit_hours > CURRENT_THRESHOLD_HOURS && $our_last_edit_hours >= 0 && $our_last_edit_hours > OUR_THRESHOLD_HOURS) {
    return 1;
  }

  return undef;
}

# simply use a regex to remove the current template, then update the page.
sub removeCurrentTemplate {
  my ($title, $content) = @_;

  $content =~ s#{{current.*?}}##i;
  $tb->replacePage($title, $content, "[[User:TedderBot/CurrentPruneBot|remove stale current-event template]], please see [[WP:CAFET]]. (bot edit)");
  _debug(":updated [[$title]]\n");
  print "updating $title\n";
}

# When were we on this page last?
sub last_tedderbot_edit
{
  my ($title) = @_;

  my $info = $mw->api( {
    action  => 'query',
    prop    => 'revisions',
    titles  => $title,
    rvdir   => 'older',
    rvlimit => 500,
  });

  my @pages = keys %{$info->{query}{pages}};
  my $pageid = shift @pages;
  foreach my $rev ( @{$info->{query}{pages}{$pageid}{revisions}} ) {
    if (lc $rev->{user} eq 'ukexpat') {
    #if (lc $rev->{user} eq 'tedderbot') {
      my $ts = parsedate($rev->{timestamp}, GMT => 1);
      #print "found us. ", scalar localtime($ts), "\n";
      my $seconds = (parsedate(scalar localtime()) - $ts);
      return $seconds / 3600;
    }
  }

  return -1;

}

sub delta_seconds {
  my ($timestamp) = @_;

  my $delta = parsedate(scalar localtime()) - parsedate($timestamp, GMT => 1);
  return $delta;
}


sub _debug {
  $LOG .= join('', @_);
}

sub isBotExclusion {
  my ($content) = @_;

  if ($content =~ m#{{nobots|bots|deny=tedderbot}}#i) {
    _debug("we've been asked to avoid changing this page, so we will.\n");
    return 1;
  }

  return undef;
}
