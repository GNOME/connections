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

            var vnc = connection as VncConnection;
            var bandwidth = new ComboProperty (vnc, "bandwidth", vnc.bandwidth) {
                label = _("Bandwidth")
            };
            bandwidth.add_option ("high-quality", _("High quality"));
            bandwidth.add_option ("fast-refresh", _("Fast refresh"));
            bandwidth.changed.connect ((property_value) => {
               vnc.bandwidth = property_value;
            });
            add_property (bandwidth);

            var scale_mode = new ComboProperty (vnc, "scale-mode", vnc.scale_mode) {
                label = _("Scale mode")
            };
            scale_mode.add_option ("fit-window", _("Fit window"));
            scale_mode.add_option ("original", _("Original size"));
            scale_mode.changed.connect ((property_value) => {
                vnc.scale_mode = property_value;
            });
            add_property (scale_mode);
        }
    }
}
