#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;

use Test::More;
use Data::Dumper;
require File::Temp;
require File::Compare;

use above 'Genome';


ok(init(), 'succesfully completed init');
ok(test_dependent_cron_ref_align(), 'successfully completed test_dependent_cron_ref_align');
ok(test_execute_build(), 'successfully completed test_execute_build');
done_testing();


sub init {
    ok($ENV{UR_DBI_NO_COMMIT} = 1, 'UR_DBI_NO_COMMIT is enabled') or die;
    ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1, 'UR_USE_DUMMY_AUTOGENERATED_IDS is enabled') or die;

    use_ok('Genome::Model::GenotypeMicroarray') or die;

    return 1;
}


sub test_dependent_cron_ref_align {
    # test_dependent_cron_ref_align_init creates several models, see sub for more details
    ok(test_dependent_cron_ref_align_init(), 'successfully completed test_dependent_cron_ref_align_init') or return;

    my $gm_m = Genome::Model::GenotypeMicroarray->get(name => 'Test Genotype Microarray');
    isa_ok($gm_m, 'Genome::Model::GenotypeMicroarray', 'gm_m') or return;

    my @dependent_cron_ref_align = $gm_m->dependent_cron_ref_align;
    my %names = map {$_->name, 1} @dependent_cron_ref_align;
    is(scalar keys %names, 2, 'got two models from dependent_cron_ref_align') or return;
    ok(exists $names{'Another Test Build 36 Reference Alignment'}, 'other model was "Another Test Build 36 Reference Alignment"') or return;
    ok(exists $names{'Test Build 36 Reference Alignment'}, 'one model was "Test Build 36 Reference Alignment"') or return;

    return 1;
}


sub test_dependent_cron_ref_align_init {
    # this create several models needed to test the expected behavior of dependent_cron_ref_align
    # build 36 ref align and build 36 genotype - just as prep work
    # build 37 ref align - for testing compatible reference_sequence_build
    # build 36 ref align with alternate genotype_microarray_model and  alternate build 36 genotype - for testing existing genotype_microarray_model input

    my $ra_pp = Genome::ProcessingProfile::ReferenceAlignment->create(
        name => 'Test Reference Alignment Processing Profile',
        sequencing_platform => 'solexa',
        dna_type => 'genomic dna',
        read_aligner_name => 'bwa',
    );
    isa_ok($ra_pp, 'Genome::ProcessingProfile::ReferenceAlignment', 'ra_pp') or return;

    # only getting this real thing because the class is preventing me from creating one due to valid values
    my $gm_pp = Genome::ProcessingProfile::GenotypeMicroarray->get(name => 'infinium wugc');
    isa_ok($gm_pp, 'Genome::ProcessingProfile::GenotypeMicroarray', 'gm_pp') or return;

    my $individual = Genome::Individual->create(name => 'Test Individual');
    isa_ok($individual, 'Genome::Individual', 'created individual') or return;

    my $subject = Genome::Sample->create(name => 'Test Sample');
    isa_ok($subject, 'Genome::Sample', 'subject') or return;

    my $other_subject = Genome::Sample->create(name => 'Another Test Sample');
    isa_ok($other_subject, 'Genome::Sample', 'another test subject created') or return;

    my $library = Genome::Library->create(name => 'Test Sample Library', sample_id => $subject->id);
    isa_ok($library, 'Genome::Library', 'library') or return;

    my $other_library = Genome::Library->create(name => 'Another Test Library', sample_id => $other_subject->id);
    isa_ok($other_library, 'Genome::Library', 'other library') or return;

    my $genotype_data = Genome::InstrumentData::Imported->create(
        library => $library,
        import_format => 'genotype file',
        sequencing_platform => 'infinium',
    );
    isa_ok($genotype_data, 'Genome::InstrumentData::Imported', 'genotype data') or return;

    $other_subject->default_genotype_data($genotype_data);

    my $build_36 = Genome::Model::Build::ReferenceSequence->get(name => 'NCBI-human-build36');
    isa_ok($build_36, 'Genome::Model::Build::ReferenceSequence', 'build_36') or return;

    my $build_37 = Genome::Model::Build::ReferenceSequence->get(name => 'GRCh37-lite-build37');
    isa_ok($build_37, 'Genome::Model::Build::ReferenceSequence', 'build_37') or return;

    my $gm_m = Genome::Model::GenotypeMicroarray->create(
        name => 'Test Genotype Microarray',
        processing_profile => $gm_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
        instrument_data => [$genotype_data],
    );
    isa_ok($gm_m, 'Genome::Model::GenotypeMicroarray', 'gm_m') or return;

    my $alt_gm_m = Genome::Model::GenotypeMicroarray->create(
        name => 'Test Alternate Genotype Microarray',
        processing_profile => $gm_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
    );
    isa_ok($alt_gm_m, 'Genome::Model::GenotypeMicroarray', 'alt_gm_m') or return;

    my $build_36_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 36 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_36_ref_align, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align') or return;

    my $other_build_36_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Another Test Build 36 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $other_subject->id,
        subject_class_name => $other_subject->class,
        reference_sequence_build => $build_36,
        auto_assign_inst_data => 1,
    );
    isa_ok($other_build_36_ref_align, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align') or return;
    $other_build_36_ref_align->genotype_microarray_model(undef);

    my $build_36_ref_align_with_existing_gm_model = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 36 Reference Alignment with Genotype Microarray Model',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
        genotype_microarray_model => $alt_gm_m,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_36_ref_align_with_existing_gm_model, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align_with_existing_gm_model') or return;

    my $build_37_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 37 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_37,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_37_ref_align, 'Genome::Model::ReferenceAlignment', 'build_37_ref_align') or return;

    return 1;
}


