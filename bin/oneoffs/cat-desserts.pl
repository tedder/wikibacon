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

my %SEEN;
my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 1 );
my $mw = $tb->getMWAPI();

my $count = process_category('Category:Desserts');
print "final count: $count\n";

exit;

sub process_category {
  my ($title) = @_;

  if ($SEEN{$title}++) {
    print "skipping category, we've already seen it: $title\n";
    return;
  }

  my $backlist = $mw->list ( { action => 'query',
    list => 'categorymembers',
    cmtitle => $title,
    cmlimit => 5,
    #ucprop => 'ids|title|timestamp',
    { max => 2, }
    #hook => &process_article
   } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  my $count = 0;
  foreach my $entry (@$backlist) {
    my $namespace = $entry->{ns};
    my $title = $entry->{title};
  
    print "title: $title, namespace: $namespace\n";
    #if ($namespace == 14 && ! $SEEN{$title}++) {
    if ($namespace == 14) {
      $count += process_category($title);
    } elsif ($namespace == 0) {
      ++$count;
      process_article($title);
    } else {
      print " I don't know what I'm supposed to do with this namespace.\n";
    }

  }


  print "count: $count\n";

  return $count;
}

sub process_article {
  my ($title) = @_;

  my $talk_title = 'Talk:' . $title;
  print " tt: $talk_title\n";
}
