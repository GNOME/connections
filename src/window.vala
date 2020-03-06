/* window.vala
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

namespace Remote {
    [GtkTemplate (ui = "/org/gnome/Remote/ui/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private Topbar topbar;

        [GtkChild]
        private Gtk.Stack stack;

        [GtkChild]
        private EmptyView empty_view;

        [GtkChild]
        private CollectionView collection_view;

        [GtkChild]
        private DisplayView display_view;

        public Window (Gtk.Application app) {
            Object (application: app);

            stack.set_visible_child (empty_view);

            bind_model (Application.application.model);
            Application.application.model.items_changed.connect (items_changed);
        }

        public void bind_model (ListModel model) {
            collection_view.bind_model (model);
        }

        public void items_changed () {
            if (Application.application.model.get_n_items () > 0)
                stack.set_visible_child (collection_view);
            else
                stack.set_visible_child (empty_view);
        }

        public void open_machine (Machine machine) {
            display_view.connect_to (machine);
            stack.set_visible_child (display_view);
        }
    }
}
