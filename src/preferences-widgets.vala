/* preferences-widgets.vala
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
    private class PreferencesWindow: Hdy.PreferencesWindow {
        protected weak Connection connection;

        construct {
            set_transient_for (Application.application.main_window);
        }

        protected void bind_widget_property (Gtk.Widget widget, string widget_property, string connection_property) {
            connection.bind_property (connection_property, widget, widget_property, BindingFlags.BIDIRECTIONAL);

            var value = GLib.Value (connection.get_class ().find_property (connection_property).value_type);
            connection.get_property (connection_property, ref value);
            widget.set_property (widget_property, value);
        }
    }

    private class BooleanProperty: Hdy.ActionRow {
        public bool active { get; set; }

        construct {
            var widget = new Gtk.Switch () {
                visible = true,
                valign = Gtk.Align.CENTER
            };

            bind_property ("active", widget, "active", BindingFlags.BIDIRECTIONAL);

            add (widget);
            set_activatable_widget (widget);
        }
    }
}
