package Demeter::Plugins::FileType;

use Moose;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;
use File::Spec;

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 0);
has 'description' => (is => 'ro', isa => 'Str',  default => "Base class for file type plugins");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str',     default => q{},
		     trigger => sub{my ($self, $new) = @_;
				    my ($name, $path, $suffix) = fileparse($new);
				    $self->filename($name);
				    $self->folder($path);
				  });
has 'filename'    => (is => 'rw', isa => 'Str', default => q{});
has 'folder'      => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plugins::FileType - base class for file type plugins

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

   my $filetype  = Demeter::Plugins::X15B->new(file=>$file);
   if ($filetype->is) {
     my $converted = $filetype->fix;
     my $data = Demeter::Data->new(file => $converted,
    	                           $filetype -> suggest("fluorescence")
                                  );
   };

=head1 DESCRIPTION

A file type plugin is used to address the common situation of raw XAS
data from a beamline which is in a form that cannot be read directly
by Ifeffit.  Some common reasons for this are data in a binary format,
data with an ambiguous separation between header and data, and
ill-formed numbers (e.g. NaN or missing white space between columns)
among the columns of data.

The user of a data analysis program does not much care about the
reasons that a particular data file might be unreadable by Ifeffit --
that person is only concerned with getting some analysis done.
Consequently, a program like Athena must do one of two things:

=over 4

=item 1.

Treat each such file as a special case and include custom code for
dealing with each such case, or

=item 2.

Provide a plugin mechanism with which a small amount of code can be
dropped in some well-advertised location and which can be used to
change the troublesome data into a more easily handled from.

=back

Demeter adopts the second option.  Ifeffit is used for data import.
All data files must be readable by Ifeffit.  For those kinds of data
file that are not easily read by Ifeffit, a plugin is used to convert
the data from the troublesome format into a standard, well-formatted,
column data file.  The normal input mechanism is then used to import
the data into a L<Demeter::Data> object.

All file type plugins are implemented as L<Moose> objects.  As such,
all file type plugins must have certain attributes and methods so that
data handling programs (such as Athena) can expect uniformity of
interface.  The best way to meet these requirements is to modify an
existing file type plugin.

See the F<022_filetypes.t> test from the Demeter distribution for an
example of using the methods of a file type plugin and creating
Demeter::Data objects from the output of the plugins.

Note that this base class uses the L<Demeter::Project> and
L<Demeter::Tools> roles and so all subclasses have access to the
methods of those roles.

=head2 Plugins shipped with Demeter

The following plugins come with Demeter.  Please note that these were
written using example data files that Bruce had available to him.  He
has not himself used all of these beamlines.  Your mileage may vary
with your own data.

=over 4

=item C<X10C>

Convert files from NSLS beamline X10C.  These files have headers which
confuse Ifeffit and sometimes fail to have white space separating
numbers among the data columns.  The plugin comments out the headers
and corrects the problem with white space between columns.

=item C<X15B>

Convert files from NSLS beamline X15B.  This beamline uses an ancient
data acquisition system which writes files in a cryptic binary
format.  This plugin converts these data to a simple column data file,
saving only the scalars containing the XAS-relevant measurement
channels.

=item C<PFBL12C>

Convert files from Photon Factory beamline 12C.  These files have
headers which will confuse Ifeffit's file import and store data as a
function of monochromator angle.  This plugin comments the header and
converts mono angle to energy using information about the crystal type
contained in the header.

=item C<SSRLB>

Convert SSRL binary data file.  Yes, SSRL does provide a program for
converting these binary files to column ASCII data.  This plugin does
the same chore, yielding a file easily read by Ifeffit.

=item C<SSRLA>

Convert SSRL ASCII data file.  Presumably, these ASCII files are the
result of the SSRL conversion program.  These AsCII files are
unreadable by Ifeffit.  This plugin, comments out the header lines,
constructs a column label line out of the Data: section, moves the
first column (real time clock) to the third column, and swaps the
requested and acheived energy columns.

