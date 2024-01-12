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
                Gtk.Allocation alloc;
                widget.get_allocation (out alloc);

                var surface = new Cairo.ImageSurface (ARGB32, alloc.width, alloc.height);
                var context = new Cairo.Context (surface);
/*                widget.draw (context);*/

                return Gdk.pixbuf_get_from_surface (surface, 0, 0, alloc.width, alloc.height);
            }
        }

        public override bool scaling {
            set {
                display.set_scaling (value);
            }

            get {
                if (!connected)
                    return true;

                return display.scaling;
            }
        }

        public override int port { get; protected set; default = 3389; }
        public bool resize_supported { get; protected set; default = false; }
        public string scale_mode { get; set; default = "fit-window"; }

        construct {
            display = new FrdpDisplay ();
            display.hexpand = display.vexpand = true;
            display.bind_property ("username", this, "username", BindingFlags.BIDIRECTIONAL);
            display.bind_property ("password", this, "password", BindingFlags.BIDIRECTIONAL);

            display.rdp_error.connect (on_rdp_connection_error_cb);
            display.rdp_connected.connect (on_rdp_connection_connected_cb);
            //display.rdp_needs_authentication.connect (on_rdp_auth_credential_cb);
            display.rdp_auth_failure.connect (auth_failed);
            display.resize.connect (resize_cb);

            notify["scale-mode"].connect (scale);
            display.notify["resize-supported"].connect (update_resize_supported);

            widget = display;

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
            if (connected) {
                show ();

                return;
            }

            if (username == null && password == null) {
                handle_auth ();

                return;
            }

            display.open_host (host, port);
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

        private void on_rdp_connection_error_cb (string reason) {
            disconnect_it ();

            delete_auth_credentials.begin ();
            username = password = null;

            on_connection_error_cb (reason);
        }

        private void on_rdp_connection_connected_cb () {
            connected = true;
            scaling = true;

            display.grab_focus ();
            show ();
        }

        public void resize_cb (int width,
                               int height) {
            scale ();
        }

        public void scale () {
            if (!display.is_open ())
                return;

            display.scaling = display.vexpand = display.hexpand = false;

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
            display.allow_resize = true;
        }

        private void scale_to_fit_window () {
            display.scaling = display.hexpand = true;
            display.width_request = display.height_request = 0;
            display.allow_resize = false;
        }

        private void scale_to_original_size () {
            display.allow_resize = false;
        }

        private void update_resize_supported () {
            resize_supported = display.resize_supported;
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
