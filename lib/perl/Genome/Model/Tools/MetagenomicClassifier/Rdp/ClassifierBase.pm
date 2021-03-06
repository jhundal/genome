package Genome::Model::Tools::MetagenomicClassifier::Rdp::ClassifierBase;

use strict;
use warnings;

use Genome;

use Genome::InlineConfig;
use Genome::Model::Tools::MetagenomicClassifier::Rdp::TrainingSet;

class Genome::Model::Tools::MetagenomicClassifier::Rdp::ClassifierBase {
    is_abstract => 1,
    has => [
        training_set => {
            is => 'Text',
            valid_values => [ Genome::Model::Tools::MetagenomicClassifier::Rdp::TrainingSet->valid_set_names ],
            doc => 'Training set to use.'
        },
    ],
    has_optional => [
        _factory => { is_transient => 1, },
        _classifier => { is_transient => 1, },
    ],
};

$ENV{PERL_INLINE_JAVA_JNI} = 1;

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $training_path = eval{ Genome::Model::Tools::MetagenomicClassifier::Rdp::TrainingSet->path_for_set_name(
            $self->training_set
        );
    };
    if ( not $training_path ) {
        $self->error_message($@);
        return;
    }

    my $training_set = Genome::Model::Tools::MetagenomicClassifier::Rdp::TrainingSet->create(
        path => $training_path,
    );
    return if not $training_set;

    my $factory = new FactoryInstance($training_set->classifier_properties_path);
    $self->_factory($factory);
    $self->_classifier( $factory->createClassifier );

    return $self;
}

sub new {
    my $class = shift;
    warn "Called method 'new' instantiate $class, but it is deprecated. Please use 'create.'";
    return $class->create(@_);
}

sub classify {
    my ($self, $seq) = @_;

    return if not $self->verify_seq($seq);

    my $parsed_seq = eval{ $self->create_classifier_sequence($seq); };
    if ( not $parsed_seq ) {
        $self->error_message("Can't classify sequence (".$seq->{id}."). Can't create rdp parsed sequence.");
        return;
    }

    # Try to classify 2X - per kathie 2009mar3
    my $classification_result = eval{ $self->_classifier->classify($parsed_seq); };
    if ( not $classification_result ) {
        $classification_result = eval{ $self->_classifier->classify($parsed_seq); };
        if ( not $classification_result ) {
            $self->error_message("Can't classify sequence (".$seq->{seq}."). No classification result was returned from the classifier.");
            return;
        }
    }

    my $complemented = $self->_is_reversed(
        parsed_seq => $parsed_seq,
        classification_result => $classification_result,
    );

    my @assignments = @{$classification_result->getAssignments()->toArray()};
    my %taxa = (
        id => $seq->{id},
        complemented => $complemented,
        classifier => 'rdp',
        root => {
            id => 'Root',
            confidence => $assignments[0]->getConfidence,
        },
    );
    for my $assignment ( @assignments[1..$#assignments] ) {
        # print Dumper([map{ $_->getName } @{$assignment->getClass->getMethods}]);
        # Methods are: getConfidence, getTaxid, getName, getRank	
        my $id = $assignment->getName;
        $id =~ s/\s+/_/g;
        $id =~ s/['"]//g;
        $taxa{ $assignment->getRank || 'root' } = {
            id => $id,
            confidence => $assignment->getConfidence,
        };
    }

    return \%taxa;
}

sub create_classifier_sequence {
    return new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($_[1]->{id}, $_[1]->{seq});
}

sub verify_seq {
    my ($self, $seq) = @_;

    if ( not $seq ) {
        Carp::confess("No sequence given to classify");
    }

    if ( not $seq->{id} ) {
        Carp::confess('Seq does not have an id: '.Data::Dumper::Dumper($seq));
    }

    if ( not $seq->{seq} or length $seq->{seq} < 50) {
        return;
    }

    return 1;
}

1;

