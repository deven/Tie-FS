package Tie::File;

$VERSION = '0.10';

=head1 NAME

Tie::File - Perl module to read/write files using a tied hash

=head1 SYNOPSIS

  use Tie::File;                     # Initialize Tie::File module.

  tie %hash,Tie::File,$flag,$dir;    # Ties %hash to files in $dir.

  @files = keys %hash;               # Retrieves directory list of $dir.

  $data = $hash{$file1};             # Reads "$dir/$file1" into $data.
  $hash{$file1} = $data;             # Writes $data into "$dir/$file1".
  $hash{$file2} = $hash{$file1};     # Copies $file1 to $file2.

  if (exists $hash{$path}) {...}     # Checks if $path exists at all.

  if (defined $hash{$path}) {...}    # Checks if $path is a file.

  $data = delete $hash{$file};       # Deletes $file, returns contents.

  undef %hash;                       # Deletes ALL regular files in $dir.

=head1 DESCRIPTION

This extension ties a hash to files in a directory.  The $flag parameter
specifies an access mode, defaulting to "Create" mode.  If no directory is
specified with the $dir parameter, "." is used for the current directory.

The following (case-insensitive) access flags are available:

  ReadOnly      Access is strictly read-only.
  Create        Files may be created but not overwritten or deleted.
  Overwrite     Files may be created, overwritten or deleted.
  ClearDir      Also allow files to be cleared (all deleted at once).

The pathname specified as a key to the hash may either be a relative path
or an absolute path.  For relative paths, the default directory specified
to tie() will be prepended to the path.

The exists() function will be true if the specified path exists, including
directories and non-regular files (such as symbolic links).  Directories and
non-regular files will return undef; only regular files will return a defined
values.  Empty regular files return "", not undef.  Attempting to store undef
in the tied will have no effect.

The keys() function will scan the directory (without sorting it), eliminate
"." and ".." entries and append "/" for directories.  (values() and each()
will follow the same rules for selecting entries.)  The following code will
retrieve a sorted list of subdirectories:

  @subdirs = sort grep {s/\/$//} keys %hash;

=head1 CAVEATS

Unless an absolute path was specified to tie(), a later chdir() will affect
the paths accessed by the tied hash with relative paths.

A symbolic link is considered a non-regular file; it will not be followed
unless a "/" follows the link name and the link points to a directory.

To perform a defined() test, the entire file must be read into memory, even
if it will be discarded immediately after the test.  The exists() function
does not need to read the contents of a file.

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

   croak "$class: Usage: \"tie %hash,$class,$dir,$flag;\"" if @_;

   croak "$class: Invalid flag \"$flag\"" unless $flag eq "readonly" or
      $flag eq "create" or $flag eq "overwrite" or $flag eq "cleardir";

   my $file_handle = gensym;
   my $dir_handle = gensym;
   opendir $dir_handle,$dir or croak "$class: opendir \"$dir\": $!";

   my $obj = {
      class => $class,
      dir => $dir,
      flag => $flag,
      file_handle => $file_handle,
      dir_handle => $dir_handle,
   };

   return bless $obj,$class;
}

sub FETCH {
   my $self = shift;
   my $file = shift;

   my $class = $self->{class};
   my $handle = $self->{file_handle};

   $file = "$self->{dir}/$file" unless substr($file,0,1) eq "/";

   lstat $file;
   return undef unless -f _;

   local $/;
   undef $/;

   open $handle,"<$file" or croak "$class: reading \"$file\": $!";
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

   $file = "$self->{dir}/$file" unless substr($file,0,1) eq "/";

   lstat $file;

   if ($flag eq "readonly") {
      croak "$class: won't overwrite \"$file\", flag is \"readonly\""
         if -e _;
      croak "$class: won't create \"$file\", flag is \"readonly\"";
   } elsif ($flag eq "create") {
      croak "$class: won't overwrite \"$file\", flag is \"create\""
         if -e _;
   } elsif ($flag eq "overwrite" or $flag eq "cleardir") {
      croak "$class: can't overwrite non-file \"$file\"" if -e _ and not -f _;
   } else {
      die;
   }

   open $handle,">$file" or croak "$class: writing \"$file\": $!";
   print $handle $contents;
   close $handle;

   return $contents;
}

sub DELETE {
   my $self = shift;
   my $file = shift;

   my $class = $self->{class};
   my $contents = $self->FETCH($file);

   $file = "$self->{dir}/$file" unless substr($file,0,1) eq "/";

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

   opendir $handle,$dir or croak "$class: opendir \"$dir\": $!";
   my @files = grep {lstat $_ and -f _} map {"$dir/$_"} readdir $handle;
   close $handle;

   my $file;
   foreach $file (@files) {
      croak "$class: deleting \"$file\": $!" unless unlink $file;
   }
}

sub EXISTS {
   my $self = shift;
   my $file = shift;

   $file = "$self->{dir}/$file" unless substr($file,0,1) eq "/";

   lstat $file;

   return -e _;
}

sub FIRSTKEY {
   my $self = shift;

   my $handle = $self->{dir_handle};

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
      last unless defined $file;
      redo if $file eq "." || $file eq "..";
      lstat "$dir/$file";
      $file .= "/" if -d _;
   }
   return $file;
}

sub DESTROY {
   my $self = shift;

   closedir $self->{dir_handle};
}

1;
