package Tie::Filesystem;

$VERSION = '0.9.0';

=head1 NAME

Tie::Filesystem - Perl module to read/write files using a tied hash

=head1 SYNOPSIS

  use Tie::Filesystem;

  tie %hash, Tie::Filesystem, $flag, $dir; # Ties %hash to files in $dir.

  @files = keys %hash;               # Retrieves directory list of $dir.

  $data = $hash{$file1};             # Reads "$dir/$file1" into $data.
  $hash{$file1} = $data;             # Writes $data into "$dir/$file1".
  $hash{$file2} = $hash{$file1};     # Copies $file1 to $file2.

  if (exists $hash{$path}) {...}     # Checks if $path exists at all.

  if (defined $hash{$path}) {...}    # Checks if $path is a file.

  $data = delete $hash{$file};       # Deletes $file, returns contents.

  undef %hash;                       # Deletes ALL regular files in $dir.

=head1 DESCRIPTION

This module ties a hash to a directory in the filesystem.  If no directory
is specified in the $dir parameter, then "." (the current directory) is
assumed.  The $flag parameter defaults to the "Create" flag.

The following (case-insensitive) flags are available:

  ReadOnly      Access is strictly read-only.
  Create        Files may be created but not overwritten or deleted.
  Overwrite     Regular files may be created, overwritten or deleted.
  ClearDir      Also allow files to be cleared (all deleted at once).

The pathname specified as a key to the hash may either be a relative path
or an absolute path.  For relative paths, the default directory specified
to "tie" will be prepended to the path.

=head1 CAVEATS

Unless an absolute path was specified to "tie", later "chdir" commands
will affect the paths accessed by the tied hash with relative paths.

Only regular files are defined when fetched from the tied hash.  However,
directories and other non-regular files will pass an "exists" test.

=head1 AUTHOR

Deven T. Corzine <deven@ties.org>

=cut

use strict;
use vars qw($VERSION);

use Carp;
use Symbol;

sub TIEHASH {
   my $class = shift;
   my $flag = lc shift || "create";
   my $dir = shift || '.';

   croak "$class: Usage: \"tie %hash, $class, $dir, $flag;\"" if @_;

   croak "$class: Invalid flag \"$flag\"" unless $flag eq "readonly" or
      $flag eq "create" or $flag eq "overwrite" or $flag eq "cleardir";

   my $file_handle = gensym;
   my $dir_handle = gensym;
   opendir $dir_handle, $dir or croak "$class: opendir \"$dir\": $!";

   my $obj = {
      class => $class,
      dir => $dir,
      flag => $flag,
      file_handle => $file_handle,
      dir_handle => $dir_handle,
   };

   return bless $obj, $class;
}

sub FETCH {
   my $self = shift;
   my $file = shift;

   my $class = $self->{class};
   my $handle = $self->{file_handle};

   $file = "$self->{dir}/$file" unless substr($file, 0, 1) eq "/";

   return undef unless -f $file;

   local $/;
   undef $/;

   open $handle, "<$file" or croak "$class: reading \"$file\": $!";
   my $contents = <$handle>;
   close $handle;

   $contents .= "";

   return $contents;
}

sub STORE {
   my $self = shift;
   my $file = shift;
   my $contents = shift;

   my $class = $self->{class};
   my $flag = $self->{flag};
   my $handle = $self->{file_handle};

   return undef unless defined $contents;

   $file = "$self->{dir}/$file" unless substr($file, 0, 1) eq "/";

   if ($flag eq "readonly") {
      croak "$class: won't overwrite \"$file\", flag is \"readonly\""
         if -e $file;
      croak "$class: won't create \"$file\", flag is \"readonly\"";
   } elsif ($flag eq "create") {
      croak "$class: won't overwrite \"$file\", flag is \"create\""
         if -e $file;
   } elsif ($flag eq "overwrite" or $flag eq "cleardir") {
      croak "$class: can't overwrite non-file \"$file\"" if -e $file and
         not -f $file;
   } else {
      die;
   }

   open $handle, ">$file" or croak "$class: writing \"$file\": $!";
   print $handle $contents;
   close $handle;

   return $contents;
}

sub DELETE {
   my $self = shift;
   my $file = shift;

   my $class = $self->{class};
   my $contents = $self->FETCH($file);

   $file = "$self->{dir}/$file" unless substr($file, 0, 1) eq "/";

   lstat $file;

   return undef unless -e _;

   my $flag = $self->{flag};

   if ($flag eq "readonly" or $flag eq "create") {
      croak "$class: won't delete \"$file\", flag is \"$flag\"";
   } elsif ($flag eq "overwrite" or $flag eq "cleardir") {
      croak "$class: won't delete non-file \"$file\"" unless -f _;
   } else {
      die;
   }

   croak "$class: deleting \"$file\": $!" unless unlink $file;

   return $contents;
}

sub CLEAR {
   my $self = shift;

   my $class = $self->{class};
   my $dir = $self->{dir};
   my $flag = $self->{flag};
   my $handle = $self->{file_handle};

   croak "$class: won't clear directory \"$dir\", flag is \"$flag\""
      unless $flag eq "cleardir";

   opendir $handle, $dir or croak "$class: opendir \"$dir\": $!";
   my @files = grep {-f $_} map {"$dir/$_"} readdir $handle;
   close $handle;

   my $file;
   foreach $file (@files) {
      croak "$class: deleting \"$file\": $!" unless unlink $file;
   }
}

sub EXISTS {
   my $self = shift;
   my $file = shift;

   $file = "$self->{dir}/$file" unless substr($file, 0, 1) eq "/";

   lstat $file;

   return -e _;
}

sub FIRSTKEY {
   my $self = shift;

   my $dir = $self->{dir};
   my $handle = $self->{dir_handle};
   my $file;

   rewinddir $handle;
   return $self->NEXTKEY();
}

sub NEXTKEY {
   my $self = shift;

   my $dir = $self->{dir};
   my $handle = $self->{dir_handle};
   my $file;

   {
      $file = readdir $handle;
      redo if defined($file) and $file eq "." || $file eq "..";
   }
   return $file;
}

sub DESTROY {
   my $self = shift;

   closedir $self->{dir_handle};
}

1;
