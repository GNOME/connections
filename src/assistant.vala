/* assistant.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/assistant.ui")]
    private class Assistant : Gtk.Dialog {
        [GtkChild]
        private Gtk.Entry url_entry;
        [GtkChild]
        private Gtk.Button create_button; 

        construct {
            use_header_bar = 1;
        }

        public Assistant (Window window, string? uri = null) {
            set_transient_for (window);

            create_button.get_style_context ().add_class ("suggested-action");

            url_entry.grab_focus ();

            if (uri != null)
                url_entry.text = uri;
        }

        [GtkCallback]
        private void on_url_entry_changed () {
            if (url_entry.text == "") {
                create_button.sensitive = false;

                return;
            }

            var uri = Xml.URI.parse (url_entry.text);
            if (uri == null || uri.scheme == null) {
                create_button.sensitive = false;

                return;
            }

            if (uri.scheme == "vnc" || uri.scheme == "rdp") {
                create_button.sensitive = true;
            }
        }

        [GtkCallback]
        private void on_create_connection_button_clicked () {
            Application.application.add_connection (url_entry.get_text ());

            destroy ();
        }

        [GtkCallback]
        private void on_url_entry_activated () {
            if (create_button.sensitive)
                create_button.clicked ();
        }
    }
}
