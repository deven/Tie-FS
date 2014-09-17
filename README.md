# NAME

Tie::FS - Read and write files using a tied hash

# VERSION

Version 0.1.0

# SYNOPSIS

    use Tie::FS;                       # Initialize Tie::FS module.

    tie %hash, Tie::FS, $flag, $dir;   # Ties %hash to files in $dir.

    @files = keys %hash;               # Retrieves directory list of $dir.

    $data = $hash{$file1};             # Reads "$dir/$file1" into $data.
    $hash{$file1} = $data;             # Writes $data into "$dir/$file1".
    $hash{$file2} = $hash{$file1};     # Copies $file1 to $file2.

    if (exists $hash{$path}) {...}     # Checks if $path exists at all.

    if (defined $hash{$path}) {...}    # Checks if $path is a file.

    $data = delete $hash{$file};       # Deletes $file, returns contents.

    undef %hash;                       # Deletes ALL regular files in $dir.

# DESCRIPTION

This module ties a hash to a directory in the filesystem.  If no directory
is specified in the $dir parameter, then "." (the current directory) is
assumed.  The $flag parameter defaults to the "Create" flag.

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

# CAVEATS

Unless an absolute path was specified to tie(), a later chdir() will affect
the paths accessed by the tied hash with relative paths.

A symbolic link is considered a non-regular file; it will not be followed
unless a "/" follows the link name and the link points to a directory.

To perform a defined() test, the entire file must be read into memory, even
if it will be discarded immediately after the test.  The exists() function
does not need to read the contents of a file.

# AUTHOR

Deven T. Corzine <deven@ties.org>

# BUGS

Please report any bugs or feature requests to `bug-tie-fs at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tie-FS](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tie-FS).

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tie::FS

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tie-FS](http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tie-FS)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/Tie-FS](http://annocpan.org/dist/Tie-FS)

- CPAN Ratings

    [http://cpanratings.perl.org/d/Tie-FS](http://cpanratings.perl.org/d/Tie-FS)

- Search CPAN

    [http://search.cpan.org/dist/Tie-FS/](http://search.cpan.org/dist/Tie-FS/)

# ACKNOWLEDGEMENTS

File::Slurp was the inspiration for this module, which is intended to
provide similar functionality in a more "Perlish" way.

# LICENSE AND COPYRIGHT

Copyright 2011 Deven T. Corzine.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
