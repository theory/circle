use strict;
use warnings;
use Module::Build::DB;

Module::Build::DB->new(
    module_name        => 'App::Circle',
    license            => 'perl',
    script_files       => 'bin',
    test_file_exts     => [qw(.t .pg)],
    db_config_key      => 'dbi',
    replace_config     => 'conf/dev.yml',
    db_client          => 'psql',
    test_env           => {
        PGOPTIONS => '--search_path=tap,public',
    },
    configure_requires => {
        'Module::Build::DB' => '0.10',
    },
    build_requires     => {
        'Module::Build::DB'                 => '0.10',
        'Test::MockModule'                  => '0.05',
        'Test::More'                        => '0.70',
        'Test::Harness'                     => '3.18',
        'TAP::Parser::SourceHandler::pgTAP' => '3.23',
    },
    requires           => {
        'aliased'                           => '0.30',
        'Class::XSAccessor'                 => '1.03',
        'DBD::Pg'                           => '2.15.1',
        'DBI'                               => '1.608',
        'DBIx::Connector'                   => '0.20',
        'Module::Build::DB'                 => '0.10',
        'Encode'                            => '2.12',
        'Encode::Detect::Detector'          => '1.01',
        'Exception::Class::DBI'             => '1.00',
        'File::Spec'                        => 0,
        'Getopt::Long'                      => '2.34',
        'perl'                              => 5.010,
        'Pod::Usage'                        => '1.36',
        'POE::Component::IRC::State'        => '6.12',
        'Unicode::Normalize'                => '1.03',
        'YAML::XS'                          => '0.21',
    },
    recommends         => {
        'POE::Component::SSLify' => '0.15',
        'Test::Pod'              => '1.20',
        'Test::Pod::Coverage'    => '1.06',
    },
    tap_harness_args => {
        sources => {
            Perl  => undef,
            pgTAP => {
                dbname   => 'circle_test',
                username => 'postgres',
                suffix   => '.pg',
            },
        },
    },
    meta_merge         => {
        resources => {
            homepage    => 'http://search.cpan.org/dist/Circle/',
            bugtracker  => 'http://github.com/theory/circle/issues/',
            repository  => 'http://github.com/theory/circle/tree/',
        }
    },
)->create_build_script;
