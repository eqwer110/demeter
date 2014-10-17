package  Demeter::UI::Artemis::Data::BondValence;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (L<http://bruceravel.github.io/home>).
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

use strict;
use warnings;

use Chemistry::Elements qw(get_symbol);
use Demeter::UI::Wx::SpecialCharacters qw($S02);
use Demeter::UI::Wx::Colours;
use List::MoreUtils qw(any uniq);
use Scalar::Util qw(looks_like_number);
use Statistics::Descriptive;
use Xray::BondValence qw(bvdescribe valences available);

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);
use Wx::Perl::TextValidator;

sub new {
  my ($class, $parent, @paths) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Compute a bond valence sum",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  ## --- elements and valences
  my $gbs = Wx::GridBagSizer->new( 6, 10 );
  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);

  my $abs = get_symbol($paths[0]->bvabs);
  $gbs -> Add( Wx::StaticText -> new($this, -1, $abs.' valence:'),  Wx::GBPosition->new(0,0));
  $this->{valence_abs} = Wx::Choice -> new($this, -1, wxDefaultPosition, wxDefaultSize, [valences($abs)]);
  $gbs -> Add( $this->{valence_abs}, Wx::GBPosition->new(0,1));

  my %unique;
  foreach my $p (@paths) {
    ++$unique{$p->bvscat};
  };
  my $i = 0;
  foreach my $s (sort keys %unique) {
    my $ss = get_symbol($s);
    $gbs -> Add( Wx::StaticText -> new($this, -1, $ss.' valence:'),  Wx::GBPosition->new($i,3));
    my @list = uniq map {(split(/:/, $_))[3]} available($abs, '.', $s); # find possible valences for scatterer
    $this->{"valence_scat$ss"} = Wx::Choice -> new($this, -1, wxDefaultPosition, wxDefaultSize, [@list]);
    $gbs -> Add( $this->{"valence_scat$ss"}, Wx::GBPosition->new($i,4));
    ++$i;
  };

  ## --- s02 value
  my $hbox = Wx::BoxSizer->new ( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $hbox -> Add(Wx::StaticText->new($this, -1, $S02.":"), 0, wxGROW|wxALL, 5);
  $this->{s02} = Wx::TextCtrl->new($this, -1, "1");
  $this->{s02} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $hbox -> Add($this->{s02}, 0, wxGROW|wxALL, 5);

  ## --- compute button
  $this->{compute} = Wx::Button->new($this, -1, 'Compute');
  $vbox -> Add($this->{compute}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{compute}, sub{OnCompute(@_, @paths)});

  ## --- result
  $hbox = Wx::BoxSizer->new ( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $hbox -> Add(Wx::StaticText->new($this, -1, "Bond valence sum:"), 0, wxGROW|wxALL, 5);
  $this->{bvs} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $hbox -> Add($this->{bvs}, 0, wxGROW|wxALL, 5);

  ## --- feedback
  my $fbbox      = Wx::StaticBox->new($this, -1, 'Feedback', wxDefaultPosition, wxDefaultSize);
  my $fbboxsizer = Wx::StaticBoxSizer->new( $fbbox, wxVERTICAL );
  $this->{feedback}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [120, 200], wxTE_MULTILINE|wxTE_READONLY);
  $fbboxsizer   -> Add($this->{feedback},  1, wxGROW|wxALL, 0);
  $vbox         -> Add($fbboxsizer, 1, wxGROW|wxLEFT|wxRIGHT, 5);


  ## --- document button
  $this->{doc} = Wx::Button->new($this, -1, q{Docmentation: BVS}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{doc}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('extended.bvs')});

  ## --- OK button
  $this->{ok} = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);


  $this -> SetSizerAndFit( $vbox );
  return $this;
};

