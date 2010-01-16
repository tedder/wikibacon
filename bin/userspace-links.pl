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

use constant WIKI_TIME => '{{subst:CURRENTTIME}} {{subst:CURRENTDAYNAME}} {{subst:CURRENTMONTHNAME}} {{subst:CURRENTDAY}}, {{subst:CURRENTYEAR}}';
use constant WIKI_LOGTIME => '{{subst:CURRENTYEAR}}-{{subst:CURRENTMONTH}}-{{subst:CURRENTDAY2}} {{subst:CURRENTTIME}}';

binmode STDOUT, ":utf8";

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
#my $page = $mw->get_page( { title => 'Wikipedia:Database reports/Articles containing links to the user space' } );


my $articles = userspace_links($mw, 'Wikipedia:Database reports/Articles       containing links to the user space');
my $text = "Last run at " . WIKI_TIME . qq(, based on [[Wikipedia:Database_reports/Articles_containing_links_to_the_user_space]].\n{| class="wikitable sortable plainlinks" style="width:100%; margin:auto;"
|- style="white-space:nowrap;"
! Article
! First match
);

foreach my $a (@$articles) {
  $text .= check_article($mw, $a);
}

my $runtime = time() - $STARTTIME;
$text .= qq(|-
|}


Runtime: $runtime seconds

);


$tb->replacePage('User:TedderBot/Database reports/Articles containing links to the user space version 2', $text, "updated page. ($runtime seconds)");

exit;

sub check_article {
  my ($mw, $title) = @_;

  my $page = $mw->get_page( { title => $title } );

  # skip empty pages.
  my $content = $page->{'*'};
  return undef unless $content;
print "checking: $title\n";
#print "page: ", Dumper($page), "\n"; exit;

  my $out = '';
  if ($content =~ /(.{0,20})\b(user:|user talk:)(.{0,20})/i) {
    $out .= "|-\n | {{plenr|1=$title}}\n | <nowiki>$1$2$3</nowiki>\n";
    print "match: $1$2$3\n";
  }

  return $out;
}

sub userspace_links {
  my ($mw, $title) = @_;

  my $ret = [];
  my $page = $mw->get_page( { title => $title } );
  foreach my $line (split(/[\n\r]/, $page->{'*'})) {
    if ($line =~ /plenr\|1=(.*)?}}/) {
      my $article = $1;
      #print "article: $article\n"; exit;
      push @$ret, $article;
    }
  }

  return $ret;
}

