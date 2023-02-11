/* rdp-preferences-window.vala
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
    [GtkTemplate (ui = "/org/gnome/Connections/ui/rdp-preferences.ui")]
    private class RdpPreferencesWindow : Connections.PreferencesWindow {
        [GtkChild]
        private unowned Gtk.Entry connection_name_entry;
        [GtkChild]
        private unowned Gtk.Label host_address_label;
        [GtkChild]
        private unowned Gtk.ComboBoxText scale_mode_combo;

        public RdpPreferencesWindow (Connection connection) {
            this.connection = connection;

            update_scale_mode_combo ();

            bind_widget_property (connection_name_entry, "text", "display_name");
            bind_widget_property (host_address_label, "label", "uri");
            bind_widget_property (scale_mode_combo, "active_id", "scale-mode");

            connection.notify["resize-supported"].connect (update_scale_mode_combo);
        }

        private void update_scale_mode_combo () {
            if ((((RdpConnection) connection).resize_supported ||
                 ((RdpConnection) connection).scale_mode == "resize-desktop") &&
                !combo_contains_item (scale_mode_combo, "resize-desktop")) {
                // Translators: Combo item for resizing remote desktop to window's size
                scale_mode_combo.insert (0, "resize-desktop", _("Resize desktop"));
            }
        }

        private bool combo_contains_item (Gtk.ComboBoxText combo_box, string item_id) {
            Gtk.TreeIter iter;
            string       mode;

            if (scale_mode_combo.model.get_iter_first (out iter)) {
                scale_mode_combo.model.get (iter, 1, out mode);
                if (mode == item_id) {
                    return true;
                } else {
                    while (scale_mode_combo.model.iter_next (ref iter)) {
                        scale_mode_combo.model.get (iter, 1, out mode);
                        if (mode == item_id)
                            return true;
                    }
                }
            }

            return false;
        }
    }
}
