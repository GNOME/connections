connections_sources = [
  'actions-popover.vala', 
  'assistant.vala',
  'application.vala',
  'collection-view.vala',
  'collection-view-child.vala',
  'database.vala',
  'display.vala',
  'display-view.vala',
  'empty-view.vala',
  'machine.vala',
  'main.vala',
  'notifications.vala',
  'properties.vala',
  'thumbnailer.vala',
  'topbar.vala',
  'vnc-display.vala',
  'window.vala',
]

connections_deps = [
  config_h,
  valac.find_library ('config', dirs: src_dir),
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gtk-vnc-2.0', version: '> 0.4.4'), 
  dependency ('libxml-2.0', version: '>= 2.7.8'),
]

gnome = import('gnome')

connections_sources += gnome.compile_resources('connections-resources',
  'connections.gresource.xml',
  c_name: 'connections'
)

c_args = [
    '-DGETTEXT_PACKAGE="connections"',
]

vala_args = [
  '--enable-experimental',
  '--target-glib=2.50',
]

executable('connections', connections_sources,
  include_directories: config_h_dir, 
  vala_args: vala_args,
  c_args: c_args,
  dependencies: connections_deps,
  install: true,
)
