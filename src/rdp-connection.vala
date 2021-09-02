/* rdp-connection.vala
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
    private class RdpConnection : Connection {
        private FrdpDisplay display;
        public override Gtk.Widget widget {
            set {
                display = value as FrdpDisplay;
            }

            get {
                return display as Gtk.Widget;
            }
        }

        protected override Gdk.Pixbuf? thumbnail {
            set {
                return;
            }

            owned get {
                return display.get_pixbuf ();
            }
        }

        public override bool scaling {
            set {
                //display.set_scaling (value);
            }

            get {
                return true;
            }
        }

        public override int port { get; protected set; default = 3389; }

        construct {
            display = new FrdpDisplay ();
            display.bind_property ("username", this, "username", BindingFlags.BIDIRECTIONAL);
            display.bind_property ("password", this, "password", BindingFlags.BIDIRECTIONAL);

            display.rdp_connected.connect (() => { show (); });
            //display.rdp_needs_authentication.connect (on_rdp_auth_credential_cb);
            display.rdp_auth_failure.connect (auth_failed);
            //display.size_allocate.connect (scale);

            need_username = need_password = true;
        }

        public RdpConnection (string uuid) {
            this.uuid = uuid;
        }

        public RdpConnection.from_uri (string uri) {
            this.uuid = Uuid.string_random ();
            this.uri = uri;
        }

        ~RdpConnection () {
            debug ("Closing connection with %s", widget.name);

            disconnect_it ();
        }

        public override void connect_it () {
            if (connected)
                return;

            if (username == null && password == null) {
                handle_auth ();

                return;
            }

            display.open_host (host, port);
            connected = true;
        }

        public override void disconnect_it () {
            if (connected)
                display.close ();
            connected = false;
        }

        public override void dispose_display () {
        }

        public override void send_keys (uint[] keyvals) {
        }

        private void on_rdp_auth_credential_cb () {
            need_username = need_password = true;

            handle_auth ();
        }
    }

    private class FrdpDisplay : Frdp.Display {
        public override bool authenticate (out string username, out string password, out string domain) {
            username = this.username;
            password = this.password;
            domain = null;

            return true;
        }
    }
}
