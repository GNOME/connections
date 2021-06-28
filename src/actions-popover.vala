/* actions-popover.vala
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
    private class ActionsPopover : Gtk.Popover {
        private GLib.SimpleActionGroup action_group;
        private const GLib.ActionEntry[] action_entries = {
            {"delete", delete_activated},
            {"properties", properties_activated}
        };

        private Connections.Connection connection;

        construct {
            action_group = new GLib.SimpleActionGroup ();
            action_group.add_action_entries (action_entries, this);
            this.insert_action_group ("connection", action_group);
        }

        public void update_for_item (Connection connection) {
            this.connection = connection;

            var menu = new GLib.Menu ();

            var action = action_group.lookup_action ("delete") as GLib.SimpleAction;
            menu.append (_("Delete"), "connection.delete");
            action.set_enabled (true);

            action = action_group.lookup_action ("properties") as GLib.SimpleAction;
            menu.append (_("Properties"), "connection.properties");
            action.set_enabled (true);

            bind_model (menu, null);
        }

        private void delete_activated () {
            debug ("Deleting %s", connection.uri);

            Application.application.remove_connection (connection);
        }

        private void properties_activated () {
            debug ("Launch properties for %s", connection.uri);

            Application.application.main_window.show_preferences_window (connection);
        }
    }
}
