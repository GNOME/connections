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

        public override bool view_only {
            set {
                display.set_read_only (value);
            }

            get {
                return display.get_read_only ();
            }
        }

        public override bool show_local_pointer {
            set {
                display.set_pointer_local (value);
            }

            get {
                return display.get_pointer_local ();
            }
        }

        construct {
            display = new Vnc.Display ();
            display.set_keyboard_grab (true);
            display.set_pointer_grab (true);
            display.set_force_size (false);
            display.set_scaling (true);

            window = new Gtk.Window ();
            window.add (display);
            display.realize ();

            display.vnc_initialized.connect (() => { show (); });
            display.vnc_auth_credential.connect (on_vnc_auth_credential_cb);
            display.vnc_auth_failure.connect (on_vnc_auth_failure_cb);
            display.size_allocate.connect (scale);

            config = new VncConfig () {
                connection = this
            };
        }

        public VncConnection (string uuid) {
            this.uuid = uuid;

            config.load ();
        }

        public VncConnection.from_uri (string uri) {
            this.uri = uri;

            this.uuid = Uuid.string_random ();
            config.save ();
        }

        ~VncConnection () {
            debug ("Closig connection with %s", widget.name);

            if (display.is_open ())
                display.close ();
        }

        public override void connect_it () {
            if (connected)
                return;
            connected = true;

            display.set_credential (DisplayCredential.USERNAME, username);
            display.set_credential (DisplayCredential.PASSWORD, password);
            display.set_credential (DisplayCredential.CLIENTNAME, "gnome-connections");

            display.open_host (host, port.to_string ());
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

            display.close ();
            connected = false;
        }

        private void on_vnc_auth_failure_cb (string message) {
            debug ("Failed to authenticate %s", message);
        }

        public void scale () {
            if (!display.is_open ())
                return;

            // Get the allocated size of the parent container
            Gtk.Allocation alloc;
            display.get_parent ().get_allocation (out alloc);
            if (display.get_width () > alloc.width) {
                display.width_request = alloc.width;

                display.height_request = (alloc.width * display.height) / display.width;
            }

            if (display.get_height () > alloc.height) {
                display.height_request = alloc.height;

                display.width_request = (alloc.height * display.width) / display.height;
            }
        }
    }

    private class VncPropertiesDialog : PropertiesDialog {

        public VncPropertiesDialog (Connection connection) {
            this.connection = connection as VncConnection;

            var scaling = new Property () {
                label = _("Scaling"),
                widget = new Gtk.Switch () {
                    active = connection.scaling
                }
            };
            scaling.widget.bind_property ("active", connection, "scaling", BindingFlags.SYNC_CREATE);
            connection.notify["scaling"].connect (() => { connection.save (); });
            add_property (scaling);

            var view_only = new Property () {
                label = _("View only"),
                widget = new Gtk.Switch () {
                    active = connection.view_only
                }
            };
            view_only.widget.bind_property ("active", connection, "view_only", BindingFlags.SYNC_CREATE);
            connection.notify["view-only"].connect (() => { connection.save (); });
            add_property (view_only);

            var local_pointer = new Property () {
                label = _("Show local pointer"),
                widget = new Gtk.Switch () {
                    active = connection.show_local_pointer
                }
            };
            local_pointer.widget.bind_property ("active", connection, "show_local_pointer", BindingFlags.SYNC_CREATE);
            connection.notify["show-local-pointer"].connect (() => { connection.save (); });
            add_property (local_pointer);
        }
    }

    private class VncConfig : ConnectionConfig {
        public override void load () {
            base.load ();

            connection.view_only = get_boolean (connection.uuid, "view_only");
            connection.show_local_pointer = get_boolean (connection.uuid, "show_local_pointer");
        }

        public override void save () {
            base.save ();

            set_boolean (connection.uuid, "view_only", connection.view_only);
            set_boolean (connection.uuid, "show_local_pointer", connection.show_local_pointer);
        }
    }
}