=item C<SSRLmicro>

Sam Webb's microprobe data acquisition program writes files with lots
of columns and with a header structure that cannot be easily used by
Ifeffit.  This plugin massages that file format into a form more
easily ready by Ifeffit, keeping only the ROI columns.  (Note that
this plugin could be modified quite easily to perform a simple ICR/OCR
deadtime correction.)

=item C<HXMA>

Files from the HXMA beamline at the Canadian Light Source are readable
by Ifeffit, but the columns are labeled in a way that Ifeffit is
unable to use.  This plugin restructures the header for Ifeffit's
convenience and keeps only the columns containing the ion chambers and
the corrected (presumably by a simple ICR/OCR deadtime correction) ROI
signals from the multi-element detector.

=item C<CMC>

Files from APS beamline 9BM (CMC-XOR) are single-record Spec files.
As a result, these data files contain lots of useless column (for
example, each file inexplicably saves h, k, and l values).  This
plugin discard all the useless columns, keeping only those from the
ion chambers and the multi-element detector.  It also discards the
problematic "logi0i1" column, which can result in NaN entries in the
case of zero signal on the transmission detector.

=item C<X23A2MED>

Data measured using the Vortex silicon drift detector at NSLS X23A2
are imported and deadtime corrected using the point-by-point iterative
algorithm developed and implemented by Joe Woicik and Bruce Ravel.
The output data file contains columns for each corrected detector
channel as well as columns for the various ion chambers.  This is an
example of a file type plugin which uses Ifeffit dirrectly.

=item C<Lytle>

Import files from the Lytle database.  This plugin imports those data
that are recorded by encoder value and which have headers that start
with the word C<NPTS> and have the mono d-spacing and steps-per-degree
in the second line.  There is another common file format in the Lytle
database (the header begins with C<CUEDGE> and does not record the
mono parameters) that is not handled by this plugin.  See question 3
at L<http://cars9.uchicago.edu/ifeffit/FAQ/Data_Handling>.

=back

As you can see, the plugins serve multiple purposes.  On one hand,
they massage unreadable data (as in the binary formats) into a
readable form.  They can also be used to do some pre-processing of the
data, as in the case of plugins which remove unnecessary columns from
the converted data files.

Plugins could be used for other sorts of data pre-processing.  For
example, it would be possible to apply deadtime corrections using
columns contained in the original data file.  As another example, a
plugin could also be used to remove a dark current from a data file
which records the dark current in the header but does not remove that
dark signal from the recorded scalars.

=head2 Boilerplate

A file type plugin should start with the boilerplate like the
following:

  package Demeter::Plugins::X15B;
  use Moose;
  extends 'Demeter::Plugins::FileType';
  has '+is_binary' => (default => 1);
  has '+description' => (default => "Read binary files from NSLS beamline X15B.");

This will set up the plugin as a class derived from the
L<Demeter::Plugins::FileType> base class and set the correct values
for the C<is_binary> and C<description> attributes.  This boilerplate
will be followed by the C<is>, C<fix> and C<suggest> methods which
define the file type plugin interface.

=head2 Common attributes

Every file type plugin has the following attributes, all of which are
inherited from the L<Demeter::Plugin::FileType> base class.  Normally,
an individual file type plugin will need to override the C<is_binary>
and C<description>, as shown above.

=over 4

=item C<is_binary>

This is a Boolean which indicates whether the original data file was
in a binary format.  The use of this flag is indicate to a GUI program
whether the original data file can be displayed as text.

=item C<description>

A brief textual description of the purpose of the plugin.  This should
be succinct and should fit on one short line.

=item C<parent>

Used by a GUI...

=item C<hash>

This is a hash reference used to pass parameters into and out of the
plugin.  For example, the X23A2MED plugin uses this attribute to pass
in deadtime values and the names of the columns used to perform the
deadtime correction.

=item C<file>

This takes the name of the original data file and is the only
attribute typically supplied by the caller.