sub test_execute_build {
    my $testdir = $ENV{GENOME_TEST_INPUTS} . '/GenotypeMicroarray';

    # ref
    my %pos_seq = (
        752566 => 'G',
        752721 => 'A',
        798959 => 'G',
        800007 => 'T',
        838555 => 'C',
        846808 => 'C',
        854250 => 'A',
        861808 => 'A',
        861810 => 'T',
        873558 => 'G',
        882033 => 'G',
    );
    #my $build_37 = Genome::Model::Build::ReferenceSequence->get(name => 'GRCh37-lite-build37');
    my $build_37 = Genome::Model::Build::ReferenceSequence->__define__(
        name => '__TEST_REF__',
    );
    no warnings;
    *Genome::Model::Build::ReferenceSequence::sequence = sub{ return $pos_seq{$_[2]}; };
    *Genome::Model::Build::ReferenceSequence::chromosome_array_ref = sub{ return [qw/ 1 /]; };
    use warnings;
    ok($build_37, 'get build_37') or return;

    # dbsnp
    my $dbsnp_file = $testdir.'/dbsnp/dbsnp.132';
    my $fl = Genome::Model::Tools::DetectVariants2::Result::Manual->__define__(
        description => '__TEST__DBSNP132__',
        username => 'apipe-tester',
        file_content_hash => 'c746fb7b7a88712d27cf71f8262dd6e8',
        output_dir => $testdir.'/dbsnp',
    );
    $fl->lookup_hash($fl->calculate_lookup_hash());
    ok($fl, 'create dv2 result');
    my $variation_list_build = Genome::Model::Build::ImportedVariationList->__define__(
        model => Genome::Model->get(2868377411),
        reference => $build_37,
        snv_result => $fl,
        version => 132,
    );
    ok($variation_list_build, 'create variation list build');

    my $sample = Genome::Sample->__define__(
        id => -8888,
        name => '__TEST__SAMPLE__',
    );
    ok($sample, 'create sample');
    my $library = Genome::Library->__define__(
        name => $sample->name.'-microarraylib',
        sample => $sample,
    );
    ok($library, 'create library');
    my $instrument_data = Genome::InstrumentData::Imported->__define__(
        id => -7777,
        library => $library,
        import_format => 'genotype file',
        sequencing_platform => 'infinium',
    );
    ok($instrument_data, 'create instrument data');
    ok(
        $instrument_data->add_attribute(attribute_label => 'genotype_file', attribute_value => $testdir.'/instdata/snpreport/-7777'),
        'add attr to inst data for genotype file',
    );
    $sample->default_genotype_data_id($instrument_data->id);

    no warnings;
    *Genome::FeatureList::file_path = sub{ return $dbsnp_file };
    use warnings;

    my $pp = Genome::ProcessingProfile::GenotypeMicroarray->get(name => 'infinium wugc');
    ok($pp, 'get genotype microarray pp') or return;

    my $model = Genome::Model::GenotypeMicroarray->create(
        name => 'Test Genotype Microarray pp',
        processing_profile => $pp,
        subject_id => $sample->id,
        subject_class_name => $sample->class,
        reference_sequence_build => $build_37,
        dbsnp_build => $variation_list_build,
    );
    ok($model, 'create genotype microarray model') or return;

    my $example_build = Genome::Model::Build::GenotypeMicroarray->__define__(
        model => $model,
        data_directory => $testdir.'/build',
    );
    ok($example_build, 'define example genotype microarray build');

    my $tempdir = File::Temp::tempdir(CLEANUP => 1);
    my $build = Genome::Model::Build::GenotypeMicroarray->create(
        model => $model,
        data_directory => $tempdir,
    );
    ok($build, 'create genotype microarray build');

    ok(!Genome::Model::GenotypeMicroarray->_execute_build($build), 'execute build failed w/ inst data');

    $model->add_instrument_data($instrument_data);
    $build->add_instrument_data($instrument_data);
    ok(Genome::Model::GenotypeMicroarray->_execute_build($build), 'execute build');
    ok($model->dbsnp_build, 'set dbsnp build on model');
    ok($build->dbsnp_build, 'set dbsnp build on build');

    my $original_genotype_file = $build->original_genotype_file_path;
    is($original_genotype_file, $tempdir.'/'.$sample->id.'.original', 'oringinal genotype file name');
    is(File::Compare::compare($original_genotype_file, $example_build->original_genotype_file_path), 0, 'oringinal genotype file matches');

    my $genotype_file = $build->genotype_file_path;
    is($genotype_file, $tempdir.'/'.$sample->id.'.genotype', 'genotype file name');
    is(File::Compare::compare($genotype_file, $example_build->genotype_file_path), 0, 'genotype file matches');
    is(File::Compare::compare($build->formatted_genotype_file_path, $example_build->formatted_genotype_file_path), 0, 'formatted genotype file matches');

    my $gold2geno_file = $build->gold2geno_file_path;
    is($gold2geno_file, $build->data_directory.'/formatted_genotype_file_path.genotype.gold2geno', 'gold2geno file name');
    is(File::Compare::compare($gold2geno_file, $example_build->gold2geno_file_path), 0, 'gold2geno file matches');

    my $copy_number_file = $build->copy_number_file_path;
    is($copy_number_file, $build->data_directory.'/-8888.copynumber', 'copy number file name');
    is(File::Compare::compare($copy_number_file, $example_build->copy_number_file_path), 0, 'copy number file matches');

    my $snvs_bed = $build->snvs_bed;
    is($snvs_bed, $build->data_directory.'/gold_snp.v2.bed', 'snvs bed name');
    is(File::Compare::compare($snvs_bed, $testdir.'/build/gold_snp.v2.bed'), 0, 'snvs bed file matches');

    return 1;
}