sub OnCompute {
  my ($this, $event, @paths) = @_;
  my $s02 = $this->{s02}->GetValue;
  return if not looks_like_number($s02);
  my $color = Wx::TextAttr->new(Wx::Colour->new('#550000'), $wxBGC,
				Wx::Font->new(9, wxTELETYPE, wxNORMAL,   wxBOLD, 0, "" ) );
  my $sum = 0;
  foreach my $p (@paths) {
    $p->_update("fft");
    $p->valence_abs($this->{valence_abs}->GetStringSelection);
    $p->valence_scat($this->{"valence_scat".$p->bvscat}->GetStringSelection);
    my @found = available($p);
    if ($#found == -1) {
      my $text  = sprintf("Bond valence parameters are not available for the combination of %s %d and %s %d",
			  $p->bvabs, $p->valence_abs, $p->bvscat, $p->valence_scat);
      $this->{feedback}->SetValue($text);
      $this->{feedback}->SetStyle(0, $this->{feedback} -> GetLastPosition, $color);
      return;
    };
    $sum += $p->bv($s02);
  };
  $this->{bvs}->SetValue(sprintf("%.3f", $sum));

  my %seen;
  my $text = "Bond valence parameters:\n";
  foreach my $p (@paths) {
    next if $seen{$p->bvscat};
    $text .= "  ".bvdescribe($p).$/;
    ++$seen{$p->bvscat};
  };
  $this->{feedback}->SetValue($text);
  $this->{feedback}->SetInsertionPointEnd;

  $text = "\n" . $this->sanity_path_too_long(@paths) . "\n\n";
  $text .= $this->sanity_paths_split_shells(@paths) . "\n\n";
  $text .= $this->sanity_ms_paths(@paths) . "\n";

  if ($text !~ m{\A\s*\z}) {
    my $was = $this->{feedback} -> GetInsertionPoint;
    $this->{feedback}->AppendText($text);
    $this->{feedback}->SetStyle($was, $this->{feedback} -> GetInsertionPoint, $color);
  };
};

sub sanity_path_too_long {
  my ($this, @paths) = @_;
  if (any {$_->R > 2.5} @paths) {
    return "Some paths are longer than 2.5A.  Bond valence sums are only valid on paths in the first coordination shell.";
  };
  return q{};
};

sub sanity_paths_split_shells {
  my ($this, @paths) = @_;
  return q{} if $#paths < 1;
  my $stat = Statistics::Descriptive::Full->new();
  foreach my $p (@paths) {
    $stat->add_data($p->R);
  };
  if ($stat->standard_deviation > 0.2) {
    return "The standard deviation of your paths is larger than 0.2A.  A bond valence sum should only include paths in the first coordination shell.";
  };
  return q{};
};

sub sanity_ms_paths {
  my ($this, @paths) = @_;
  if (any {$_->nleg > 2} @paths) {
    return "Some paths are multiple scattering paths.  Bond valence sums should use only single scattering paths.";
  };
  return q{};
};

1;


=head1 NAME

Demeter::UI::Artemis::Data::BondValence - Dialog to perform a simple bond valence sum calculation

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a dialog for computing a bond valence sum using a
set of marked paths and table of bond valence parameters maintained by
I. David Brown of McMaster University.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

The tabulation of bond valence parameters carried the following
copyright notice and disclaimer:

  #***************************************************************
  # COPYRIGHT NOTICE
  # This table may be used and distributed without fee for
  # non-profit purposes providing
  # 1) that this copyright notice is included and
  # 2) no fee is charged for the table and
  # 3) details any changes made in this list by anyone other than
  # the copyright owner are suitably noted in the _audit_update record
  # Please consult the copyright owner regarding any other uses.
  #
  # The copyright is owned by I. David Brown, Brockhouse Institute for
  # Materials Research, McMaster University, Hamilton, Ontario Canada.
  # idbrown@mcmaster.ca
  #
  #*****************************DISCLAIMER************************
  #
  # The values reported here are taken from the literature and
  # other sources and the author does not warrant their correctness
  # nor accept any responsibility for errors.  Users are advised to
  # consult the primary sources.
  #
  #***************************************************************



=cut
