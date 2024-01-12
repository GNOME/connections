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
    private class Assistant : Gtk.Popover {
        [GtkChild]
        private unowned Gtk.Entry url_entry;
        [GtkChild]
        private unowned Gtk.Button create_button; 
        [GtkChild]
        private unowned Gtk.CheckButton rdp_radio_button;
        [GtkChild]
        private unowned Gtk.CheckButton vnc_radio_button;

        private bool uri_has_supported_scheme (string uri) {
            return uri.has_prefix ("rdp://") || uri.has_prefix ("vnc://");
        }

        [GtkCallback]
        private void on_url_entry_changed () {
            if (url_entry.text == "") {
                create_button.sensitive = false;

                return;
            }

            var address = url_entry.text;
            if (!uri_has_supported_scheme (address)) {
                if (rdp_radio_button.get_active ())
                    address = "rdp://" + address;
                else
                    address = "vnc://" + address;
            }

            debug ("Attempting to add \"%s\"", address);
            var uri = Xml.URI.parse (address);
            if (uri == null) {
                create_button.sensitive = false;

                debug ("Address \"%s\" is invalid", address);

                return;
            }

            rdp_radio_button.set_active (uri.scheme == "rdp");
            vnc_radio_button.set_active (uri.scheme == "vnc");

            create_button.sensitive = uri.server != null;
        }

        [GtkCallback]
        private void on_create_connection_button_clicked () {
            var uri = url_entry.get_text ();

            // Prefixes the uri string with the selected protocol (when protocol isn't explicit)
            if (!uri_has_supported_scheme (uri)) {
                var scheme = rdp_radio_button.get_active () ? "rdp://" : "vnc://";
                uri = scheme + uri;
            }

            Application.application.add_connection (uri);

            url_entry.set_text ("");
            popdown ();
        }

        [GtkCallback]
        private void on_url_entry_activated () {
            if (create_button.sensitive)
                create_button.clicked ();
        }

        [GtkCallback]
        private void on_help_button_clicked () {
/*
            try {
                Gtk.show_uri_on_window (Application.application.main_window,
                                        "help:gnome-connections/connect",
                                        Gtk.get_current_event_time ());
            } catch (GLib.Error error) {
                warning ("Failed to display help: %s", error.message);
            }
*/
        }
    }
}
