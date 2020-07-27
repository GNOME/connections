desktop_file = i18n.merge_file(
  input: 'org.gnome.Connections.desktop.in',
  output: 'org.gnome.Connections.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

appstream_file = i18n.merge_file(
  input: 'org.gnome.Connections.appdata.xml.in',
  output: 'org.gnome.Connections.appdata.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'appdata')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util,
    args: ['validate', appstream_file]
  )
endif

dbus_conf = configuration_data ()
dbus_conf.set ('bindir', join_paths (get_option ('prefix'), get_option ('bindir')))
configure_file (
  input: 'org.gnome.Connections.service.in',
  output: 'org.gnome.Connections.service',
  configuration: dbus_conf,
  install: true,
  install_dir: join_paths (get_option('datadir'), 'dbus-1', 'services')
)

# Icons
install_subdir('icons',
  install_dir: join_paths(get_option('datadir')),
)

install_data('org.gnome.Connections.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

install_data('org.gnome.Connections.xml',
  install_dir: join_paths(get_option('datadir'), 'mime', 'packages')
)
