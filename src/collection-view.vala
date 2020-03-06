/* collection-view.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/collection-view.ui")]
    public class CollectionView : Gtk.ScrolledWindow {
        [GtkChild]
        private Gtk.FlowBox flowbox; 

        private Connections.ActionsPopover popover;

        construct {
            popover = new Connections.ActionsPopover ();
        }

        public void bind_model (ListModel model) {
            flowbox.bind_model (model, create_child);
        }

        private Gtk.Widget create_child (Object item) {
            var child = new Gtk.FlowBoxChild (); 
            child.halign = Gtk.Align.START;

            var box = new CollectionViewChild (item as Machine);
            child.add (box);

            return child;
        }

        [GtkCallback]
        private void on_child_activated (Gtk.FlowBoxChild child) {
            var item = child.get_child () as CollectionViewChild;
            if (item == null)
                return;

            Application.application.open_machine (item.machine);
        } 

        [GtkCallback]
        private bool on_button_release_event (Gdk.EventButton event) { 
            if (event.type != Gdk.EventType.BUTTON_RELEASE || event.button != 3)
                return false;

            var child = flowbox.get_child_at_pos ((int) event.x, (int) event.y);

            return launch_context_popover_for_child (child);
        }

        private bool launch_context_popover_for_child (Gtk.FlowBoxChild child) {
            var item = child.get_child () as CollectionViewChild;
            if (item == null)
                return false;

            popover.update_for_item (item.machine);
            popover.set_relative_to (item.thumbnail);
            popover.show ();

            return true;
        }
    }
}
