package Demeter::Plot;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use autodie qw(open close);

use Moose;
extends 'Demeter';
use MooseX::AttributeHelpers;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Element
			  Edge
			  Clamp
			  FitSpace
			  Window
			  Empty
			  DataType
			  PgplotLine
			  MERIP
			  PlotWeight
			  Interp
		       );
use Demeter::NumTypes qw( Natural
			  PosInt
			  PosNum
			  NonNeg
			  OneToFour
			  OneToTwentyNine
		       );

use Carp;
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};
use String::Random qw(random_string);
#use YAML;


has 'charsize'  => (is => 'rw', isa =>  PosNum,    default => sub{ shift->co->default("plot", "charsize") || 1.2});
has 'charfont'  => (is => 'rw', isa =>  OneToFour, default => sub{ shift->co->default("plot", "charfont") || 1});
has 'key_x'     => (is => 'rw', isa =>  PosNum,    default => sub{ shift->co->default("plot", "key_x")    || 0.8});
has 'key_y'     => (is => 'rw', isa =>  PosNum,    default => sub{ shift->co->default("plot", "key_y")    || 0.9});
has 'key_dy'    => (is => 'rw', isa =>  PosNum,    default => sub{ shift->co->default("plot", "key_dy")   || 0.075});

## I need a Color type
has 'bg'        => (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "bg")        || "white"});
has 'fg'        => (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "fg")        || "black"});
has 'showgrid'  => (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "showgrid")  || 1});
has 'gridcolor' => (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "gridcolor") || "grey82"});

has 'increm'    => (is => 'rw', isa =>  Natural,    default => 0);
has 'col0'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col0") || "blue"});
has 'col1'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col1") || "red"});
has 'col2'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col2") || "green4"});
has 'col3'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col3") || "darkviolet"});
has 'col4'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col4") || "darkorange"});
has 'col5'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col5") || "brown"});
has 'col6'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col6") || "deeppink"});
has 'col7'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col7") || "gold3"});
has 'col8'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col8") || "cyan3"});
has 'col9'	=> (is => 'rw', isa =>  'Str',    default => sub{ shift->co->default("plot", "col9") || "yellowgreen"});

has 'datastyle' => (is => 'rw', isa =>  PgplotLine, default => sub{ shift->co->default("plot", "datastyle")  || "solid"});
has 'fitstyle'  => (is => 'rw', isa =>  PgplotLine, default => sub{ shift->co->default("plot", "fitstyle")   || "solid"});
has 'partstyle' => (is => 'rw', isa =>  PgplotLine, default => sub{ shift->co->default("plot", "partstyle")  || "solid"});
has 'pathstyle' => (is => 'rw', isa =>  PgplotLine, default => sub{ shift->co->default("plot", "pathstyle")  || "solid"});

has 'space'	=> (is => 'rw', isa =>  FitSpace, default => 'r');
has 'emin'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "emin")	  || -200});
has 'emax'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "emax")	  || 800});
has 'e_mu'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_mu")	  || 1});
has 'e_bkg'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_bkg")	  || 0});
has 'e_pre'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_pre")	  || 0});
has 'e_post'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_post")    || 0});
has 'e_norm'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_norm")    || 0});
has 'e_der'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_der")	  || 0});
has 'e_sec'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_sec")	  || 0});
has 'e_markers'	=> (is => 'rw', isa =>  'Bool',   default => sub{ shift->co->default("plot", "e_markers") || 0});
has 'e_part'	=> (is => 'rw', isa =>  'Str',    default => q{});
has 'e_smooth'	=> (is => 'rw', isa =>  'Int',    default => sub{ shift->co->default("plot", "e_smooth")  || 0});
has 'e_zero'	=> (is => 'rw', isa =>  'Bool',   default => 0);
has 'kmin'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "kmin") || 0});
has 'kmax'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "kmax") || 15});
has 'rmin'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "rmin") || 0});
has 'rmax'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "rmax") || 6});
has 'r_pl'	=> (is => 'rw', isa =>  MERIP,    default => sub{ shift->co->default("plot", "r_pl") || "m"});
has 'qmin'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "qmin") || 0});
has 'qmax'	=> (is => 'rw', isa =>  'Num',    default => sub{ shift->co->default("plot", "qmax") || 15});
has 'q_pl'	=> (is => 'rw', isa =>  MERIP,    default => sub{ shift->co->default("plot", "q_pl") || "r"});

