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
use Time::Local;
use lib '/home/tedt/git/wikibacon/';
use TedderBot::OregonArticles;

use constant NOW => Time::Local::timegm(gmtime(time()));
use constant EPOCH_OFFSET => Time::Local::timegm(gmtime(time())) - Time::Local::timegm(localtime(time()));

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


my $tb = TedderBot::OregonArticles->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

#my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );

my $data = getParticipants($mw);
#my $data = { 'active' => { 'Little Mountain 5' => 1 }};
#print Dumper($data); exit;
my $content = parseParticipants($mw, $tb, $data);

my $ret = $tb->replacePage('User:TedderBot/OreBot/MemberActivity', $content, "most recent member activity results");

###my $ret = $tb->isOregonArticle("Pioneer Courthouse Square");
#my $ret = $tb->evalUserContribs('PeteForsyth');
#print "dumped ret: ", Dumper($ret), "\n";

exit;

sub parseParticipants {
  my ($mw, $tb, $data) = @_;

  my $content;
  $content .= qq(==Users marked as active==
{|class="wikitable sortable"
! User
! Last Oregon edit (days)
! Last Oregon edit time
! Oregon edits
! Last Wiki edit (days)
! Last Wiki edit time
! % of edits in Oregon
);
  $content .= checkParticipantList($tb, keys %{$data->{active}});
  $content .= "|-\n|}\n";

  $content .= qq(==Users marked as inactive==
{|class="wikitable sortable"
! User
! Last Oregon edit (days)
! Last Oregon edit time
! Oregon edits
! Last Wiki edit (days)
! Last Wiki edit time
! % of edits in Oregon
);
  $content .= checkParticipantList($tb, keys %{$data->{inactive}});
  $content .= "|-\n|}\n";

  return $content;
}

sub checkParticipantList {
  my $tb = shift; # rest of @_ is the list of users
  return undef unless scalar @_;

#print Dumper(\@_);
  my $ret = '';
  foreach my $user (sort @_) {
    # good way to test a single user
    #next unless (lc $user eq 'esprqii');

    #my $ucf = ucfirst lc $user;
    my $ucf = $user;
    my $uc = $tb->evalUserContribs($ucf);
    #print Dumper($uc); exit;

    my $lastOregon = daysDelta($uc->{ORmax});
    my $lastOregonPretty = scalar gmtime($uc->{ORmax});
    my $editsOregon = $uc->{ORedit};
    my $percentOregon = '-';
    if ($uc->{ORedit} && $uc->{edit}) {
      $percentOregon = sprintf('%.1f%%', ($uc->{ORedit} / $uc->{edit}) * 100);
    }
#print "pct: $percentOregon\n"; exit;
    my $lastAny = daysDelta($uc->{max});
    my $lastAnyPretty = scalar gmtime($uc->{max});
    $ret .= qq(|-
| [[Special:Contributions/$user|$user]]
| $lastOregon
| $lastOregonPretty
| $editsOregon
| $lastAny
| $lastAnyPretty
| $percentOregon
);
  }

  return $ret;
}

sub daysDelta {
  my $offset = daysFromSeconds((NOW - $_[0]) + EPOCH_OFFSET);
  if ($offset < 0) {
    print STDERR "Uh oh, negative offset ($offset). Edit time: $_[0] (", scalar gmtime($_[0]), ") .. NOW time: ", NOW, "(", scalar gmtime(NOW), ")\n";
  }

  return $offset;
}

sub daysFromSeconds {
  return sprintf('%.1f', $_[0]/(3600*24));
}

sub getParticipants {
  my ($mw) = @_;

  my $ret = {};
  my $type = 'active';

  my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Participants' } );
  my $content = $page->{'*'};
#print "content: $content\n";
  foreach my $line (split(/[\r\n]/, $content)) {
#print "line: $line\n";
    if ($line =~ /^\s*\*.*?\[\[user:(.+?)(\|.*)?\]\]/i) {
      my $user = $1;
      $ret->{$type}{$user}++;
    }
    # couldn't get the user name that way? Try again with user talk: link.
    elsif ($line =~ /^\s*\*.*?\[\[(user talk|special:contributions\/):(.+?)(\|.*)?\]\]/i) {
      my $user = $2;
      print "user found by talk/contribs, $user with line: $line\n";
      $ret->{$type}{$user}++;
    }

    if ($line =~ /===.*inactive.*===/i) { $type = "inactive"; }
  }

  return $ret;
}
