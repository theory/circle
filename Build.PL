use strict;
use warnings;
use Module::Build::DB;

Module::Build::DB->new(
    module_name        => 'App::Circle',
    license            => 'perl',
    script_files       => 'bin',
    test_file_exts     => [qw(.t .pg)],
    db_config_key      => 'dbi',
    db_client          => 'psql',
    test_env           => { PGOPTIONS => '--search_path=tap,public,contrib' },
    configure_requires => {
        'Module::Build::DB' => '0.10',
    },
    build_requires     => {
        'Module::Build::DB' => '0.10',
        'Test::MockModule'  => '0.05',
        'Test::More'        => '0.70',
    },
    requires           => {
        'aliased'                           => '0.30',
        'Catalyst::Action::RenderView'      => '0.11',
        'Catalyst::Devel'                   => '1.2',
        'Catalyst::Plugin::ConfigLoader'    => '0.27',
        'Catalyst::Plugin::StackTrace'      => '0.10',
        'Catalyst::Plugin::Static::Simple'  => '0.22',
        'Catalyst::Plugin::Unicode'         => '0.91',
        'Catalyst::Runtime'                 => '5.80011',
        'Class::XSAccessor'                 => '1.03',
        'DBD::Pg'                           => '2.15.1',
        'DBI'                               => '1.608',
        'DBIx::Connector'                   => '0.20',
        'Encode'                            => '2.12',
        'Encode::Detect::Detector'          => '1.01',
        'Exception::Class::DBI'             => '1.00',
        'File::Spec'                        => 0,
        'Getopt::Long'                      => '2.34',
        'perl'                              => 5.010,
        'Pod::Usage'                        => '1.36',
        'POE::Component::IRC::State'        => '6.12',
        'Unicode::Normalize'                => '1.03',
        'YAML::Syck'                        => '1.07',
    },
    recommends         => {
        'POE::Component::SSLify' => '0.15',
        'Test::Pod'              => '1.20',
        'Test::Pod::Coverage'    => '1.06',
    },
    meta_merge         => {
        resources => {
            homepage    => 'http://search.cpan.org/dist/Circle/',
            bugtracker  => 'http://github.com/theory/circle/issues/',
            repository  => 'http://github.com/theory/circle/tree/',
        }
    },
)->create_build_script;
