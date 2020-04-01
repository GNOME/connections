/* properties.vala
 *
 * Copyright (C) Red Hat, Inc
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: Felipe Borges <felipeborges@gnome.org>
 *
 */

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/properties.ui")]
    private class PropertiesDialog : Gtk.Dialog {
        private GLib.ListStore model = new GLib.ListStore (typeof (Property));
        [GtkChild]
        private Gtk.ListBox listbox;

        protected weak Connection connection;

        construct {
            use_header_bar = 1;

            listbox.bind_model (model, create_entry);
            listbox.set_header_func (use_listbox_separator);

            set_transient_for (Application.application.main_window);
        }

        public void add_property (Connections.Property property) {
            assert (property is Connections.Property);
            model.append (property);
        }

        private Gtk.Widget create_entry (Object item) {
            var property = item as Property;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 20) {
                border_width = 10
            };

            var label = new Gtk.Label (property.label) {
                halign = Gtk.Align.START,
                hexpand = true
            };
            box.pack_start (label);

            box.pack_end (property.widget);
            property.widget.halign = Gtk.Align.END;
            box.show_all ();

            return box;
        }

        private void use_listbox_separator (Gtk.ListBoxRow row, Gtk.ListBoxRow? before_row) {
            if (before_row == null) {
                row.set_header (null);

                return;
            }

            var current = row.get_header ();
            if (current == null) {
                current = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
                    visible = true
                };

                row.set_header (current);
            }
        }
    }

     private class Property : GLib.Object {
        public string label;
        public Gtk.Widget widget;
    }
}
