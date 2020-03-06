/* vnc-display.vala
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

using Vnc;

namespace Connections {
    private class VncDisplay : Connections.Display {
        private Gtk.Window window;

        private Vnc.Display display;

        construct {
            display = new Vnc.Display ();
            display.set_keyboard_grab (true);
            display.set_pointer_grab (true);
            display.set_force_size (false);
            display.set_scaling (true);

            window = new Gtk.Window ();
            window.add (display);
            display.realize ();

            display.vnc_auth_failure.connect (on_vnc_auth_failure_cb);
            display.vnc_initialized.connect (() => {
                show ();
                print ("HERE!\n");
            });
            display.vnc_auth_credential.connect ((creds) => {
                foreach (var cred in creds) {
                    var credential = (DisplayCredential) cred;

                    switch (credential) {
                    case DisplayCredential.USERNAME:
                        print ("need username\n");
                        break;

                        case DisplayCredential.PASSWORD:
                            print ("need passswd\n");
                            break;

                        case DisplayCredential.CLIENTNAME:
                            break;

                        default:
                            debug ("Unsupported credential: %s".printf (credential.to_string ()));
                            break;
                    }
                }
                display.close ();
            });
            display.vnc_auth_unsupported.connect (() => {
                debug ("auth unsupported");
            });

            display.size_allocate.connect (scale);
        }

        ~VncDisplay () {
            debug ("Closig connection with %s", display.name);

            if (display.is_open ())
                display.close ();
        }

        public override Gtk.Widget get_widget () {
            window.remove (display);

            return display;
        }

        public override void connect_to (Machine machine) {
            if (connected)
                return;
            connected = true;

            display.open_host (machine.host, machine.port.to_string ());
        }

        private void on_vnc_auth_failure_cb (string message) {
            debug ("auth failed: %s", message);
        }

        public override Gdk.Pixbuf? get_pixbuf () {
            return display.get_pixbuf ();
        }

        public void scale () {
            if (!display.is_open ())
                return;

            // Get the allocated size of the parent container
            Gtk.Allocation alloc;
            display.get_parent ().get_allocation (out alloc);

            double parent_aspect = (double) alloc.width / (double) alloc.height;
            double display_aspect = (double) display.get_width () / (double) display.get_height ();
            Gtk.Allocation scaled = alloc;
            if (parent_aspect > display_aspect) {
                scaled.width = (int) (alloc.height * display_aspect);
                scaled.x += (alloc.width - scaled.width) / 2;
            } else {
                scaled.height = (int) (alloc.width / display_aspect);
                scaled.y += (alloc.height - scaled.height) / 2;
            }

            display.size_allocate (scaled);
        }
    }
}
