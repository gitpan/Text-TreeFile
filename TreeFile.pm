#                             file:  Text/TreeFile.pm
#
#   Copyright (c) 2000 John Kirk. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#   The latest version of this module should always be available
# at any CPAN (http://www.cpan.org) mirror, or from the author:
#              http://perl.dystanhays.com/jnk

package Text::TreeFile;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);

require Exporter;
require AutoLoader;

$VERSION=0.38;
@ISA=qw(Exporter AutoLoader);
@EXPORT_OK=qw(showlines showglobals);

require 5.002;
use FileHandle;    # nice to easily have filehandles as plain variables

my %proto=( 'endq'=>undef,'top'=>undef,'idir'=>undef,'iname'=>undef,
            'nest'=>undef,'level'=>undef,'line'=>undef,'lev'=>undef, );

sub _loadtree;
sub _readspec;
sub showlines;
sub showglobals;

sub new { my ($that,$iname,$endq)=@_;
  my $class=ref($that)||$that;
  my $me={_prop=>\%proto,%proto,};
  bless $me,$class;
  if(defined $endq) { $$me{endq}=$endq; }
  if(defined $iname) { $$me{iname}=$iname;
    $iname=~/^(.*\/)([^\/]*)$/;
    $$me{idir}=(defined $1 and $1 ne '')?$1:'';
    $$me{top}=_loadtree $me or return undef;
  }
  return $me;
}

sub _loadtree { my $me=shift;
  my ($spec,$cnt);
  if(!defined $$me{nest}) {
    $$me{nest}=0;
    $$me{lev}=[{'cum'=>0,'lev'=>0,'ifn'=>undef,'ifh'=>undef,'ifl'=>undef,}];
    if(defined $$me{endq}) {
      $spec=[];
      $cnt=0;
    }
  }
  my $lp=$$me{lev}[$$me{nest}];
  if((!defined $$lp{ifh})&&($$me{nest}==0)) {
    if(defined $$me{iname}) {
      $$lp{ifn}=$$me{iname};
    } else {
      print "loadtree(): wasn't given a filename ($$me{iname})\n";
      return undef;
    }
  }
  if(!defined $$lp{ifn}) {
    print "no input filename\n";
    return undef;
  } elsif(!defined $$lp{ifh}) {
    $$lp{ifh}=new FileHandle "<$$lp{ifn}";
    $$me{line}=undef;
  }
  if(!defined $$lp{ifh}) {
    print "couldn't open ifile: $$lp{ifn}\n";
    return undef;
  }
  if(!defined $$me{line}) {
    ($$me{level},$$me{line})=_readspec $$lp{ifh},$$lp{ifl};
  }
  while(defined $$me{line}) { # loop on top-level specs; test eof from readspec
    if($$me{line}=~/^include\s+(\S+)/) {
      my $iname="$$me{idir}$1";
      my ($cum,$lev)=($$me{lev}[$$me{nest}]{cum},$$me{lev}[$$me{nest}]{lev});
      ++$$me{nest};
      $$me{lev}[$$me{nest}]={
        'cum'=>$cum+$lev,'lev'=>0,'ifn'=>$iname,'ifh'=>undef,'ifl'=>undef,
      };
      if(defined $cnt) { $$spec[$cnt++]=_loadtree($me); }
      else             { $spec         =_loadtree($me); }

      --$$me{nest};
      ($$me{level},$$me{line})=_readspec $$lp{ifh},$$lp{ifl};
    } else {
      my @specs=();
      if(defined $cnt) { $$spec[$cnt++]=[$$me{line},\@specs]; }
      else             { $spec         =[$$me{line},\@specs]; }
      ($$me{level},$$me{line})=_readspec $$lp{ifh},$$lp{ifl};
      my $sublevel=(++$$lp{lev});
      while((defined $$me{level}) && ($$me{level}==$sublevel)) {
        push @specs,_loadtree($me);
      }
      --$$lp{lev};
    }
    last if(!defined $cnt);
  }
  return $spec;
}

