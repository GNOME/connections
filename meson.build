project('gnome-connections', ['c', 'vala'],
          version: '46.rc',
    meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2',
                   ],
)

i18n = import('i18n')
valac = meson.get_compiler ('vala')
gnome = import('gnome')

src_dir = join_paths (meson.source_root (), 'src')
locale_dir = join_paths (get_option ('prefix'), get_option ('localedir'))

conf = configuration_data ()
conf.set_quoted ('GETTEXT_PACKAGE', meson.project_name ())
conf.set_quoted ('LOCALEDIR', locale_dir)
conf.set_quoted ('VERSION', '@0@-@VCS_TAG@'.format (meson.project_version()))
conf.set_quoted ('PACKAGE_TARNAME', meson.project_name ())

if get_option ('profile') == 'development'
  profile = '.Devel'
else
  profile = ''
endif

application_id = 'org.gnome.Connections@0@'.format (profile)
conf.set_quoted ('PROFILE', profile)
conf.set_quoted ('APPLICATION_ID', application_id)

config_h = declare_dependency (
  sources: vcs_tag (
    command: ['git', 'rev-parse', '--short', 'HEAD'],
    fallback: '',
    input: configure_file (
      output: 'config.h.in',
      configuration: conf
    ),
    output: 'config.h'
  )
)

#configure_file (output: 'config.h', configuration: conf)
config_h_dir = include_directories ('.')

subdir('data')
subdir('help')
subdir('src')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
