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
use lib '/home/tedt/git/wikibacon/';
use TedderBot;

print STDERR "hello world!\n";

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 1 );
my $mw = $tb->getMWAPI();

# get some page contents
#my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );
print STDERR "time to make request.\n";
my $backlist = $mw->list ( { action => 'query',
  list => 'backlinks',
  bltitle => 'Template:WikiProject Oregon',
  #bltitle => 'Felicia Day',
  #blnamespace => '0|1', # 1 is talk, which is where the template is. We'll
  #                      # just use s/Talk:// to get the title.
  bllimit => '500',
  blredirect => '500',
  #ucprop => 'ids|title|timestamp',
  #ucdir => 'newer',  },
  { max => 200, }
  # not using a hook, we want the raw list
  #hook => \&print_articles
} ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

my $count = 0;
foreach my $entry (@$backlist) {
  next unless ($entry->{ns} == 1);
  ++$count;
  next if ($entry->{title} =~ /^Talk:/);
  print STDERR Dumper($entry); exit;
}

print STDERR "pagecount: $count\n";

#print Dumper($backlist);
my $wikiContent = '';

my $catlist = $mw->list ( { action => 'query',
  list => 'categorymembers',
  cmtitle => 'Category:WikiProject Oregon pages',
  #bltitle => 'Felicia Day',
  #blnamespace => '0|1', # 1 is talk, which is where the template is. We'll
  #                      # just use s/Talk:// to get the title.
  cmlimit => '500',
  #ucprop => 'ids|title|timestamp',
  #ucdir => 'newer',  },
  { max => 200, }
  # not using a hook, we want the raw list
  #hook => \&print_articles
} ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

$count = 0;
binmode STDOUT, ":utf8";
foreach my $entry (@$catlist) {
  next unless ($entry->{ns} == 1);
  ++$count;

  my $title = $entry->{title};
  if (! $title =~ /^Talk:/) {
    print STDERR "not talk: $title\n";
    next;
  }

  $title =~ s#^Talk:\s*##;
  $wikiContent .= '* [[' . decode_utf8($title) . "]]\n";
  ###print Dumper($entry); exit;
}

$tb->replacePage('User:TedderBot/AOP/admin', $wikiContent, 'update /admin page with all listings (bot edit)');

print STDERR "pagecount: $count\n";
