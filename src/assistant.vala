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
    public class Assistant : Gtk.Dialog {
        [GtkChild]
        private Gtk.Entry url_entry;

        construct {
            use_header_bar = 1;
        }

        public Assistant (Window window) {
            set_transient_for (window);
        }

        [GtkCallback]
        private void on_create_machine_button_clicked () {
            try {
                var machine = new Connections.Machine () {
                    uri = url_entry.get_text ()
                };

                Application.application.add_machine (machine);
            } catch (GLib.Error error) {
                warning ("Failed to add machine %s: %s", url_entry.get_text (), error.message);
            }

            destroy ();
        }
    }
}
