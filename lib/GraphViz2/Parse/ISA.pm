package GraphViz2::Parse::ISA;

use strict;
use warnings;
use warnings  qw(FATAL utf8); # Fatalize encoding glitches.

our $VERSION = '2.52';

use Algorithm::Dependency;
use Algorithm::Dependency::Source::HoA;
use Class::ISA;
use Class::Load 'try_load_class';
use GraphViz2;
use Moo;
use Tree::DAG_Node;

has graph => (
	default  => sub {
		GraphViz2->new(
			edge   => {color => 'grey'},
			global => {directed => 1},
			graph  => {rankdir => 'BT'},
			node   => {color => 'blue', shape => 'Mrecord'},
		)
        },
	is       => 'rw',
	#isa     => 'GraphViz2',
	required => 0,
);

has is_a => (
	default  => sub{return {} },
	is       => 'ro',
	#isa     => 'HashRef',
	required => 0,
);

sub add {
	my ($self, %arg) = @_;
	my $class = delete $arg{class}  || die 'Error. No class name specified';
	my $ignore = delete $arg{ignore} || [];
	die "Error. The class parameter must not be a ref\n" if ref $class;
	die "Error. The ignore parameter's value must be an arrayref\n" if ref $ignore ne 'ARRAY';
	die "Error: Unable to load class '$class'\n" if !try_load_class $class;
	my $tree = Tree::DAG_Node->new;
	_process_is_a($tree, $class, +{ map +($_=>1), @$ignore });
	_simplify($tree);
	_build_dependency($tree, $self->is_a);
	return $self;
}

sub _build_dependency {
	my ($tree, $is_a) = @_;
	$$is_a{$tree->name} = [map $_->name, my @daughters = $tree->daughters];
	_build_dependency($_, $is_a) for @daughters;
}

sub _process_is_a {
	my($tree, $class, $ignore) = @_;
	$tree->name($class);
	_process_is_a($tree->new_daughter, $_, $ignore)
		for grep !$$ignore{$_}, Class::ISA::super_path($class);
}

sub _simplify {
	my ($tree) = @_;
	my @delenda;
	for my $node ($tree->daughters) {
		my $node_name = $node->name;
		push @delenda, $node if grep $node_name eq $_->name,
			map $_->daughters, $node->sisters;
	}
	$tree->remove_daughters(@delenda);
	_simplify($_) for $tree->daughters;
}

sub generate_graph {
	my($self) = @_;
	my $data = Algorithm::Dependency->new(source => Algorithm::Dependency::Source::HoA->new($self->is_a));
	die 'Error: No dependency data provided' if !$data;
	my $g = $self->graph;
	my @items = sort {$a->[0] cmp $b->[0]} map [$_->id, $_->depends], $data->source->items;
	for my $item (@items) {
		my ($id, @depends) = @$item;
		$g->add_node(name => $id);
		$g->add_edge(from => $id, to => $_) for @depends;
	}
}

1;

=pod

=head1 NAME

L<GraphViz2::Parse::ISA> - Visualize N Perl class hierarchies as a graph

=head1 SYNOPSIS

	use strict;
	use warnings;
	use File::Spec;
	use GraphViz2::Parse::ISA;

	my $parser = GraphViz2::Parse::ISA->new;
	unshift @INC, 't/lib';
	$parser->add(class => 'Adult::Child::Grandchild', ignore => []);
	$parser->add(class => 'HybridVariety', ignore => []);
	$parser->generate_graph;

	my $format      = shift || 'svg';
	my $output_file = shift || "parse.code.$format";

	$parser->graph->run(format => $format, output_file => $output_file);

See scripts/parse.isa.pl.

=head1 DESCRIPTION

Takes a class name and converts its class hierarchy into a graph. This can be done for N different classes before the graph is generated.

You can write the result in any format supported by L<Graphviz|http://www.graphviz.org/>.

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = GraphViz2::Parse::ISA->new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<GraphViz2::Parse::ISA>.

Key-value pairs accepted in the parameter list:

=over 4

=item o graph => $graphviz_object

This option specifies the GraphViz2 object to use. This allows you to configure it as desired.

The default is GraphViz2->new. The default attributes are the same as
in the synopsis, above.
The default for L<GraphViz2::Parse::ISA> is to plot from the bottom to
the top (Grandchild to Parent).  This is the opposite of L<GraphViz2>.

This key is optional.

=back

=head1 METHODS

=head2 add(class => $class[, ignore => $ignore])

Adds the class hierarchy of $class to an internal structure.

$class is the name of the class whose parents are to be found.

$ignore is an optional arrayref of class names to ignore. The value of $ignore is I<not> preserved between calls to add().

After all desired calls to add(), you I<must> call L</generate_graph()> to actually trigger the call to the L<GraphViz2> methods add_node() and add_edge().

Returns $self for method chaining.

See scripts/parse.isa.pl.

=head2 generate_graph()

Processes the internal structure mentioned under add() to add all the nodes and edges to the graph.

After that you call L<GraphViz2>'s run() method on the graph object. See L</graph()>.

Returns $self for method chaining.

See scripts/parse.isa.pl.

=head2 graph()

Returns the graph object, either the one supplied to new() or the one created during the call to new().

=head1 Scripts Shipped with this Module

=head2 scripts/parse.isa.pl

Demonstrates combining 2 Perl class hierarchies on the same graph.

Outputs to ./html/parse.isa.svg by default. Change this by providing a
format argument (e.g. C<svg>) and a filename argument.

=head1 THANKS

Many thanks are due to the people who chose to make L<Graphviz|http://www.graphviz.org/> Open Source.

And thanks to L<Leon Brocard|http://search.cpan.org/~lbrocard/>, who wrote L<GraphViz>, and kindly gave me co-maint of the module.

The code in add() was adapted from L<GraphViz::ISA::Multi> by Marcus Thiesen, but that code gobbled up package declarations
in comments and POD, so I used L<Pod::Simple> to give me just the source code.

=head1 AUTHOR

L<GraphViz2> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2011.

Home page: L<http://savage.net.au/index.html>.

=head1 COPYRIGHT

Australian copyright (c) 2011, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Perl License, a copy of which is available at:
	http://dev.perl.org/licenses/

=cut
