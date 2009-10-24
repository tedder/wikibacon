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

use constant WIKI_TIME => '{{CURRENTTIME}} {{CURRENTDAYNAME}} {{CURRENTMONTHNAME}} {{CURRENTDAY}}, {{CURRENTYEAR}}';

my $NOPOST = 1;

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
my %namespacelist;
foreach my $entry (@$backlist) {
  my $namespace = $entry->{ns};
  my $title = $entry->{title};
  my $dtitle = decode_utf8($title);
  push @{$namespacelist{$namespace}}, $title;
}

#print Dumper($backlist);

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

#binmode STDOUT, ":utf8";
my %articles;
foreach my $entry (@$catlist) {
  my $namespace = $entry->{ns};
  my $title = $entry->{title};
  my $dtitle = decode_utf8($title);
  push @{$namespacelist{$namespace}}, $title;
}

outputAdmin($tb, $mw, \%namespacelist);
outputAdmin2($tb, $mw, \%namespacelist);

exit;

# outputs the 'article' and 'talk' namespaces only, but must remove "Talk:"
# from the talk page titles.
sub outputAdmin {

  my %alist;
  while (my $title = shift @{$namespacelist{0}}) {
    if (exists $alist{$title}) {
      #print STDERR "Duplicated /admin page: $title\n";
    } else {
      ++$alist{$title};
    }
  }

  while (my $title = shift @{$namespacelist{1}}) {
    $title =~ s/^Talk:(.*)/$1/;
    if (exists $alist{$title}) {
      #print STDERR "Duplicated /admin page: $title\n";
    } else {
      ++$alist{$title};
    }
  }

  my $count = scalar keys(%alist);

  # hack for the lazy- so we don't have to concatenate the constant.
  my $time_subst = WIKI_TIME;

  # create our header
  my $wikiContent = qq({{WP:WPOR-Nav}}
This list was constructed from articles tagged with {{tl|WikiProject Oregon}} (or any other article in [[:category:WikiProject Oregon articles]]) as of $time_subst. This list makes possible [http://en.wikipedia.org/w/index.php?title=Special:Recentchangeslinked&target=Wikipedia:WikiProject_Oregon/Admin Recent WP:ORE article changes].

There are $count entries, all articles.

<small>''See also: [[Wikipedia:WikiProject Oregon/Admin2]] for non-article entries''</small>

);

  # content
  foreach my $title (sort keys %alist) {
    $wikiContent .= '[[' . $alist{$title} . "]]\n";
  }

  # footer
  $wikiContent .= "\n\n[[Category:WikiProject Oregon]]\n";

  #print "page: $wikiContent\n";
  unless ($NOPOST) {
    $tb->replacePage('User:TedderBot/AOP/admin', $wikiContent, 'update /admin page with all listings (bot edit)');
  }

}

sub makeCategoryList {
  my ($ns) = @_;

  my %u;
  foreach my $title (@{$ns->{14}}) {
    $title = ':' . $title;
    $u{$title}++;
  }

  foreach my $title (@{$ns->{15}}) {
    $title =~ s#^(Category) talk#$1#;
    $title = ':' . $title;
    $u{$title}++;
  }

  my @final = keys %u;

  return \@final;
}

sub makeFileList {
  my ($ns) = @_;

  my %u;
  foreach my $title (@{$ns->{6}}) {
    $title = ':' . $title;
    $u{$title}++;
  }

  foreach my $title (@{$ns->{7}}) {
    $title =~ s#^(File) talk#$1#;
    $title = ':' . $title;
    $u{$title}++;
  }

  my @final = keys %u;

  return \@final;
}

sub makePortalList {
  my ($ns) = @_;

  my %u;
  foreach my $title (@{$ns->{100}}) {
    $u{$title}++;
  }

  foreach my $title (@{$ns->{101}}) {
    $title =~ s#^(Portal) talk#$1#;
    $u{$title}++;
  }

  my @final = keys %u;

  return \@final;
}

sub makeTemplateList {
  my ($ns) = @_;

  my %u;
  foreach my $title (@{$ns->{10}}) {
    $u{$title}++;
  }

  foreach my $title (@{$ns->{11}}) {
    $title =~ s#^(Template) talk#$1#;
    $u{$title}++;
  }

  my @final = keys %u;

  return \@final;
}

sub makeProjectList {
  my ($ns) = @_;

  my %u;
  foreach my $title (@{$ns->{4}}) {
    $title =~ s#^:##;
    $u{$title}++;
  }

  foreach my $title (@{$ns->{5}}) {
    $title =~ s#^(Project|Wikipedia) talk##;
    $title =~ s#^:##;
    $u{$title}++;
  }

  my @final = keys %u;

  return \@final;
}

# outputs the remaining namespaces.
sub outputAdmin2 {
  my ($tb, $mw, $nsl) = @_;


  # It's pretty much easier to unroll this loop than it is to build a
  # dispatch table in perl. So we'll make these six calls by hand and
  # duplicate the makeNList functions; at least it allows us to create
  # custom regexes and filters.

  my $catlist = makeCategoryList($nsl);
  my $cat = outputCategory('category', $catlist);
  my $mainContent = join('', @$cat);

  #my $filelist = makeFileList($nsl);
  my $file = outputCategory('file', makeFileList($nsl));
  $mainContent .= join('', @$file);

  my $port = outputCategory('portal', makePortalList($nsl));
  $mainContent .= join('', @$port);

  my $temp = outputCategory('template', makePortalList($nsl));
  $mainContent .= join('', @$temp);

  my $proj = outputCategory('project', makeProjectList($nsl));
  $mainContent .= join('', @$proj);

  my $time_subst = WIKI_TIME;
  my $wikiContent = qq({{WP:WPOR-Nav}}
This table was constructed from categories, images, portal, project, and templates tagged with {{tl|WikiProject Oregon}} (or any other article in [[:category:WikiProject Oregon articles]]) as of $time_subst. This list makes possible [http://en.wikipedia.org/w/index.php?title=Special:Recentchangeslinked&target=Wikipedia:WikiProject_Oregon/Admin2 Recent WP:ORE non-article changes].

There are TODO images (now called "file"), TODO categories, TODO portal pages, TODO templates, and TODO project pages totaling TODO pages.

<small>''See also: [[Wikipedia:WikiProject Oregon/Admin]] for article entries''</small>

{| class="sortable"
! Page !! Classification
) . $mainContent . qq(|}

[[Category:WikiProject Oregon]]
);
  $tb->replacePage('User:TedderBot/AOP/admin2', $wikiContent, 'update /admin2 page with all listings (bot edit)');
}

sub outputCategory {
  my ($label, $list) = @_;
  my @ret;

  #unless (ref $lista eq 'ARRAY') {
  #  print "Inner array isn't present for $label.\n";
  #  return \@ret;
  #}

  #my $list = \@$lista;

  unless (ref $list eq 'ARRAY') {
    print "Hmm. No results for $label in outputCategory.\n";
    return \@ret;
  }

  foreach my $title (sort @$list) {
    push @ret, '|-' . "\n" . '|[[' . $title . ']]||' . $label . "\n";
  }

  return \@ret;
}
