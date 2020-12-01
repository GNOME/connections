/* vnc-properties-dialog.vala
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
    private class VncPropertiesDialog : PropertiesDialog {
        public VncPropertiesDialog (Connection connection) {
            this.connection = connection;
            var vnc = connection as VncConnection;

            var scaling = new BooleanProperty (connection, "scaling") {
                label = _("Scaling")
            };
            add_property (scaling);

            var view_only = new BooleanProperty (connection, "view-only") {
                label = _("View only")
            };
            add_property (view_only);

            var local_pointer = new BooleanProperty (connection, "show-local-pointer") {
                label = _("Show local pointer")
            };
            add_property (local_pointer);

            var combo_widget = new Gtk.ComboBoxText ();
            combo_widget.append ("high-quality", _("High quality"));
            combo_widget.append ("fast-refresh", _("Fast refresh"));
            combo_widget.active_id = vnc.bandwidth.to_string ();
            var bandwidth = new Property () {
                label = _("Bandwidth"),
                widget = combo_widget
            };
            combo_widget.notify["active-id"].connect (() => {
                vnc.bandwidth = vnc.bandwidth.from_string (combo_widget.active_id);
            });
            add_property (bandwidth);
        }
    }
}
