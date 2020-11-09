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

        construct {
            display = new FrdpDisplay ();
            display.bind_property ("username", this, "username", BindingFlags.BIDIRECTIONAL);
            display.bind_property ("password", this, "password", BindingFlags.BIDIRECTIONAL);

            display.rdp_connected.connect (() => { show (); });
            display.rdp_needs_authentication.connect (on_rdp_auth_credential_cb);
            //display.size_allocate.connect (scale);

            config = new RdpConfig () {
                connection = this
            };
        }

        public RdpConnection (string uuid) {
            this.uuid = uuid;

            config.load ();
        }

        public RdpConnection.from_uri (string uri) {
            this.uri = uri;

            this.uuid = Uuid.string_random ();
            config.save ();
        }

        ~RdpConnection () {
            debug ("Closing connection with %s", widget.name);

            disconnect_it ();
        }

        public override void connect_it () {
            if (connected)
                return;
            connected = true;

            display.open_host (host, port);
        }

        public override void disconnect_it () {
            display.close ();
            connected = false;
        }

        public override void send_keys (uint[] keyvals) {
        }

        private void on_rdp_auth_credential_cb () {
            need_username = need_password = true;

            handle_auth ();

            display.close ();
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

    private class RdpPropertiesDialog : PropertiesDialog {
        public RdpPropertiesDialog (Connection connection) {
            this.connection = connection;

            var scaling = new Property () {
                label = _("Scaling"),
                widget = new Gtk.Switch () {
                    active = connection.scaling
                }
            };
            scaling.widget.bind_property ("active", connection, "scaling", BindingFlags.SYNC_CREATE);
            connection.notify["scaling"].connect (() => { connection.save (); });
            add_property (scaling);
        }
    }

    private class RdpConfig : ConnectionConfig {
        public override void load () {
            base.load ();
        }

        public override void save () {
            base.save ();
        }
    }
}
