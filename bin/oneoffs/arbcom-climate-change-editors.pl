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

use Time::ParseDate;
use Data::Dumper;
use Encode;
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

my $TOTAL = 0;
my %ATOTAL;
my @pages = ('Climatic Research Unit e-mail hacking incident', 'Intergovernmental Panel on Climate Change', 'Global cooling', 'Global warming', 'Scientific opinion on climate change');
my $editors = {};
#my $start = scalar gmtime parsedate('-90 days');
my $start = '2009-10-01T00:00:00Z';
print "start: $start\n";

foreach my $page (@pages) {
  getEditors($mw, $page, $start, $editors);
  getEditors($mw, 'Talk:' . $page, $start, $editors);
}
#print Dumper($editors);

#print "talk edits over 30\n";
#showUsers($editors, 'talk', 30);
print "article edits over 30\n";
showUsers($editors, 'article', 30);
#print "total edits ($TOTAL) over 30\n";
#showUsers($editors, 'all', 30);
print Dumper(\%ATOTAL);

exit;

sub showUsers {
  my ($data, $type, $limit) = @_;

  my $count = 0;
  my %toprint;
  foreach my $user (keys %$data) {
    my $edits = $data->{$user}{$type};
    if ( $edits >= $limit) {
      $toprint{$user} = $edits;
      #print "$edits,$user\n";
      ++$count;
    }
  }

  foreach my $u (reverse sort { $toprint{$a} <=> $toprint{$b} } keys %toprint) {
    print "* {{userlinks|$u}} ($toprint{$u} article edits, $$data{$u}{talk} talk edits)\n";
  }

  print "\n$count editors listed.\n\n\n";
}

sub getEditors {
  my ($mw, $title, $date, $data, $con) = @_;

print "page: $title\n";
  my $pstart = parsedate("2009-10-01 00:00:00 UTC");

  my %opt = (
    action => 'query',
    prop   => 'revisions',
    titles => $title,
    rvlimit => 500,
    rvstart => $date,
    rvdir   => 'newer',
    rvprop => 'user|timestamp'
  );
  if ($con) { delete $opt{rvstart}; $opt{rvstartid} = $con; }
#print Dumper(\%opt);
  my $ret = $mw->api( \%opt );
#print Dumper($ret); exit;

  my $count = 0;
  foreach my $page (keys %{$ret->{query}{pages}}) {
#print "page: $page\n";
    foreach my $rev (@{$ret->{query}{pages}{$page}{revisions}}) {
      my $user = $rev->{user};
      my $time = $rev->{timestamp};

#print " time: $time\n";
      my $utime = parsedate($time);
      next if ($utime < $pstart);

#print "user: $user at $time/$utime\n";
      my $type = 'article';
      if ($title =~ /Talk:/i) { $type = 'talk'; }
      $data->{$user}{all}++;
      $data->{$user}{$type}++;
      $TOTAL++;
      $ATOTAL{$title}++;
      ++$count;
    }
  }


  return undef unless $count;

  my $continue = $ret->{'query-continue'}{revisions}{rvstartid};
print "continue: $continue\n";
  if ($continue) {
    getEditors($mw, $title, $date, $data, $continue);

  }
}

