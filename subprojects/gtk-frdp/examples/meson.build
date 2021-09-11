example_application_sources = [
  'gtk-frdp-viewer.c',
]

example_application = executable('gtk-frdp-viewer', example_application_sources,
  dependencies: gtk_frdp_dep,
  install: true
)

vala_args = [
  '--vapidir', vapidir,
]

vala_example_application = executable('gtk-frdp-viewer-vala',
  'gtk-frdp-viewer.vala',
  vala_args: vala_args,
  link_with: gtk_frdp_lib,
  dependencies: [
    dependency ('gtk+-3.0'),
    gtk_frdp_vapi,
  ],
)
