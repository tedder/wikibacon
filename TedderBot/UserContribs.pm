package TedderBot::UserContribs;

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
use Data::Dumper; # TODO: probably temporary for debugging/implementation
use Time::ParseDate;
use MediaWiki::API;
use Storable;
use TedderBot;

# Inherit from TedderBot
our @ISA = 'TedderBot';


# Get a user's contribs via the API. Many hardcoded bits in here will
# probably be parameters later, but it serves our needs.
sub getContribs {
  my ($self, %opt) = @_;

  return { error => 'no user given' } unless $opt{user};

  ## see if we have a local cache of the user's data.
  my $lcuser = lc $opt{user};
  $lcuser =~ s/\s/_/g;
  # filename will be blank unless we pass a taint check.
  my $filename;

  # basic taint check
  $self->_debug("lcuser: $lcuser\n");
  if ($lcuser =~ /^([a-z0-9\s_\.]+)$/) {
    $filename = '/tmp/tedderbot-usercontribs-' . $lcuser;
  }
  else {
    $self->_debug("user taint check failed: $lcuser\n");
  }

  # Do we have a filename? Does Storable return something? Great!
  # That saves us some calls.
  if ($filename && -e $filename) {
    my $contribs = Storable::retrieve($filename);
    if ($contribs) { return $contribs; }
  }

  my $mw = $self->getMWAPI();

  # future: check uclimit to make sure we haven't gone over the
  #  permissible limit, tune down as necessary.
  my $uclist = $mw->list ( { action => 'query',
                list => 'usercontribs',
                ucuser => $opt{user},
                uclimit =>'500',
                ucprop => 'ids|title|timestamp',
                ucdir => 'newer',  },
              { max => 10000,
                # not using a hook, we want the raw list
                #hook => \&print_articles
              } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};


  $self->_debug("number of contribs found: ", scalar @$uclist, "\n");

  # Do we have a filename for Storable? If so, store out our contribs
  # before returning so we can use it in future calls.
  if ($filename) {
    $self->_debug("attempting to store uclist at $filename\n");
    Storable::store($uclist, $filename);
  }

  return $uclist;
}

# preScoreContribs:
#
# Set up our contribution lists to be ready for scoring. This means we'll
# find the intersection of the two lists, and also collect the timestamps
# for each editor.
#
sub preScoreContribs {
  my ($self, $list1, $list2) = @_;

  my $intersection = {};
  # populate the intersection with both user lists.
  $self->_populateIntersection($intersection, $list1, 1);
  $self->_debug("intersection size after first list: ", scalar keys %$intersection, "\n");

  $self->_populateIntersection($intersection, $list2, 2);
  $self->_debug("intersection size after both lists: ", scalar keys %$intersection, "\n");

  # loop through the intersection. Remove entries that haven't
  # been edited by both users.
  # If this is too slow, it might be faster to create a new list.
  while (my ($name, $r) = each %$intersection) {
    # Both hashes should exist to prove both users have edited the same article.
    unless (exists $r->{user1_timestamps} &&
            exists $r->{user2_timestamps}) {
      delete $intersection->{$name};
    }
  }
  $self->_debug("intersection size after deletion: ", scalar keys %$intersection, "\n");

  #my %intersection;
  # loop through list2, make a second hash with articles in list1 hash
  #foreach my $article (@$list2) {
    #my $articleName = $article->{'title'};

    # does this article also appear on list1?
    #if ($list1articles{$articleName}) {
      #$intersection{$articleName} = 1;
    #}
  #}

  #$self->_debug("articles in intersection: ", scalar keys %intersection, "\n");

  return $intersection;
}

# Create a complex hash with all articles from the list, as well as all edit
# times by this user.
#
# Returns intersection, even though it's modifying the ref version.
sub _populateIntersection {
  my ($self, $intersection, $list, $usern) = @_;

  foreach my $article (@$list) {
    my $name = $article->{'title'};
    my $time = $article->{'timestamp'};

    # This $user could probably be optimized away, because it won't change
    # for all of $list1 or all of $list2.
    # 
    # (round 2- not using "user", just calling it "user1" and "user2".
    #my $user = $article->{'user'};

    my $usern_tag = "user" . $usern . "_timestamps";
    # push the timestamps in. This is an easy way to count edits by each user
    push @{$intersection->{$name}{$usern_tag}}, $time;
    # push the edit ref in. This gives us full information.
    push @{$intersection->{$name}{edits}}, $article;
    $usern_tag = "user" . $usern . "_edits";
    push @{$intersection->{$name}{$usern_tag}}, $article;
  }

  return $intersection;
}

