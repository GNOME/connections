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

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/window.ui")]
    private class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private unowned Topbar topbar;

        [GtkChild]
        private unowned Gtk.Stack stack;

        [GtkChild]
        private unowned EmptyView empty_view;

        [GtkChild]
        public unowned CollectionView collection_view;

        [GtkChild]
        private unowned DisplayView display_view;

        [GtkChild]
        public unowned NotificationsBar notifications_bar;

        public Window (Gtk.Application app) {
            Object (application: app);

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;

            stack.set_visible_child (empty_view);

            bind_model (Application.application.model);
            Application.application.model.items_changed.connect (items_changed);

            try {
                var style_provider = new Gtk.CssProvider ();
                var file = File.new_for_uri ("resource:///org/gnome/Connections/ui/style.css");
                style_provider.load_from_file (file);

                Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                          style_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (GLib.Error error) {
                warning ("Failed to load CSS: %s", error.message);
            }

            topbar.search_button.bind_property ("active", collection_view.search_bar, "search_mode_enabled", BindingFlags.BIDIRECTIONAL);

            if (app.application_id == "org.gnome.Connections.Devel") {
                get_style_context ().add_class ("devel");
            }
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

        public void open_connection (Connection connection) {
            display_view.connect_to (connection);

            stack.set_visible_child (display_view);
            topbar.show_display_view (connection);
        }

        public void show_collection_view () {
            stack.set_visible_child (collection_view);
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.Widget widget, Gdk.EventKey event) {
            var default_modifiers = Gtk.accelerator_get_default_mod_mask ();

            if (event.keyval == Gdk.Key.f &&
                (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
                collection_view.search_bar.search_mode_enabled = !collection_view.search_bar.search_mode_enabled;

                return true;
            } else if (event.keyval == Gdk.Key.q &&
                       (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
                Application.application.quit_app ();

                return true;
            } else if (event.keyval == Gdk.Key.F1) {
                Application.application.activate_action ("help", null);

                return true;
            }

            return false;
        }

        [GtkCallback]
        private bool on_delete_event () {
            notifications_bar.dismiss_any_notification ();

            return false;
        }
    }
}