has 'kweight'		=> (is => 'rw', isa =>  'Num',      default => "1",
			    trigger => sub{my ($self) = @_; $self->propagate_kweight});
has 'window_multiplier' => (is => 'rw', isa =>  'Num',      default => 1.05);
has 'plot_data'	        => (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_fit'		=> (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_win'		=> (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_res'		=> (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_bkg'		=> (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_paths'	=> (is => 'rw', isa =>  'Bool',     default => 0);
has 'plot_rmr_offset'	=> (is => 'rw', isa =>   NonNeg,    default => 0);


has 'nindicators'    => (is => 'rw', isa =>  PosInt,          default => sub{ shift->co->default("indicator", "n")     || 8});
has 'indicatorcolor' => (is => 'rw', isa =>  'Str',           default => sub{ shift->co->default("indicator", "color") || "violetred"});
has 'indicatorline'  => (is => 'rw', isa =>  'Str',           default => sub{ shift->co->default("indicator", "line")  || "solid"});
has 'showmarker'     => (is => 'rw', isa =>  'Str',           default => sub{ shift->co->default("marker", "show")     || 1});
has 'markertype'     => (is => 'rw', isa =>  OneToTwentyNine, default => sub{ shift->co->default("marker", "type")     || 9});    # number 1 to 29, 9 is a dotted circle
has 'markersize'     => (is => 'rw', isa =>  'Num',           default => sub{ shift->co->default("marker", "size")     || 2});
has 'markercolor'    => (is => 'rw', isa =>  'Str',           default => sub{ shift->co->default("marker", "color")    || "orange"});

has 'New'    => (is => 'rw', isa =>  'Bool',          default => 0);
has 'color'  => (is => 'rw', isa =>  'Any',           default => q{});
has 'xlabel' => (is => 'rw', isa =>  'Any',           default => q{});
has 'ylabel' => (is => 'rw', isa =>  'Any',           default => q{});
has 'key'    => (is => 'rw', isa =>  'Any',           default => q{});
has 'title'  => (is => 'rw', isa =>  'Any',           default => q{});

has 'tempfiles' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    provides  => {
				  'push'  => 'add_tempfile',
				  'pop'   => 'remove_tempfile',
				  'clear' => 'clear_tempfiles',
				 }
		   );

has 'lastplot'  => (is => 'rw', isa => 'Any',        default => q{});

		       ## interpolation parameters
has 'interp' => (is => 'rw', isa => Interp,          default => sub{ shift->co->default("interpolation", "type") || "qinterp"});


sub BUILD {
  my ($self) = @_;
  $self -> start_plot;
  $self -> mode -> plot($self);
  $self -> mode -> push_Plot($self);
  return;
};

sub alldone {
  my ($self) = @_;
  $self->end_plot;
};

sub start_plot {
  my ($self) = @_;
  my $color = $self->col0;
  $self -> New(1);
  $self -> color($color);
  $self -> xlabel(q{});
  $self -> ylabel(q{});
  $self -> increm(0);
  $self -> lastplot(q{});
  $self -> co -> set(plot_part=>q{});
  return $self;
};

sub increment {
  my ($self) = @_;
  my $incr = $self->increm;
  ++$incr;
  $incr = $incr % 10;
  my $cc = 'col' . $incr;
  my $color = $self->$cc;
  $self->New(0);
  $self->color($color);
  return $self->increm($incr);
};
sub reinitialize {
  my ($self, $xl, $yl) = @_;
  $self -> xlabel($xl);
  $self->ylabel($yl);
  $self->key(q{});
  $self->title(q{});
  #$self->color(q{});
  #$self->New(1);
  $self->e_part(q{});
  return $self->increm;
};
sub end_plot {
  my ($self) = @_;
  return $self;
};


sub tempfile {
  my ($self) = @_;
  my $this = File::Spec->catfile($self->stash_folder, random_string('cccccccc'));
  $self->add_tempfile($this);
  return $this;
};
sub cleantemp {
  my ($self) = @_;
  foreach my $f (@{ $self->tempfiles }) {
    unlink $f;
  };
  $self -> clear_tempfiles;
  return $self;
};


sub legend {
  my ($self, @arguments) = @_;
  my %args = @arguments; # coerce to a hash
  foreach my $which (qw(dy y x)) {
    my $k = "key_".$which;
    $args{$which} ||= $args{$k};
    $args{$which} ||= $self->$k;
  };

  foreach my $key (keys %args) {
    next if ($key !~ m{\A(?:dy|x|y)\z});
    my $k = "key_".$key;
    $self->$k($args{$key});
  };
  Ifeffit::put_scalar('&plot_key_x' , $self->key_x);
  Ifeffit::put_scalar('&plot_key_y0', $self->key_y);
  Ifeffit::put_scalar('&plot_key_dy', $self->key_dy);
  return $self;
};

## size cannot be negative, font must be 1-4
sub font {
  my ($self, @arguments) = @_;
  my %args = @arguments; # coerce to a hash
  $args{font} ||= $args{charfont};
  $args{size} ||= $args{charsize};
  $args{font} ||= $self->charfont;
  $args{size} ||= $self->charsize;
  foreach my $key (keys %args) {
    next if ($key !~ m{\A(?:font|size)\z});
    my $k = "char$key";
    $self->$k($args{$key});
  };
  my $command = sprintf("plot(charfont=%d, charsize=%s)\n", $self->charfont, $self->charsize);
  $self->dispose($command);
  return $self;
};

sub textlabel {
  my ($self, $x, $y, $text) = @_;
  my $command = $self->template("plot", "label", {  x    => $x,
						   'y'   => $y,
						    text => $text
						 });
  #if ($self->get_mode("template_plot") eq 'gnuplot') {
  #  $self->get_mode('external_plot_object')->gnuplot_cmd($command);
  #} else {
  $self -> dispose($command, "plotting");
  #};
  return $self;
};

sub outfile {
  my ($self, $type, $file) = @_;
  my %devices = (png => '/png', ps => '/cps');
  my $command = $self->template("plot", "file", { device => $devices{$type},
						  file   => $file });
  $self -> dispose($command, "plotting");
  return $self;
};

sub propagate_kweight {
  my ($self) = @_;
  $_->update_fft(1) foreach (@{ $self->mode->Data }, @{ $self->mode->Path }, @{ $self->mode->VPath });
};


1;

=head1 NAME

Demeter::Plot - Controlling plots of XAS data

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

  $object -> po -> set(kweight=>3);

=head1 DESCRIPTION

This subclass of Demeter is for holding information pertaining to how
plots of data and paths are made.

=head1 METHODS

This uses the C<set>, and C<get> methods of the parent class.

The typical way of accessing these methods is in a chain with the
C<po> method.  All of the examples below demonstrate that.  You can
also store the reference to the plot object as a scalar and used that:

  $plot_object - $other_object -> po;
  $plot_object -> set(kweight=>3);

=over 4

=item C<start_plot>

This method reinitializes a plot.  In terms of Ifeffit, the next plot made
after running this method will be a C<newplot()>.  Each subsequent plot until
the next time C<start_plot> is called will be a C<plot()>.  Also, the sequence
of colors is reset when this method is called.

  $object -> po -> start_plot;

=item C<legend>

This is a convenience method for controlling the appearence of the legend in
the plot.  This will set the legend parameters (C<key_x>, C<key_y>, and
C<key_dy>) and return the Ifeffit command to reset the legend.

  $object -> po -> legend(x=>0.6, y=>0.8, dy=>0.05);

Note that you get to drop "key" in the arguments to this method,
although C<x> and C<key_x> will be interpreted the same.

=item C<font>

This is a convenience method for controlling the appearence of the text in
the plot.  This will set the text attributes (C<charfont> and
C<charsize>) and return the Ifeffit command to reset the text.

  $object -> po -> font(font=>4, size=>1.8)

Note that you get to drop "char" in the arguments to this method,
although C<font> and C<charfont> will be interpreted the same.

The available pgplot fonts are: 1=sans serif, 2=roman, 3=italic,
4=script.  If the font is not one of those numbers, it will fall back
to 1.  The size cannot be negative.  Values larger than around 1.8 are
allowed, but are probably a poor idea.

=item C<label>

Place a textual label on the plot at a specified point.

  $object -> po -> label($x, $y, $text);

=back

=head1 ATTRIBUTES

The following are the attributes of the Plot object.  Attempting to
access an attribute not on this list will throw an exception.

The type of argument expected in given in parentheses. i.e. number,
integer, string, and so on.  The default value, if one exists, is
given in square brackets.

=over 4

=item C<group> (string) I<[a random four-letter string]>

This string is used as the unique identifier for the Plot object.

=item C<space> (letter) I<[r]>

The space in which to preform the plot.  It must be one of E, k, r, or q.

=item C<color>

The next line color to be used.  This is updated automatically by the
plotting methods.

=item C<increment>

A counter for the number of traces already drawn in the current plot.

=item C<new>

A flag indicating whether to start a new plot or to plot over the
current one.

=back

=head2 Text and colors

=over 4

=item C<charsize> (number) I<[1.2]>

The character size in PGPLOT plots.

=item C<charfont> (integer) I<[1]>

The font type used in plots with PGPLOT.  The available fonts are:
1=sans serif, 2=roman, 3=italic, 4=script.

=item C<key_x> (number) I<[0.8]>

The location in x of the plot legend as a fraction of the full window
width.

=item C<key_y> (number) I<[0.9]>

The location in y of the plot legend as a fraction of the full window
height.

=item C<key_dy> (number) I<[0.075]>

The separation in y of the entried in the plot legend as a fraction of
the full window height.

=item C<bg> (color) I<[white]>

The plot background color.

=item C<fg> (color) I<[black]>

The plot foreground color, used for text and the plot frame.

=item C<showgrid> (boolean) I<[1]>

When true, a grid will be shown on the plot.

=item C<gridcolor> (color) I<[grey82]>

The color of the grid drawn on the plot.

=item C<c0> to C<c9> (color)

The line colors.  These are the default colors (as defined in the X
windows F<rgb.txt> file) in order: blue red green4 darkviolet
darkorange brown deeppink gold3 cyan3 yellowgreen.

=back

=head2 Line types

The line type attributes take these possible values:

   solid dashed dotted dot-dash points linespoints

=over 4

=item C<datastyle> (string) I<[solid]>

The line type for plots of data.

=item C<fitstyle> (string) I<[solid]>

The line type for the fit array.

=item C<partstyle> (string) I<[solid]>

The line type for a part of the data, such as the window or the
background.

=item C<pathstyle> (string) I<[solid]>

The line type for a path.

=back

=head2 Energy plots

=over 4

=item C<emin> (number) I<[-200]>

The lower bound of the plot range in energy, relative to e0 of the
data group.

=item C<emax> (number) I<[800]>

The upper bound of the plot range in energy, relative to e0 of the
data group.

=item C<e_mu> (boolean) I<[1]>

A flag for whether to plot mu(E) in an energy plot.

=item C<e_bkg> (boolean) I<[0]>

A flag for whether to plot the background in an energy plot.

=item C<e_pre> (boolean) I<[0]>

A flag for whether to plot the pre-edge line in an energy plot.

=item C<e_post> (boolean) I<[0]>

A flag for whether to plot the post-edge line in an energy plot.

=item C<e_norm> (boolean) I<[0]>

A flag for whether to plot mu(E) and the background as normalized data
in an energy plot.

=item C<e_der> (boolean) I<[0]>

A flag for whether to plot muE() as a derivative spectrum in an energy
plot.

=item C<e_sec> (boolean) I<[0]>

A flag for whether to plot the mu(E) as a second derivative spectrum
in an energy plot.

=item C<C<e_markers>> (boolean) I<[0]>

If true, than markers will be plotted in energy as appropriate to indicate the
positions of E0 and the boundaries of the pre- and post-edge resions.

=item C<e_part> () I<[]>

q{},

=item C<e_smooth> (integer) I<[0]>

When non-zero, data plotted in energy will be smoothed using Ifeffit's
three-point smoothing function.  The number is the number of
repititions of the smoothing function.

=item C<e_zero> (boolean) I<[0]>

When true, data plotted in energy have C<bkg_e0> subtracted from the
energy array.  Thus mu(E) data are plotted with the edge energy at 0.
The purpose of this is to facilitate overplotting data from different
edges.

=back

=head2 k plots

=over 4

=item C<kmin> (number) I<[0]>

The lower bound of the plot range in k.

=item C<kmax> (number) I<[15]>

The upper bound of the plot range in k.

=item C<kweight> (number) I<[1]>

The k-weighting to use when plotting in k or in a Fourier transform
before plottingin R or q.  Typically, this is 1, 2, or 3, but can
actually be any number.  When this gets changed, all Data, Path, and
VPath objects will be flagged as needing to be brought up-to-date for
their forward Fourier transform.

=back

=head2 R plots

=over 4

=item C<rmin> (number) I<[0]>

The lower bound of the plot range in R.

=item C<rmax> (number) I<[6]>

The upper bound of the plot range in R.

=item C<r_pl> (letter) I<[m]>

The part of the Fourier transform to plot when making a multiple data
set plot in R.  The choices are m, p, r, and i for magnitude, phase,
real, and imaginary.

=back

=head2 q plots

=over 4

=item C<qmin> (number) I<[0]>

The lower bound of the plot range in backtransform k.

=item C<qmax> (number) I<[15]>

The upper bound of the plot range in backtransform k.

=item C<q_pl> (letter) I<[r]>

The part of the Fourier transform to plot when making a multiple data
set plot in q.  The choices are m, p, r, and i for magnitude, phase,
real, and imaginary.

=back

=head2 Data parts

=over 4

=item C<plot_data> (boolean) I<[1]>

When making a plot after a fit, the data will be plotted when
this is true.

=item C<plot_fit> (boolean) I<[0]>

When making a plot after a fit, the fit will be plotted when this is
true.

=item C<plot_win> (boolean) I<[0]>

When making a plot after a fit, the Fourier transform window will be
plotted when this is true.

=item C<window_multiplier> (number) I<[1.05]>

This is the scaling factor by which the window is multipled so that it
plots nicely with the data.  The window will be multiplied by the
value of the largest point in the plot, then by this number.

=item C<plot_res> (boolean) I<[0]>

When making a plot after a fit, the residual will be plotted when this
is true.

=item C<plot_bkg> (boolean) I<[0]>

When making a plot after a fit, the background will be plotted when
this is true, if the background was corefined in the fit..

=item C<plot_paths> (boolean) I<[0]>

When making a plot after a fit, all paths used in the fit will be
plotted when this is true.

=back

=head2 Plot ornaments

=over 4

=item C<nindicators> (number) I<[8]>

The maximum number of plot indicators that can be defined.

=item C<indicatorcolor> (color) I<[violetred]>

The color of the plot indicators.

=item C<indicatorline> (string) I<[solid]>

The line type of the plot indicator.  It must be one of

   solid dashed dotted dot-dash points linespoints

=item C<showmarker> (boolean) I<[1]>

Plot markers for things like e0 and the normalization range will be
displayed when this true.

=item C<markertype> (number) I<[9]>

The point style of t he plot marker.  In PGPLOT, this can be a number
between 1 and 29 and 9 is a dotted circle.

=item C<markersize> (number) I<[2]>

The size of the plot marker.

=item C<markercolor> (color) I<[orange]>

The color of the plot marker.

=back

=head1 DIAGNOSTICS


These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).


=over 4

=item C<$key is not a valid Demeter::Data parameter>

You have tried to set in invalid Plot parameter

=item C<Demeter::Plot: $k must be a number>

You have attempted to set an attribute that takes a numerical value to
something other than a number.

=item C<key_X must be a positive number>

(W) You have tried to set one of the legend parameters to something that is
not a positive number.  It was reset to its default.

=item C<The font must be an integer from 1 to 4.>

(W) There are only four types of fonts available and they are numbered 1
through 4.  The font was reset to sans-serif, which is number 1.

=item C<The size must be a positive number>

(W) You have tried to set the font size to something that is not a positive
number.  It was reset to size 1.2.

=item C<Demeter::Plot: $k must be one of solid, dashed, dotted, dot-dash, points, or linespoints>

You have attempted to set an attribute controlling a line to an
unknown line type.

=item C<Demeter::Plot: $k must be one of m, e, r, i, or p>

You have set an attribute controlling which part of complex function
is plotted to something that is not understood as complex function
part.  The choices are C<m>agnitude, C<e>nvelope, C<r>eal,
C<i>maginary, and C<p>hase.

=back

=head1 SERIALIZATION AND DESERIALIZATION

Serialization of a Plot object is still an open question.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
The plot and ornaments configuration groups control the attributes of
the Plot object.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need a boolean flag for indicating energy plots from 0 (i.e. with
bkg_e0 subtracted from the energy array).  With this mu(E) from
different edges can be easily overplotted.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
