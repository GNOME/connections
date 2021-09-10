/* topbar.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/topbar.ui")]
    private class Topbar : Gtk.Stack {
        [GtkChild]
        private unowned Hdy.HeaderBar collection_toolbar;
        [GtkChild]
        public unowned Gtk.Button search_button;
        [GtkChild]
        private unowned Gtk.HeaderBar display_toolbar;
        [GtkChild]
        public unowned Connections.Assistant assistant;

        private weak Connections.Connection connection;
        private const GLib.ActionEntry[] action_entries = {
            {"take_screenshot", take_screenshot_activated},
            {"fullscreen", fullscreen_activated},
            {"properties", properties_activated},
        };

        private const GLib.ActionEntry[] key_input_action_entries = {
            {"ctrl+alt+backspace", ctrl_alt_backspace_activated},
            {"ctrl+alt+del", ctrl_alt_del_activated},
            {"ctrl+alt+f1", ctrl_alt_fn_activated},
            {"ctrl+alt+f2", ctrl_alt_fn_activated},
            {"ctrl+alt+f3", ctrl_alt_fn_activated},
            {"ctrl+alt+f7", ctrl_alt_fn_activated},
        };

        construct {
            var action_group = new GLib.SimpleActionGroup ();
            action_group.add_action_entries (action_entries, this);
            this.insert_action_group ("display", action_group);

            var menu = new GLib.Menu ();
            var section = new GLib.Menu ();

            section.append (_("Take Screenshot"), "display.take_screenshot");
            var action = action_group.lookup_action ("take_screenshot") as GLib.SimpleAction;
            action.set_enabled (true);

            section.append (_("Fullscreen"), "display.fullscreen");
            action = action_group.lookup_action ("fullscreen") as GLib.SimpleAction;
            action.set_enabled (true);

            section.append (_("Properties"), "display.properties");
            action = action_group.lookup_action ("properties") as GLib.SimpleAction;
            action.set_enabled (true);

            var key_input_action_group = new GLib.SimpleActionGroup ();
            key_input_action_group.add_action_entries (key_input_action_entries, this);
            this.insert_action_group ("key", key_input_action_group);
        }

        private void properties_activated () {
            Application.application.main_window.show_preferences_window (connection);
        }

        private void take_screenshot_activated () {
            if (connection != null)
                connection.take_screenshot.begin ();
        }

        private void fullscreen_activated () {
            Application.application.main_window.fullscreened =
                !Application.application.main_window.fullscreened;
        }

        [GtkCallback]
        private void back_button_clicked () {
            Application.application.main_window.show_collection_view ();
            set_visible_child (collection_toolbar);
        }

        [GtkCallback]
        public void disconnect_button_clicked () {
            connection.disconnect_it ();

            back_button_clicked ();
        }

        public void show_collection_view () {
            this.connection = null;

            set_visible_child (collection_toolbar);
        }

        public void show_display_view (Connection connection) {
            this.connection = connection;

            set_visible_child (display_toolbar);

            display_toolbar.set_title (connection.get_visible_name ());
        }

        public void set_title (string title) {
            collection_toolbar.set_title (title);
        }

        private void ctrl_alt_backspace_activated () {
            uint[] keyvals = { Gdk.Key.Control_L, Gdk.Key.Alt_L, Gdk.Key.BackSpace };

            send_keys (keyvals);
        }

        private void ctrl_alt_del_activated () {
            uint[] keyvals = { Gdk.Key.Control_L, Gdk.Key.Alt_L, Gdk.Key.Delete };

            send_keys (keyvals);
        }

        private void ctrl_alt_fn_activated (GLib.SimpleAction action) {
            uint[] keyvals = { Gdk.Key.Control_L, Gdk.Key.Alt_L, 0 };

            if (action.name[action.name.length - 1] == '1')
                keyvals[2] = Gdk.Key.F1;
            else if (action.name[action.name.length - 1] == '2')
                keyvals[2] = Gdk.Key.F2;
            else if (action.name[action.name.length - 1] == '3')
                keyvals[3] = Gdk.Key.F3;
            else if (action.name[action.name.length - 1] == '7')
                keyvals[2] = Gdk.Key.F7;
            else {
                warn_if_reached ();

                return;
            }

            send_keys (keyvals);
        }

        private void send_keys (uint[] keyvals) {
            connection.send_keys (keyvals);
        }
    }
}
