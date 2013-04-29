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


# run through the process, but don't acutally output to Wikipedia.
my $NOPOST = 0; 

# Output to the debug location, not the ACTUAL location. Might also cause
# messages to STDOUT/STDERR.
my $DEBUG = 0;

# Log lines
my $LOG = '';

my $STARTTIME = time();
my $USERFILE = '/home/tedt/.wiki-userinfo';


GetOptions ("nopost"    => \$NOPOST,
            "userfile=s"=> \$USERFILE,
            "debug"     => \$DEBUG);


my $tb = TedderBot->new( userfile => $USERFILE, debug => 0 );
my $mw = $tb->getMWAPI();

unless($tb->okayToRun()) {
  die "we are not approved to run. outta here.";
}

# get some page contents
#my $page = $mw->get_page( { title => 'Wikipedia:WikiProject Oregon/Admin' } );

my $backlist = $mw->list ( { action => 'query',
  list => 'backlinks',
  bltitle => 'Template:WikiProject Oregon',
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


  # Skip the Wikipedia: projects that link to here. We only want the ones
  # that are in the category, not all the {{tlx|WPOR}} type links.
  #
  # Skip templates too.
  if ($namespace == 4 || $namespace == 5 || $namespace == 10 || $namespace == 11) {
    #print "backlinks: $title .. namespace: $namespace\n";
    next;
  }
  push @{$namespacelist{$namespace}}, $title;
}

#print Dumper($backlist);

my $catlist = $mw->list ( { action => 'query',
  list => 'categorymembers',
  cmtitle => 'Category:WikiProject Oregon pages',
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

#sleep 30;
#sleep 30;
outputAdmin($tb, $mw, \%namespacelist);
outputAdmin2($tb, $mw, \%namespacelist);
#sleep 30;
my $runtime = time() - $STARTTIME;
appendLog("finished, ready to upload log. Runtime in seconds: $runtime");
uploadLog($tb);

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
  my $wikiContent = qq({{Wikipedia:WikiProject Oregon/Nav}}
This list was constructed from articles tagged with {{tl|WikiProject Oregon}} (or any other article in [[:category:WikiProject Oregon pages]]) as of $time_subst. This list makes possible [http://en.wikipedia.org/w/index.php?title=Special:Recentchangeslinked&target=Wikipedia:WikiProject_Oregon/Admin Recent WP:ORE article changes].

There are $count entries, all articles.

<small>''See also: [[Wikipedia:WikiProject Oregon/Admin2]] for non-article entries''</small>

);

  # content
  foreach my $title (sort keys %alist) {
#print "title: $title .. ", $alist{$title}, "\n"; exit;
    $wikiContent .= '* [[' . $title . "]]\n";
  }

  # footer
  $wikiContent .= "\n\n[[Category:WikiProject Oregon]]\n";

  #print "page: $wikiContent\n";
  unless ($NOPOST) {
    my $location = 'User:TedderBot/AOP/admin';
    unless ($DEBUG) {
      $location = 'Wikipedia:WikiProject Oregon/Admin';
    }
    my $ret = $tb->replacePage($location, $wikiContent, "update page with $count articles (bot edit)");
    my $status = 'succeeded';
    unless ($ret) { $status = 'FAILED'; }
    appendLog("Updated [[$location]] with $count articles, $status.");
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
    #print "* [[$title]]\n";
    $title =~ s#^:##;
    $u{$title}++;
  }

  foreach my $title (@{$ns->{5}}) {
    #print "* [[$title]]\n";
    $title =~ s#^(Project|Wikipedia) talk#$1#;
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

  my $temp = outputCategory('template', makeTemplateList($nsl));
  $mainContent .= join('', @$temp);

  my $proj = outputCategory('project', makeProjectList($nsl));
  $mainContent .= join('', @$proj);

  my $time_subst = WIKI_TIME;
  my %count = (
    file     => scalar @$file,
    category => scalar @$cat,
    portal   => scalar @$port,
    template => scalar @$temp,
    project  => scalar @$proj,
    total    => scalar @$file + scalar @$cat + scalar @$port + scalar @$temp + scalar @$proj,
  );

  my $wikiContent = qq({{Wikipedia:WikiProject Oregon/Nav}}
This table was constructed from categories, images, portal, project, and templates tagged with {{tl|WikiProject Oregon}} (or any other article in [[:category:WikiProject Oregon pages]]) as of $time_subst. This list makes possible [http://en.wikipedia.org/w/index.php?title=Special:Recentchangeslinked&target=Wikipedia:WikiProject_Oregon/Admin2 Recent WP:ORE non-article changes].

There are $count{file} media files (previously called images), $count{category} categories, $count{portal} portal pages, $count{template} templates, and $count{project} project pages totaling $count{total} pages.

<small>''See also: [[Wikipedia:WikiProject Oregon/Admin]] for article entries''</small>

{| class="sortable"
! Page !! Classification
) . $mainContent . qq(|}

[[Category:WikiProject Oregon]]
);

  #print "about to post admin2\n";
  unless ($NOPOST) {
    my $location = 'User:TedderBot/AOP/admin2';
    unless ($DEBUG) {
      $location = 'Wikipedia:WikiProject Oregon/Admin2';
    }
    #print "at RP, loc: $location\n";
    my $ret = $tb->replacePage($location, $wikiContent, "update page with $count{total} total listings (bot edit)");
    my $status = 'succeeded';
    unless ($ret) { $status = 'FAILED'; }
    #print "RP done, loc: $location\n";
    appendLog("Updated [[$location]] with the following: $count{file} images,$count{category} categories, $count{portal} portals, $count{template} templates, $count{project} project pages (total: $count{total} pages), $status.");
  }

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

# Add to the log cache so we can output it at the end.
sub appendLog {
  $LOG .= join('', ':', @_, "\n");
}

# Dump the log onto Wikipedia, clear the global.
sub uploadLog {
  my ($tb) = @_;

  my $location = 'User:TedderBot/AOP/log';
  unless ($NOPOST) {
    my $output = "* " . WIKI_LOGTIME . "\n" . $LOG . "\n\n";
    $tb->appendPage($location, $output, WIKI_LOGTIME, "update AOP log");
    $LOG = '';
  }
}