# scoreContribs: given an intersection list, sort through them to assign
# a "Bacon score".
sub scoreContribs {
  my ($self, $intersection) = @_;

  #print Dumper($int); exit;
  # loop through each article, send them to our score drivers
  while (my ($article, $ref) = each %$intersection) {
    print "a/r: $article / $ref\n";
    #print Dumper($ref); exit;
    my ($minEditTime, $u1Edit, $u2Edit) = $self->closestEditTime($ref);
    $ref->{minEdit} = {
      'time' => $minEditTime,
      u1 => $u1Edit,
      u2 => $u2Edit };

#print Dumper($ref); exit;
    #$self->firstEdits($ref);
  }

}


# Display the close edits summary. Take the (scored) intersection list
# and display text.
sub showCloseEdits {
  my ($self, $list, $limit) = @_;

  my $count = 0;
  foreach my $article (sort { $list->{$a}{minEdit}{time} <=> $list->{$b}{minEdit}{time} } keys %$list) {
    # Have we shown the maximum number of edits we want to show?
    if (++$count > $limit) { last; }

    print "time: ", $list->{$article}{minEdit}{'time'}, "\n";
    #print Dumper($list->{$article}{minEdit}); exit;

    # pull out vars so they are easier to print.
    my $id1 = $list->{$article}{minEdit}{u1}{revid};
    my $id2 = $list->{$article}{minEdit}{u2}{revid};
    my $time1 = $list->{$article}{minEdit}{u1}{timestamp};
    my $time2 = $list->{$article}{minEdit}{u2}{timestamp};
    my $user1 = $list->{$article}{minEdit}{u1}{user};
    my $user2 = $list->{$article}{minEdit}{u2}{user};
    my $difftime = $list->{$article}{minEdit}{'time'};
    my $article = $list->{$article}{minEdit}{u1}{title};
    print qq(* Article: [[$article]] (time between edits: $difftime seconds)<br />Edit #1 by $user1 ([http://en.wikipedia.org/w/index.php?diff=prev&oldid=$id1 diff]) at $time1<br />Edit #2 by $user2 ([http://en.wikipedia.org/w/index.php?diff=prev&oldid=$id2 diff]) at $time2\n);


  }
}


# closestEditTime: Given an article reference from an intersection list, find
# the minimum time between edits from different users.
sub closestEditTime {
  my ($self, $article) = @_;

  # store our minimum time and revision ID.
  my $minTime;
  my $minU1Edit; # edit hash
  my $minU2Edit; # edit hash

  #print Dumper($article); exit;
  foreach my $edit (@{$article->{user1_edits}}) {
    # convert timestamp to epoch, compare against user2 to find min time.
    my $epoch = parsedate($edit->{timestamp});
    my $min;
    ($min, $minU2Edit) = $self->findClosestEditTime($epoch, $article->{user2_edits});

    # new minimum? Store the minTime and revision
    if ($min < $minTime || ! $minTime) {
      $minTime = $min;
      $minU1Edit = $edit;
    }
  }

  print "mt/mr: $minTime / $minU1Edit / $minU2Edit\n";

  return ($minTime, $minU1Edit, $minU2Edit);
}

# driver to compare a given epoch time against a list of edits.
# Poorly named, it's a driver broken out from closestEditTime()
sub findClosestEditTime {
  my ($self, $timeCompare, $edits)  = @_;

  # set up a minimum. Set it to 'infinity' (the epoch of timeCompare)
  my $min = $timeCompare;
  my $minEdit = {};
  foreach my $edit (@$edits) {
    my $epoch = parsedate($edit->{timestamp});

    # easier to be lazy- compute it once and store it here. Need to use 'abs'
    # to make sure $timeCompare isn't greater than $epoch
    my $delta = abs($epoch - $timeCompare);
    if ($delta < $min) {
      $min = $delta;
      $minEdit = $edit;
    }
  }

  # return the time and the edit hash.
  return ($min, $minEdit);
}

# firstEdits: find the first page that U1 and U2 edited. This is actually
# trickier than it sounds. In reality, it's the first edit by the
# *second user*, not the TODO TODO need to return all, not top 1
#  
#    $self->firstEdits($ref);

1; # Like a good module should.
