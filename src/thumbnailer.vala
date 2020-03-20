/* thumbnailer.vala
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
    private class Thumbnailer : GLib.Object {
        public weak Connection connection;

        public signal void update ();

        public string? thumbnail_path {
            owned get {
                return Path.build_filename (Environment.get_user_cache_dir (),
                                            "connections",
                                            connection.host + ".png");
            }
        }

        private uint thumbnail_id;

        public Thumbnailer (Connection connection) {
            this.connection = connection;
        }

        public void update_thumbnail () {
            if (thumbnail_id != 0)
                return;

            thumbnail_id = Timeout.add_seconds (3, () => {
                if (connection.thumbnail != null) {
                    update ();
                    try {
                        connection.thumbnail.save (thumbnail_path, "png");
                    } catch (GLib.Error error) {
                        warning (error.message);

                        return true;
                    }
                }

               return true; 
            });            
        }
    }
}
