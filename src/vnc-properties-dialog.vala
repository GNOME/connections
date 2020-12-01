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

            var scaling = new Property () {
                label = _("Scaling"),
                widget = new Gtk.Switch () {
                    active = connection.scaling
                }
            };
            scaling.widget.bind_property ("active", connection, "scaling", BindingFlags.SYNC_CREATE);
            add_property (scaling);

            var view_only = new Property () {
                label = _("View only"),
                widget = new Gtk.Switch () {
                    active = vnc.view_only
                }
            };
            view_only.widget.bind_property ("active", vnc, "view_only", BindingFlags.SYNC_CREATE);
            add_property (view_only);

            var local_pointer = new Property () {
                label = _("Show local pointer"),
                widget = new Gtk.Switch () {
                    active = vnc.show_local_pointer
                }
            };
            local_pointer.widget.bind_property ("active", vnc, "show_local_pointer", BindingFlags.SYNC_CREATE);
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