sub _readspec { my $ifh=shift;
  if(!defined $_[0]) {
    while(<$ifh>) {
      next if(/^[#;\/]/ or /^\s*\.\.\./ or /^\s*$/);
      last;
    }
    if(eof($ifh)) {
      $_[0]='';
      return (0,undef);
    }
    chop;
    $_[0]=$_;
  }
  if(!defined $_[0]) {
    return (undef,undef);
  }
  if($_[0] eq '') {
    return (0,undef);
  }
  my ($indent,$line,$str);
  ($indent,$line)=$_[0]=~/^([ ]*)(.*)$/;
  my $level=length($indent)/2;
  die "indent. not a mult. of two spaces\n" if($level*2!=length($indent));
  while(<$ifh>) {
    next if(/^[#;]/ or /^\s*\.\.\.\s*$/ or /^\s*$/);
    chop;
    ($indent,$str)=/^(\s*)\.\.\.(.*)$/;
    if(defined $str) {
      $str=~s/^\s+/\ /;
      $line.=$str;
      next;
    }
    $_[0]=$_;
    last;
  }
  if(eof($ifh)) {
    $_[0]='' if(!defined $_);
  }
  return ($level,$line);
}

1;

__END__

=head1 NAME

Text::TreeFile - Reads a tree of text strings into a data structure

=head1 SYNOPSIS

  use Text::TreeFile;

  # need to set $filename, e.g.:  my $filename='treetest.tre';

  my $treeref=Text::TreeFile->new($filename);
  # or: my $treeref=Text::TreeFile->new($filename,'mult');

  die "TreeFile constructor returned undef\n" if not defined $treeref;

  my $topref=$treeref->{top}; # scalar or array for top-level tree(s)
  showlines($topref,0);            # see EXAMPLE, below

=head1 REQUIRES

  TreeFile uses modules:  FileHandle, Exporter and Autoloader.

=head1 DESCRIPTION

  TreeFile.pm supports a simple ASCII text file format for
representing tree structures.  It loads the contents of such
a file into a tree (or array of trees) of two-element array
nodes, where the first element of each node is a text string
and the second is an array of child nodes.  It supports
comments, continuation lines and include files, and uses a
strict (two-space-per-level) indentation scheme in the file
to indicate hierarchical nesting.

-head1 OPTIONS

  TreeFile implements a two-choice option between:

    (1) A single top-level tree per file (leaving the tail end
          of each file available for supplementary data which
          TreeFile.pm does not, itself, support), in which case
          it makes reference for the top-level tree, or

    (2) Multiple top-level trees per file (or, put another way,
          the top-level of the tree represented by a file is
          implicit -- having no explicit text string in the file
          -- or is associated with only the filename as its
          content), in which case it makes an array of references
          to the top-level trees.

=head1 EXAMPLE

  use Text::TreeFile;

  sub showlines;

  # set $filename string and $wantmult boolean
  # my $filename='treetest.tre';
  # my $wantmult=1;   # or:  =0;  # or: omit from new() constructor;

  my $treeref;
  $treeref=Text::TreeFile->new($filename) if not $wantmult;
  $treeref=Text::TreeFile->new($filename,'mult') if $wantmult;
  die "TreeFile constructor returned undef\n" if not defined $treeref;

  my $topref=$treeref->{top}; # scalar or array for top-level tree(s)
  showlines($topref,0);

  sub showlines { my ($spec,$level)=@_;
    if(ref($$spec[0]) eq 'ARRAY') {  # want-mult case
      for my $item (@$spec) {
        print('  'x$level);print("$$item[0]\n");
        for(@{$$item[1]}) { showlines $_,$level; } } }
    else {                           # no-want-mult case
      print('  'x$level);print("$$spec[0]\n");
      for(@{$$spec[1]}) { showlines $_,$level+1; } } }

=head1 FILE FORMAT

  The file format supported relies upon indentation of text strings,
to indicate hierarchical nesting for the tree structure.  Strict
indentation (of two space characters per nesting level) is used to
represent parent-child structure.

=head2 COMMENTS

  A line consisting exclusively of whitespace, or a line beginning with
either the pound-sign ("#"), the semicolon (";"), or the forward slash
("/") character will be ignored as a comment.

=head2 CONTINUATION LINES

  A line beginning with whitespace followed by three period (".")
characters, will be concatenated to the previous line, as a
continuation.  The preceding end-of-line, the initial whitespace and
the ellipsis ("...") will be removed and otherwise ignored, to allow
long strings to be represented within line-length constraints.

=head2 INCLUDE FILES

  In addition, any line consisting of indentation followed by "include"
will be interpreted as a file-include request.  In this case, succeeding
whitespace followed by a file specification will cause the contents of
the named file to be substituted at that point in the tree.

=head1 AUTHOR

John Kirk <johnkirk@dystanhays.com>

-head1 COPYRIGHT

  Copyright (c) 2000 John Kirk. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), FileHandle(3pm), Exporter(3pm), Autoloader(3pm)
  and http://perl.dystanhays.com/jnk -- for gory details and examples.

=cut

sub showlines { my ($gl,$spec,$level)=@_;
  if(!defined $level) { $level=0; } if(!defined $spec) { $spec=$$gl{top}; }
  if(ref($$spec[0]) eq 'ARRAY') {
    for my $item (@$spec) {
      print('  'x$level);print("$$item[0]\n");
      for(@{$$item[1]}) { showlines $gl,$_,$level+1; } } }
  else {
    print('  'x$level);print("$$spec[0]\n");
    for(@{$$spec[1]}) { showlines $gl,$_,$level+1; } } }

sub showglobals { my ($gl)=@_;
  for(keys %{$gl}) { print("$_: $$gl{$_}\n"); } }
