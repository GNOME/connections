/* rdp-preferences-window.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/rdp-preferences.ui")]
    private class RdpPreferencesWindow : Connections.PreferencesWindow {
        [GtkChild]
        private unowned Gtk.Entry connection_name_entry;
        [GtkChild]
        private unowned Gtk.Label host_address_label;
        [GtkChild]
        private unowned BooleanProperty scaling;

        public RdpPreferencesWindow (Connection connection) {
            this.connection = connection;

            bind_widget_property (connection_name_entry, "text", "display_name");
            bind_widget_property (host_address_label, "label", "uri");
            bind_widget_property (scaling, "active", "scaling");
        }
    }
}
