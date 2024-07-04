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
        private Gtk.Window sidecar_vnc_window;
        private Gtk.Clipboard clipboard;

        private Vnc.Display display;
        public override Gtk.Widget widget {
            set {
                display = value as Vnc.Display;
            }

            get {
                if (sidecar_vnc_window.get_child () != null)
                    sidecar_vnc_window.remove (display);

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

        private bool _enable_audio = true;
        public bool enable_audio {
            set {
                var connection = display.get_connection ();
                _enable_audio = value;

                if (_enable_audio)
                    connection.audio_enable ();
                else
                    connection.audio_disable ();
            }

            get {
                return _enable_audio;
            }
        }

        public override int port { get; protected set; default = 5900; }
        public string bandwidth { get; set; default = "hight-quality"; }
        public string scale_mode { get; set; default = "fit-window"; }

        construct {
            display = new Vnc.Display ();
            display.set_keyboard_grab (true);
            display.set_pointer_grab (true);
            display.set_force_size (false);
            display.set_keep_aspect_ratio (true);

            dispose_display ();

            clipboard = Gtk.Clipboard.get_default (Application.application.main_window.get_display ());

            display.vnc_error.connect (on_connection_error_cb);
            display.vnc_initialized.connect (() => { show (); });
            display.vnc_auth_credential.connect (on_vnc_auth_credential_cb);
            display.vnc_auth_failure.connect (on_vnc_auth_failure_cb);
            display.size_allocate.connect (scale);
            display.vnc_server_cut_text.connect (on_vnc_server_cut_text_cb);
            clipboard.owner_change.connect (on_owner_change_cb);

            notify["scale-mode"].connect (scale);

            var connection = display.get_connection ();
            connection.set_audio_format (new Vnc.AudioFormat () {
                frequency = 44100,
                nchannels = 2
            });
            connection.set_audio (new Vnc.AudioPulse ());
            connection.audio_enable ();
            authentication_complete.connect (update_display_authenticated);
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

        private void update_display_authenticated () {
            connect_it ();
        }

        public override void connect_it () {
            if (connected) {
                show ();

                return;
            }
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

        public override void dispose_display () {
            /* The Vnc.Display widget doesn't like not having a realized window.
             * so we pack it on a temporary window for initialization and for
             * when the connection persists but the display is not being presented. */
            if (sidecar_vnc_window == null)
                sidecar_vnc_window = new Gtk.Window ();

            sidecar_vnc_window.add (display);
            display.realize ();
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

        private void on_vnc_auth_failure_cb (string reason) {
            debug ("Failed to authenticate %s", reason);

            auth_failed (reason);
        }

        private void on_vnc_server_cut_text_cb (string message) {
            if (view_only)
                return;

            clipboard.set_text (message, message.length);
            clipboard.store ();
        }

        private void on_owner_change_cb () {
            if (!connected || view_only)
                return;

            string message = clipboard.wait_for_text ();
            if (message != null)
                display.client_cut_text (message);
        }

        public void scale () {
            if (!display.is_open ())
                return;

            display.scaling = display.expand = false;

            switch (scale_mode) {
                case "resize-desktop":
                    resize_desktop_to_window ();
                    break;
                case "fit-window":
                    scale_to_fit_window ();
                    break;
                case "original":
                    scale_to_original_size ();
                    break;
            }
        }

        private void resize_desktop_to_window () {
            display.set_allow_resize (true);
        }

        private void scale_to_fit_window () {
            display.scaling = display.hexpand = true;
            display.width_request = display.height_request = 0;
            display.set_allow_resize (false);
        }

        private void scale_to_original_size () {
            display.width_request = display.width;
            display.height_request = display.height;
            display.set_allow_resize (false);
        }
    }
}
