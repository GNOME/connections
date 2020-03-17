/* display.vala
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
    private abstract class Display : GLib.Object {
        public abstract Gtk.Widget get_widget ();
        public abstract void connect_to (Machine machine);
        public abstract Gdk.Pixbuf? get_pixbuf ();
        public bool connected;

        public bool can_grab_mouse { get; protected set; }
        public bool mouse_grabbed { get; protected set; }
        public bool keyboard_grabbed { get; protected set; }

        public abstract bool scaling { get; set; }

        public signal void show ();

        public async void take_screenshot () {
            var pixbuf = get_pixbuf ();
            if (pixbuf == null)
                return;

            try {
                var timestamp = new GLib.DateTime.now_local ().format ("%Y-%m-%d %H-%M-%S");

                // Translators: %s => the timestamp of when the screenshot was taken.
                var filename = _("Screenshot from %s").printf (timestamp);
                var path = Path.build_filename (Environment.get_user_special_dir (GLib.UserDirectory.PICTURES),
                                                filename);
                pixbuf.save (path + ".png", "png");
            } catch (GLib.Error error) {
                warning ("Failed to take screenshot %s", error.message);
            }

            flash_display ();
        }

        private void flash_display () {
            var style_context = get_widget ().get_parent ().get_style_context ();
            style_context.add_class ("flash");
            Timeout.add (200, () => {
                style_context.remove_class ("flash");

                return false;
            });
        }
    }
}
