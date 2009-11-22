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
use Time::CTime;
use Time::ParseDate;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

use constant WIKI_TIME => '{{subst:CURRENTTIME}} {{subst:CURRENTDAYNAME}} {{subst:CURRENTMONTHNAME}} {{subst:CURRENTDAY}}, {{subst:CURRENTYEAR}}';
use constant WIKI_LOGTIME => '{{subst:CURRENTYEAR}}-{{subst:CURRENTMONTH}}-{{subst:CURRENTDAY2}} {{subst:CURRENTTIME}}';


# run through the process, but don't acutally output to Wikipedia.
my $NOPOST = 0; 

# Output to the debug location, not the ACTUAL location. Might also cause
# messages to STDOUT/STDERR.
my $DEBUG = 0;

# Log lines
my $LOG = '';

my $STARTTIME = time();


GetOptions ("nopost"    => \$NOPOST,
            "debug"     => \$DEBUG);


my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

# get some page contents
#my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );

my $start_epoch = parsedate('-30 days');
my $start_time = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime $start_epoch);

my $catlist = $mw->list ( { action => 'query',
  list => 'categorymembers',
  cmtitle => 'Category:Wikipedia:Books',
  cmnamespace => '2|4',
  cmlimit => '500',
  cmstart => $start_time,
  cmsort  => 'timestamp',
  #cmdir   => 'desc',
  cmprop => 'ids|title|sortkey|timestamp',
  ##ucdir => 'newer',  },
  },
  { max => 100, }
  ## not using a hook, we want the raw list
  ##hook => \&print_articles
) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};


my $sorted = {};
foreach my $entry (@$catlist) {
  #print Dumper($entry);
  my $namespace = $entry->{ns};
  my $title = $entry->{title};

  my $time = parsedate($entry->{timestamp});

  # make sure we didn't end up with too-early articles.
  next if ($time < $start_epoch);
  $entry->{day} = strftime('%d %b %Y', gmtime $time);
  $entry->{user} = get_creator($mw, $title, $entry->{pageid});

  push @{$sorted->{$namespace}{$time}}, $entry;
  #my $dtitle = decode_utf8($title);
}

my $output = output_entries($sorted);

post_output($tb, $output);

exit;

sub get_creator {
  my ($mw, $title, $pageid) = @_;

  my $info = $mw->api( {
    action  => 'query',
    prop    => 'revisions',
    titles  => $title,
    rvdir   => 'newer',
    rvlimit => 1,
  });
  my $user = $info->{query}{pages}{$pageid}{revisions}[0]{user};
  return $user;
}

sub post_output {
  my ($tb, $wikiContent) = @_;

  my $status;
  unless ($NOPOST) {
    my $location = 'User:TedderBot/New books alert/results';
    unless ($DEBUG) {
      # TODO: uncomment actual location
      #$location = 'Wikipedia:Books/New books';
    }
    my $ret = $tb->replacePage($location, $wikiContent, "update page latest results (bot edit)");
    $status = 'succeeded';
    unless ($ret) { $status = 'FAILED'; }
    #appendLog("Updated [[$location]] with $count articles, $status.");
  }

  return $status;
}

sub output_entries {
  my ($data) = @_;

  my $output = "__TOC__\n\n";
#print "namespaces: ", join(', ', keys %$data), "\n";

  $output .= output_namespace($data->{4}, "Community books");
  $output .= output_namespace($data->{2}, "User books");

  return $output;
}

sub output_namespace {
  my ($data, $header) = @_;

  my $ret = "==$header==\n";
  my %seen;
  foreach my $time (reverse sort keys %$data) {
    #my $day = 
    foreach my $entry (@{$data->{$time}}) {
      my $day = $entry->{day};
      #if ($seen{$day}++) {
      #  $ret .= "* $$entry{day}";
      #}
      #else {
      #  $ret .= "* '''$$entry{day}'''";
      #}
      my $user = "";
      my $txt_title = $$entry{title};
      $txt_title =~ s#^(Wikipedia:|User:.*?/)Books/##;
      if ($entry->{user}) {
        $user .= "created by {{User|$$entry{user}}}";
      }
      $ret .= "* '''$$entry{day}''' [[$$entry{title}|$txt_title]] $user\n";
    }
  }

  return $ret;
}
