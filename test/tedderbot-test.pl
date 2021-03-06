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
use Getopt::Long;
use lib '/home/tedt/git/wikibacon/';
use TedderBot::UserContribs;

# commandline options with defaults.
my $user1;
my $user2;
my $userfile = '/home/tedt/.wiki-userinfo';
my $debug = 0;
my $test = 0;
my $help = 0;

GetOptions ("user1=s"    => \$user1,
            "user2=s"    => \$user2,
            "userfile=s" => \$userfile,
            "debug"      => \$debug,
            "test"       => \$test,
            "help"       => \$help);

if ($help) {
  showUsage();
  exit;
}

unless (-e $userfile) {
  print "Userfile is required for login info.\n";
  showUsage();
  exit;
}

unless ($user1 && $user2) {
  print "must specify both user1 and user2.\n";
  showUsage();
  exit;
}

my $tb = TedderBot::UserContribs->new( userfile => $userfile, debug => $debug );

my $contrib1 = $tb->getContribs( user => $user1 );
my $contrib2 = $tb->getContribs( user => $user2 );
$tb->preScoreContribs($contrib1, $contrib2);
#print join(", ", keys %$int), "\n";
$tb->scoreContribs();

my $newText = "";
#my $newText = "\n\n==Wikibacon: " . join(', ', sort($user1, $user2)) . "==\n";
#my $summary = 'Wikibacon results between ' . join(', ', sort($user1, $user2));
my $summary = "Wikibacon: " . join(', ', sort($user1, $user2));

my $numArticles = $tb->getUniqueArticles();
$newText .= qq(\n$numArticles unique articles have been edited by both [[User:$user1|$user1]] and [[User:$user2|$user2]]\n);

# don't bother showing results if they haven't edited articles together.
if ($numArticles) {
  $newText .= qq(\n===Close edits===\nAmong [http://toolserver.org/~mzmcbride/cgi-bin/wikistalk.py?namespace=0&user1=$user1&user2=$user2&user3=&user4=&user5=&user6=&user7=&user8=&user9=&user10= pages that both users have edited], this list shows the pages where their edits were closest in time. This usually reveals periods of [[Wikipedia:Consensus|close collaboration]] or [[Wikipedia:Edit war|edit wars]] between two editors.\n);
  $newText .= $tb->showCloseEdits(5);

  $newText .= qq(\n===First edits===\nAmong pages that both users have edited, this list shows where both made edits the earliest, without regard to how soon one edit was after the other. This may be useful in determining when the two editors first "met" one another.\n);
  $newText .= $tb->showFirstEdits(5);

  $newText .= qq(\n====Article namespace====\nFirst edits in the article [[WP:NS|namespace]] only.\n);
  $newText .= $tb->showFirstEdits(5, 0);

  $newText .= qq(\n====Article Talk namespace====\nFirst edits in the article talk [[WP:NS|namespace]] only.\n);
  $newText .= $tb->showFirstEdits(5, 1);
}

# Sign the post.
$newText .= "~~~~\n\n";

if ($test) {
  print "output:\n$newText\n";
} else {
  $tb->appendPage('User:TedderBot/Bacon Results', $newText, $summary);
}

exit;

sub showUsage {
  # TODO
  print qq(PLACEHOLDER TODO TODO\n);
}
