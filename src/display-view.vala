/* display-view.vala
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

using Gtk;
using Gdk;

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/display-view.ui")]
    private class DisplayView : Gtk.Box {

        [GtkChild]
        private unowned ScrolledWindow scrolled_window;
        [GtkChild]
        private unowned Stack stack;
        [GtkChild]
        private unowned Label size_label;
        [GtkChild]
        private unowned Button escape_fullscreen_button;

        private Connection? connection;

        private ulong show_display_id;
        private int last_width = -1;
        private int last_height = -1;

        [GtkCallback]
        private void motion_cb (double x,
                                double y) {
            if (!Application.application.main_window.fullscreened)
                return;

            escape_fullscreen_button.visible = (y < 40.0);
        }

        private void remove_display () {
            if (connection == null)
                return;

            connection.dispose_display ();
            connection = null;
        }

        public void replace_display (Connection connection) {
            remove_display ();

            this.connection = connection;
            var display = (Gtk.DrawingArea) connection.widget;

            display.hexpand = false;
            display.vexpand = false;
            display.halign = Gtk.Align.CENTER;
            display.valign = Gtk.Align.CENTER;
            display.focusable = true;

            scrolled_window.set_child (display);
            scrolled_window.show ();
            display.show ();

            ulong resize_id = 0;
            resize_id = display.resize.connect (display_resize_cb);
        }

        private uint size_label_timeout;
        private void display_resize_cb (int width, int height) {
            var display = (Gtk.DrawingArea) connection.widget;

            if (width != last_width || height != last_height) {
                // Translators: Showing size of widget as WIDTH×HEIGHT here.
                size_label.label = _("%d×%d").printf (width, height);

                Idle.add (() => {
                    size_label.visible = true;

                    if (size_label_timeout != 0) {
                        Source.remove (size_label_timeout);
                        size_label_timeout = 0;
                    }

                    size_label_timeout = Timeout.add_seconds (3, () => {
                        size_label.visible = false;
                        size_label_timeout = 0;

                        return false;
                    });

                    return false;
                });
            }

            last_width = width;
            last_height = height;
        }

        public void connect_to (Connection connection) {
            stack.set_visible_child_name ("loading");

            if (show_display_id != 0) {
                this.connection.disconnect (show_display_id);
                show_display_id = 0;
            }

            replace_display (connection);

            show_display_id = connection.show.connect (show_display);
            connection.connect_it ();
        }

        private void show_display () {
            stack.set_visible_child_name ("display");
        }

        [GtkCallback]
        private void on_escape_fullscreen_button_clicked () {
            Application.application.main_window.fullscreened = false;
            escape_fullscreen_button.visible = false;
        }
    }
}
