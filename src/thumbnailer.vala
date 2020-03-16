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
        public weak Machine machine;

        private uint thumbnail_id;

        public Thumbnailer (Machine machine) {
            this.machine = machine;
        }

        public void update_thumbnail (Display display) {
            if (thumbnail_id != 0)
                return;

            thumbnail_id = Timeout.add_seconds (2, () => {
                var pixbuf = display.get_pixbuf ();
                if (pixbuf != null) {
                    machine.thumbnail = pixbuf.scale_simple (180, 134, Gdk.InterpType.BILINEAR);
                }

               return true; 
            });            
        }
    }
}
