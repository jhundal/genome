package Genome::VariantReporting::Suite::Joinx::HomoPolymer::Expert;

use strict;
use warnings FATAL => 'all';
use Genome;

class Genome::VariantReporting::Suite::Joinx::HomoPolymer::Expert {
    is => 'Genome::VariantReporting::Framework::Component::Expert',
};

sub name {
    'homo-polymer';
}

1;
