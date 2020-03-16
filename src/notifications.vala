/* notifications.vala
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
    private class NotificationsBar : Gtk.Bin {
        public const int DEFAULT_TIMEOUT = 6;

        construct {
            valign = Gtk.Align.START;
            halign = Gtk.Align.CENTER;
            get_style_context ().add_class ("transparent-bg");
        }

        public void display_for_action (string message,
                                        string? ok_label,
                                        owned Notification.OKFunc? ok_func,
                                        owned Notification.DismissFunc? dismiss_func) {
            var notification = new Notification (message, ok_label, (owned) ok_func, (owned) dismiss_func);

            if (get_child () != null)
                remove (get_child ());

            add (notification);
        }
    }

    [GtkTemplate (ui = "/org/gnome/Connections/ui/notification.ui")]
    private class Notification : Gtk.Revealer {
        public delegate void OKFunc ();
        public delegate void DismissFunc ();

        [GtkChild]
        private Gtk.Label message_label; 
        [GtkChild]
        private Gtk.Button ok_button; 
        [GtkChild]
        private Gtk.Button close_button; 

        public Notification (string  message,
                             string? ok_label,
                             owned OKFunc? ok_func,
                             owned DismissFunc? dismiss_func) {
            set_reveal_child (true);

            message_label.label = message;

            if (ok_label != null) {
                ok_button.label = ok_label;

                ok_button.clicked.connect (() => {
                    if (ok_func != null)
                        ok_func ();

                    set_reveal_child (false);
                });

                ok_button.show_all ();
            }

            close_button.clicked.connect (() => {
                set_reveal_child (false);
                if (dismiss_func != null)
                    dismiss_func ();
            });
        }
    }
}
