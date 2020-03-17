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
        private Gtk.HeaderBar collection_toolbar;
        [GtkChild]
        private Gtk.HeaderBar display_toolbar;

        private weak Connections.Machine machine;
        private const GLib.ActionEntry[] action_entries = {
            {"properties", properties_activated}
        };

        construct {
            var action_group = new GLib.SimpleActionGroup ();
            action_group.add_action_entries (action_entries, this);
            this.insert_action_group ("display", action_group);

            var menu = new GLib.Menu ();
            var section = new GLib.Menu ();

            section.append (_("Properties"), "display.properties");
            var action = action_group.lookup_action ("properties") as GLib.SimpleAction;
            action.set_enabled (true);
        }

        private void properties_activated () {
            (new VncPropertiesDialog (machine).run ());
        }

        [GtkCallback]
        private void add_new_machine_button_clicked () {
            (new Connections.Assistant (Application.application.main_window)).run ();
        }

        [GtkCallback]
        private void back_button_clicked () {
            Application.application.main_window.show_collection_view ();
            set_visible_child (collection_toolbar);
        }

        public void show_display_view (Machine machine) {
            this.machine = machine;

            set_visible_child (display_toolbar);

            display_toolbar.set_title (machine.display_name);
        }
    }
}
