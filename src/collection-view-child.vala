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
    private class CollectionViewChild : Gtk.Box {
        public Connection connection;

        [GtkChild]
        private Gtk.Label connection_name;

        [GtkChild]
        public Gtk.Image thumbnail; 

        private ulong deleted_notify_id;

        public CollectionViewChild (Connection connection) {
            this.connection = connection;

            connection_name.set_text (connection.display_name);
            connection.bind_property ("display_name", connection_name, "label", BindingFlags.SYNC_CREATE);

            connection.thumbnailer.update.connect (() => {
                thumbnail.set_from_pixbuf (connection.thumbnail.scale_simple (180, 134, Gdk.InterpType.BILINEAR));
            }); 

            update_thumbnail.begin ();
        }

        private async void update_thumbnail () {
            var file = GLib.File.new_for_path (connection.thumbnailer.thumbnail_path);
            if (file.query_exists ()) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale (file.get_path (), 180, 134, true);
                    thumbnail.set_from_pixbuf (pixbuf);
                } catch (GLib.Error error) {
                    debug ("Failed to update thumbnail: %s", error.message);
                }
            }
        }
    }
}
