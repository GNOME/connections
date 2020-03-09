/* collection-view-child.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/collection-view-child.ui")]
    public class CollectionViewChild : Gtk.Box {
        public Machine machine;

        [GtkChild]
        private Gtk.Label machine_name;

        [GtkChild]
        public Gtk.Image thumbnail; 

        private ulong deleted_notify_id;

        public CollectionViewChild (Machine machine) {
            this.machine = machine;

            machine_name.set_text (machine.display_name != null ? machine.display_name : machine.uri);
        }
    }
}
