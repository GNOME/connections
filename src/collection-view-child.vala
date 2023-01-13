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
        private unowned Gtk.Label connection_name;

        [GtkChild]
        public unowned Gtk.Image thumbnail; 
        private string default_thumbnail_icon {
            owned get {
                return ("%s-symbolic").printf (Application.application.application_id);
            }
        }

        private uint thumbnail_id = 0;

        public CollectionViewChild (Connection connection) {
            this.connection = connection;

            update_display_name ();
            connection.notify["display-name"].connect (update_display_name);

            thumbnail.icon_name = default_thumbnail_icon;
            connection.show.connect (update_thumbnail);
        }

        private void update_display_name () {
            connection_name.set_text (connection.get_visible_name ());
        }

        private void update_thumbnail () {
            thumbnail_id = Timeout.add_seconds (3, () => {
                thumbnail_id = 0;

                if (!connection.connected) {
                    thumbnail.set_from_icon_name (default_thumbnail_icon,
                                                  Gtk.IconSize.LARGE_TOOLBAR);
                    return Source.REMOVE;
                }

                if (connection.thumbnail == null)
                    return Source.REMOVE;

                var pixbuf = connection.thumbnail.scale_simple (180, 134,
                                                                Gdk.InterpType.BILINEAR);
                thumbnail.set_from_pixbuf (pixbuf);

                return Source.CONTINUE;
            });
        }

        ~CollectionViewChild () {
            if (thumbnail_id != 0)
                Source.remove (thumbnail_id);
                thumbnail_id = 0;
        }
    }
}
