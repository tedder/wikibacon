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

my $nopost = 1;

my $tb = TedderBot->new( userfile => '/home/tedt/.wiki-userinfo', debug => 0 );
my $mw = $tb->getMWAPI();

# get some page contents
#my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );

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

  print STDERR "non-Talk entry:\n" . Dumper($entry);
  exit;
}


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
my %articles;
foreach my $entry (@$catlist) {
  next unless ($entry->{ns} == 1);

  my $title = $entry->{title};
  if (! $title =~ /^Talk:/) {
    print STDERR "not talk: $title\n";
    next;
  }

  $title =~ s#^Talk:\s*##;
  my $dtitle = decode_utf8($title);
  #my $dtitle = $title;
  my $str = '* [[' . $title . "]]\n";
  if (exists $articles{$title}) {
    print STDERR "Duplicated article: $title\n";
  }
  $articles{$title} = $str;

  ++$count;
  ###print Dumper($entry); exit;
}

# seperate, so we can avoid escaping issues.
my $time_subst = '{{CURRENTTIME}} {{CURRENTDAYNAME}} {{CURRENTMONTHNAME}} {{CURRENTDAY}}, {{CURRENTYEAR}}';

# header
$wikiContent = qq({{WP:WPOR-Nav}}
This list was constructed from articles tagged with {{tl|WikiProject Oregon}} (or any other article in [[:category:WikiProject Oregon articles]]) as of $time_subst. This list makes possible [http://en.wikipedia.org/w/index.php?title=Special:Recentchangeslinked&target=Wikipedia:WikiProject_Oregon/Admin Recent WP:ORE article changes].

There are $count entries, all articles.

<small>''See also: [[Wikipedia:WikiProject Oregon/Admin2]] for non-article entries''</small>

);

# content
foreach my $key (sort keys %articles) {
  $wikiContent .= $articles{$key};
}
#$wikiContent .= join sort keys %articles;

# footer
$wikiContent .= "\n\n[[Category:WikiProject Oregon]]\n";

#print "page: $wikiContent\n";
unless ($nopost) {
  $tb->replacePage('User:TedderBot/AOP/admin', $wikiContent, 'update /admin page with all listings (bot edit)');
}

