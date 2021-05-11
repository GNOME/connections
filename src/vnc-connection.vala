/* vnc-connection.vala
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
    private class VncConnection : Connection {
        private Gtk.Window window;

        private Vnc.Display display;
        public override Gtk.Widget widget {
            set {
                display = value as Vnc.Display;
            }

            get {
                if (window.get_child () != null)
                    window.remove (display);

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
                display.set_scaling (value);
            }

            get {
                return display.get_scaling ();
            }
        }

        public bool view_only {
            set {
                display.set_read_only (value);
            }

            get {
                return display.get_read_only ();
            }
        }

        public bool show_local_pointer {
            set {
                display.set_pointer_local (value);
            }

            get {
                return display.get_pointer_local ();
            }
        }

        public override int port { get; protected set; default = 5900; }
        public string bandwidth { get; set; default = "hight-quality"; }

        construct {
            display = new Vnc.Display ();
            display.set_keyboard_grab (true);
            display.set_pointer_grab (true);
            display.set_force_size (false);

            window = new Gtk.Window ();
            window.add (display);
            display.realize ();

            display.vnc_initialized.connect (() => { show (); });
            display.vnc_auth_credential.connect (on_vnc_auth_credential_cb);
            display.vnc_auth_failure.connect (on_vnc_auth_failure_cb);
            display.size_allocate.connect (scale);
        }

        public VncConnection (string uuid) {
            this.uuid = uuid;
        }

        public VncConnection.from_uri (string uri) {
            this.uuid = Uuid.string_random ();
            this.uri = uri;
        }

        public VncConnection.from_vnc_file(string file_path) {
            var key_file = new KeyFile();

            try {
                key_file.load_from_file (file_path, GLib.KeyFileFlags.NONE);
            } catch (GLib.Error e) {
                warning (_ ("Couldn’t parse the file"));
                return;
            }

            try {
                this.host = key_file.get_string ("Connection", "Host");
            } catch (GLib.Error e) {
                // Translators: %s is a VNC file key
                info  ( _("VNC File is missing key “%s”".printf ("Host")));
            }
            try {
                this.port = key_file.get_integer ("Connection", "Port");
            } catch (GLib.Error e) {
                info  ( _ ("VNC File is missing key “%s”".printf ("Port")));
            }
            try {
                this.username = key_file.get_string ("Connection", "Username");
            } catch (GLib.Error e) {
                info  ( _ ("VNC File is missing key “%s”".printf ("Username")));
            }
            try {
                this.password = key_file.get_string ("Connection", "Password ");
            } catch (GLib.Error e) {
                info  ( _ ("VNC File is missing key “%s”".printf ("Password")));
            }

            this.uuid = Uuid.string_random ();
        }

        ~VncConnection () {
            debug ("Closing connection with %s", widget.name);

            disconnect_it ();
        }

        public override void connect_it () {
            if (connected)
                return;
            connected = true;

            display.set_credential (DisplayCredential.USERNAME, username);
            display.set_credential (DisplayCredential.PASSWORD, password);
            display.set_credential (DisplayCredential.CLIENTNAME, "connections");

            display.open_host (host, port.to_string ());
        }

        public override void disconnect_it () {
            if (display.is_open ())
                display.close ();
            connected = false;
        }

        public override void send_keys (uint[] keyvals) {
            display.send_keys (keyvals);
        }

        private void on_vnc_auth_credential_cb (ValueArray creds) {
            foreach (var cred in creds) {
                var credential = (DisplayCredential) cred;

                switch (credential) {
                case DisplayCredential.USERNAME:
                    need_username = true;
                    handle_auth ();
                    break;

                case DisplayCredential.PASSWORD:
                    need_password = true;
                    handle_auth ();
                    break;

                case DisplayCredential.CLIENTNAME:
                    break;

                default:
                    debug ("Unsupported credential: %s".printf (credential.to_string ()));
                    break;
                }
            }

            disconnect_it ();
            connected = false;
        }

        private void on_vnc_auth_failure_cb (string message) {
            debug ("Failed to authenticate %s", message);
        }

        public void scale () {
            if (!display.is_open ())
                return;

            display.scaling = display.hexpand = true;
            display.width_request = display.height_request = 0;
        }
    }
}
