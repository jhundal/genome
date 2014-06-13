#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use Sub::Install qw(reinstall_sub);
use above 'Genome';
use Genome::Utility::Test qw(compare_ok);
use Genome::VariantReporting::TestHelpers qw(
    get_test_somatic_variation_build
    test_dag_xml
    test_dag_execute
    get_test_dir
);
use Genome::VariantReporting::Plan::TestHelpers qw(
    set_what_interpreter_x_requires
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

my $pkg = 'Genome::VariantReporting::Expert::Vep::Expert';
use_ok($pkg) || die;

my $VERSION = 5; # Bump these each time test data changes
my $BUILD_VERSION = 2;
my $test_dir = get_test_dir($pkg, $VERSION);

my $expert = $pkg->create();
my $dag = $expert->dag();
my $expected_xml = File::Spec->join($test_dir, 'expected.xml');
test_dag_xml($dag, $expected_xml);

set_what_interpreter_x_requires('vep');
my $variant_type = 'snvs';
my $expected_vcf = File::Spec->join($test_dir, "expected_$variant_type.vcf.gz");
my $build = get_test_somatic_variation_build(version => $BUILD_VERSION);

my $feature_list_cmd = Genome::FeatureList::Command::Create->create(
    reference => $build->reference_sequence_build,
    file_path => File::Spec->join($test_dir, "feature_list.bed"),
    format => "true-BED",
    content_type => "roi",
    name => "test",
);
my $feature_list = $feature_list_cmd->execute;

reinstall_sub({
    into => "Genome::Model::Build::ReferenceSequence",
    as => "self_chain",
    code => sub {return $feature_list},
});

my $plan = Genome::VariantReporting::Plan->create_from_file(
    File::Spec->join($test_dir, 'plan.yaml'),
);
$plan->validate();
test_dag_execute($dag, $expected_vcf, $variant_type, $build, $plan);
done_testing();
