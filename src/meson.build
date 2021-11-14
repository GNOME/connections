connections_sources = [
  'actions-popover.vala', 
  'assistant.vala',
  'application.vala',
  'connection.vala',
  'collection-view.vala',
  'collection-view-child.vala',
  'database.vala',
  'display-view.vala',
  'main.vala',
  'notifications.vala',
  'onboarding-dialog.vala',
  'onboarding-dialog-page.vala',
  'preferences-widgets.vala',
  'rdp-connection.vala',
  'rdp-preferences-window.vala',
  'topbar.vala',
  'vnc-connection.vala',
  'vnc-preferences-window.vala',
  'window.vala',
]

cc = meson.get_compiler ('c')

connections_deps = [
  config_h,
  valac.find_library ('config', dirs: src_dir),
  cc.find_library('m'),
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gtk-vnc-2.0', version: '> 0.4.4'),
  dependency('gvncpulse-1.0'),
  dependency('libhandy-1', version: '>= 1.2.0'),
  dependency ('libxml-2.0', version: '>= 2.7.8'),
  dependency ('libsecret-1'),
]

gtk_frdp_dep = dependency('gtk-frdp-0.1', required: false)

if gtk_frdp_dep.found()
  connections_deps += gtk_frdp_dep
else
  gtk_frdp_dep = subproject('gtk-frdp', default_options: [
    'package_subdir=' + meson.project_name()
  ])

  connections_deps += gtk_frdp_dep.get_variable('gtk_frdp_vapi')
endif

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
  '--disable-since-check',
  '--target-glib=2.50',
]

executable('gnome-connections', connections_sources,
  include_directories: config_h_dir, 
  vala_args: vala_args,
  c_args: c_args,
  dependencies: connections_deps,
  install: true,
  install_rpath: join_paths (get_option ('prefix'), get_option ('libdir'), meson.project_name ())
)
