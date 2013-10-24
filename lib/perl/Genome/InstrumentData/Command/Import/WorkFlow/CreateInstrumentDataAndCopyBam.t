#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

require Genome::Utility::Test;
require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::InstrumentData::Command::Import::WorkFlow::CreateInstrumentDataAndCopyBam') or die;

my $sample = Genome::Sample->create(name => '__TEST_SAMPLE__');
ok($sample, 'Create sample');

my $test_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import', 'bam-rg-multi/v1');
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my @bam_paths;
for my $bam_base_name (qw/ 2883581797.bam 2883581798.bam /) {
    my $bam_path = $tmp_dir.'/'.$bam_base_name;
    Genome::Sys->create_symlink($test_dir.'/'.$bam_base_name, $bam_path);
    ok(-s $bam_path, 'linked bam path') or die;
    push @bam_paths, $bam_path
}

my $source_bam = $test_dir.'/input.rg-multi.bam';
my $md5 = Genome::InstrumentData::Command::Import::WorkFlow::Helpers->load_md5($source_bam.'.md5');
ok($md5, 'load source md5');

# failures
my $cmd = Genome::InstrumentData::Command::Import::WorkFlow::CreateInstrumentDataAndCopyBam->create(
    sample => $sample,
    bam_paths => \@bam_paths,
    instrument_data_properties => { },
    source_md5s => [ $md5 ],
);
ok($cmd, "create command");
my @errors = $cmd->__errors__;
ok(@errors, "command has errors");
is($errors[0]->__display_name__, "INVALID: property 'instrument_data_properties': No original data path!", 'correct error');

# success
$cmd->instrument_data_properties(
    {
        original_data_path => $source_bam, 
        sequencing_platform => 'solexa',
        import_format => 'bam',
        lane => 2, 
        flow_cell_id => 'XXXXXX', 
    },
);
ok($cmd, "create command");
ok($cmd->execute, "execute command");

my @instrument_data_attributes = Genome::InstrumentDataAttribute->get(
    attribute_label => 'original_data_path_md5',
    attribute_value => $md5,
);
my @instrument_data = Genome::InstrumentData::Imported->get(id => [ map { $_->instrument_data_id } @instrument_data_attributes ], '-order_by' => 'import_date');
is(@instrument_data, 2, "got instrument data for md5 $md5") or die;;
my $read_group = 2883581797;
for my $instrument_data ( @instrument_data ) {
    is($instrument_data->original_data_path, $source_bam, 'original_data_path correctly set');
    is($instrument_data->import_format, 'bam', 'import_format is bam');
    is($instrument_data->sequencing_platform, 'solexa', 'sequencing_platform correctly set');
    is($instrument_data->is_paired_end, 1, 'is_paired_end correctly set');
    is($instrument_data->read_count, 128, 'read_count correctly set');
    is($instrument_data->attributes(attribute_label => 'segment_id')->attribute_value, $read_group, 'segment_id correctly set');

    my $bam_path = $instrument_data->bam_path;
    ok(-s $bam_path, 'bam path exists');
    is($bam_path, $instrument_data->data_directory.'/all_sequences.bam', 'bam path correctly named');
    is(eval{$instrument_data->attributes(attribute_label => 'bam_path')->attribute_value}, $bam_path, 'set attributes bam path');
    is(File::Compare::compare($bam_path, $test_dir.'/'.$read_group.'.bam'), 0, 'flagstat matches');
    is(File::Compare::compare($bam_path.'.flagstat', $test_dir.'/'.$read_group.'.bam.flagstat'), 0, 'flagstat matches');

    my $allocation = $instrument_data->allocations;
    ok($allocation, 'got allocation');
    ok($allocation->kilobytes_requested > 0, 'allocation kb was set');

    $read_group++;
}

# recreate
$cmd = Genome::InstrumentData::Command::Import::WorkFlow::CreateInstrumentDataAndCopyBam->create(
    sample => $sample,
    bam_paths => \@bam_paths,
    instrument_data_properties => {
        original_data_path => $source_bam, 
        sequencing_platform => 'solexa',
        import_format => 'bam',
        lane => 2, 
        flow_cell_id => 'XXXXXX', 
    },
    source_md5s => [ $md5 ],
);
ok($cmd, "create command");
ok(!$cmd->execute, "execute command");
like(Genome::InstrumentData::Command::Import::WorkFlow::Helpers->get->error_message, qr/^Instrument data was previously imported! Found existing instrument data with MD5s: /, 'correct error message');

#print $instrument_data->data_directory."\n";<STDIN>;
done_testing();