=item C<filename>

This is the file name part of the value of the C<file> attribute.
This is set by a trigger when the C<file> attribute is set.  All the
file type plugins that ship with Demeter write the output column data
file to the stash directory with the same name as the input file.  The
bit of code that does that copying uses this attribute to name the
output file.  You should rarely need to set this directly.

=item C<folder>

This is the folder part of the value of the C<file> attribute.  This
is set by a trigger when the C<file> attribute is set.  You should
rarely need to set this directly.

=item C<fixed>

This contains the fully resolved file name of the converted file.
The converted file typically sits in Demeter's stash folder.

=back

=head2 Required methods

All plugins B<must> supply these three methods:

=over 4

=item C<is>

The C<is> method is used to recognize a data file of a particular
format.  Typically, this recognition is made by examining the contents
of the data file and finding some identifying feature of the contents.

  my $filetype = Demeter::Plugins::X15B->new(file=>$file);
  my $is_x15b  = $filetype->is;

The C<is> method returns a true value if the file is recognized and a
false value if not.

Note that the C<is> method must be fast.  It is possible that a data
file will be checked against many different file types.  A poorly
written C<is> method can seriously impede the performance of a data
processing program.

=item C<fix>

The C<fix> method opens the file contained in the C<file> attribute,
applies whatever processing needs to happen and writes that file as a
normal column data file.  The fully-resolved filename of the output
file is stored in the C<fixed> attribute B<and> is the return value of
this method.  All plugins that come with Demeter write the output file
to Demeter's stash folder and use the same name as the input data
file.  This is good practice, but is not required.


      my $filetype  = Demeter::Plugins::X15B->new(file=>$file);
      my $converted_file = $filetype->fix;
       ## this also works:
       ## my $converted_file = $filetype->fixed;


The C<fix> method can be written using virtually any tool, including
tools provided by Demeter itself.  It can also call Ifeffit directly
if you C<use Ifeffit;> at the top of the plugin file.  You can even
use external tools such as L<PDL>, L<Math::Cephes>, or other
heavy-duty mathematics utilities.

Speed is appreciated, but correctness is essential.

=item C<suggest>

This method returns an array containing values for the C<energy>,
C<numerator>, C<denominator>, and C<ln> attributes of the
L<Demeter::Data> object.  If the C<fix> method leaves the data file in
a format for which correct column selection for transmission or
fluorescence XAS is predictable, this method helps lower the barrier
of using the plugin.

      my $filetype  = Demeter::Plugins::X15B->new(file=>$file);
      if ($filetype->is) {
        my $converted = $filetype->fix;
	my $data = Demeter::Data->new(file => $converted,
	   	   	              $filetype -> suggest("fluorescence")
                                     );
      };

Here the suggested column numbers for the energy, fluorescence
(numerator), and I0 (denominator) channels are returned by the
C<suggest> method for use in defining the L<Demeter::Data> object.

This method takes a single argument, which should be either
"transmission" or "fluorescence".  If the argument is missing,
"transmission" is assumed.  If the argument has a value but is not
"transmission", then "fluorescence" is assumed.  (So spell carefully!)

If the proper columns are not predictable, then this method should
return an empty array.

The return value should be an array and not an array reference.

=back

=head2 Namespace and disk locations

All plugins B<must> live in the C<Demeter::Plugins::> namespace.  In
the Demeter distribution, therefore, they live in the
F<Demeter/Plugins> folder beneath the installation location.

An individual user can have additional plugins in user diskspace by
placing them in ...

=over 4

=item unix

  $HOME/.horae/Demeter/Plugins/

=item Windows

  %APPDATA%\horae\Demeter\Plugins\

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Do I need the C<parent> and C<hash> attributes?

=item *

None of the plugins have enough error testing.  It is certainly
possible that C<is> could return true but the rest of the file is
malformed compared to the expectations of C<fix>.

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://xafs.org/BruceRavel

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut