import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GtkFrdp

win = Gtk.Window()

display = GtkFrdp.Display()
display.open_host("10.43.12.92", 3389)
win.add(display)

win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
