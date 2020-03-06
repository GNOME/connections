project('connections', ['c', 'vala'], 
          version: '0.1.0',
    meson_version: '>= 0.50.0',
  default_options: [ 'warning_level=2',
                   ],
)

i18n = import('i18n')
valac = meson.get_compiler ('vala')


src_dir = join_paths (meson.source_root (), 'src')
locale_dir = join_paths (get_option ('prefix'), get_option ('localedir'))

conf = configuration_data ()
conf.set_quoted ('GETTEXT_PACKAGE', meson.project_name ())
conf.set_quoted ('LOCALEDIR', locale_dir)

config_h = declare_dependency (
    input: configure_file (
        output: 'config.h.in',
        configuration: conf
    ),
    output: 'config.h'
)

configure_file (output: 'config.h', configuration: conf)
config_h_dir = include_directories ('.')

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('build-aux/meson/postinstall.py')
