desktop_conf = configuration_data()
desktop_conf.set('icon', application_id)
desktop_file = i18n.merge_file(
  input: configure_file(
    input: files('org.gnome.Connections.desktop.in'),
    output: 'org.gnome.Connections.desktop.in',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(application_id),
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

appstream_conf = configuration_data()
appstream_conf.set('app-id', application_id)
appstream_file = i18n.merge_file(
  input: configure_file(
    input: 'org.gnome.Connections.metainfo.xml.in',
    output: 'org.gnome.Connections.metainfo.xml.in',
    configuration: appstream_conf
  ),
  output: '@0@.metainfo.xml'.format(application_id),
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('Validate appstream file', appstreamcli,
    args: ['validate', '--no-net', '--explain', appstream_file]
  )
endif

dbus_conf = configuration_data()
dbus_conf.set('bindir', join_paths (get_option ('prefix'), get_option ('bindir')))
dbus_conf.set('appid', application_id)
configure_file(
  input: 'org.gnome.Connections.service.in',
  output: '@0@.service'.format(application_id),
  configuration: dbus_conf,
  install: true,
  install_dir: join_paths (get_option('datadir'), 'dbus-1', 'services')
)

# Icons
icon_dir = join_paths('icons', 'hicolor', 'scalable', 'apps')
install_data(
  join_paths(icon_dir, '@0@.svg'.format(application_id)),
  install_dir: join_paths(get_option('datadir'), icon_dir),
  rename: '@0@.svg'.format(application_id)
)

icon_dir = join_paths('icons', 'hicolor', 'symbolic', 'apps')
install_data(
  join_paths(icon_dir, 'org.gnome.Connections-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), icon_dir),
  rename: '@0@-symbolic.svg'.format(application_id)
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
