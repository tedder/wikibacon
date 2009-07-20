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
use lib '/home/tedt/git/wikibacon/';
use TedderBot::UserContribs;

print "hello world!\n";

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 1 );
my $mw = $tb->getMWAPI();

# get some page contents
my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );

open(OUT, "> /home/tedt/adventist-out.txt") || die "couldn't open outfile: $!";

# print page contents
#print $page->{'*'};
foreach my $line (split(/\n/, $page->{'*'})) {
  if ($line =~ /^\*\[\[(.*)\]\]$/) {
    my $title = $1;
print "$title\n";
    checkArticle($mw, $title);
  } else {
    print "unmatched line: $line\n";
  }
}

exit;

sub checkArticle {
  my ($mw, $title) = @_;

  my $aarticle = isAdventistArticle($title);
  my $tarticle = isAdventistProject('Talk:' . $title);

  if ($aarticle || $tarticle) {
    print "**** matched $title: $aarticle / $tarticle\n";
    print OUT '* [[' . $title . ']]';
    if (! $aarticle) {
      print OUT " (not mentioned in article) ";
    }
    if (! $tarticle) {
      print OUT " (not in Adventist project on talk page) ";
    }
    print OUT "\n";
  }


}

sub isAdventistArticle {
  my ($title) = @_;

  my $page = $mw->get_page( { title => $title } );

  if ($page->{'*'} =~ /adventist/i) { return 1; }

  return undef;
}

sub isAdventistProject {
  my ($title) = @_;

  my $page = $mw->get_page( { title => $title } );

  if ($page->{'*'} =~ /{{(WP|WikiProject)\s*Adventist/i) { return 1; }

  return undef;
}
