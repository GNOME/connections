/* connection.vala
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
    private abstract class Connection : GLib.Object {
        public string uuid;

        public signal void show ();

        public abstract Gtk.Widget widget { get; protected set; }
        public abstract bool scaling { get; set; }

        private Cancellable auth_cancellable = new Cancellable ();
        private Secret.Schema secret_auth_schema
                = new Secret.Schema ("org.gnome.Connections",
                                     Secret.SchemaFlags.NONE,
                                     "gnome-connections-connection-uuid", Secret.SchemaAttributeType.STRING);

        public bool connected;

        public string uri {
            owned get {
                return @"$protocol://$host:$port";
            }

            set {
                var address = Xml.URI.parse (value);

                protocol = address.scheme;
                host = address.server;
                port = (address.port != 0) ? address.port : port;
            }
        }

        public string host { get; protected set; }
        public abstract int port { get; protected set; }
        public string protocol { get; protected set; }
        public string display_name { get; set; default = ""; }

        public abstract void send_keys (uint[] keys);

        public abstract Gdk.Pixbuf? thumbnail { set; owned get; }

        public async void take_screenshot () {
            if (thumbnail == null)
                return;

            try {
                var timestamp = new GLib.DateTime.now_local ().format ("%Y-%m-%d %H-%M-%S");

                // Translators: %s => the timestamp of when the screenshot was taken.
                var filename = _("Screenshot from %s").printf (timestamp);
                var path = Path.build_filename (Environment.get_user_special_dir (GLib.UserDirectory.PICTURES),
                                                filename);
                thumbnail.save (path + ".png", "png");

                Notification.OKFunc open = () => {
/*
                    debug ("Opening screenshot file");
                    try {
                        Gtk.show_uri_on_window (Application.application.main_window,
                                      File.new_for_path (path).get_uri () + ".png",
                                      Gdk.CURRENT_TIME);
                    } catch (GLib.Error error) {
                        warning ("Failed to open screenshot: %s", error.message);
                    }
*/
                };
                var message = _("Screenshot taken");
                // Translators: Open is a verb
                Application.application.main_window.notifications_bar.display_for_action (message,
                                                                                          _("Open"),
                                                                                          (owned) open,
                                                                                          null);
            } catch (GLib.Error error) {
                warning ("Failed to take screenshot %s", error.message);
            }

            flash_display ();
        }

        private void flash_display () {
            var style_context = widget.get_parent ().get_style_context ();
            style_context.add_class ("flash");
            Timeout.add (200, () => {
                style_context.remove_class ("flash");

                return false;
            });
        }

        private AuthNotification auth_notification = null;
        public bool need_password;
        public bool need_username;
        public string? username { get; set; }
        public string? password { get; set; }
        protected void handle_auth () {
            if (auth_notification != null)
                return;

            if (!need_username && !need_password)
                return;

            AuthNotification.AuthFunc auth_func = (username, password) => {
                if (username != "")
                    this.username = username;
                if (password != "")
                    this.password = password;

                Application.application.open_connection (this);
            };

            Notification.DismissFunc dismiss_func = () => {
                auth_notification = null;
            };

            Secret.password_lookup.begin (secret_auth_schema, auth_cancellable, (obj, res) => {
                try {
                    var parsing_error = new IOError.FAILED("couldn't unpack a string for the connection credentials");

                    var credentials_str = Secret.password_lookup.end (res);
                    if (credentials_str == null || credentials_str == "")
                        throw parsing_error;

                    try {
                        var credentials_variant = GLib.Variant.parse (null, credentials_str, null, null);

                        string username_str;
                        credentials_variant.lookup ("username", "s", out username_str);
                        if (username_str != null && username_str != "")
                            this.username = username_str;

                        string password_str;
                        credentials_variant.lookup ("password", "s", out password_str);
                        if (password_str != null && password_str != "")
                            this.password = password_str;

                        Application.application.open_connection (this);
                    } catch (GLib.Error error) {
                        throw parsing_error;
                    }
                } catch (GLib.Error error) {
                    debug ("No credentials found in keyring. Prompting user.");

                    var auth_string = _("“%s” requires authentication").printf (get_visible_name ());
                    auth_notification = Application.application.main_window.notifications_bar.display_for_auth (auth_string,
                                                                                                                (owned) auth_func,
                                                                                                                (owned) dismiss_func,
                                                                                                                need_username);
                }
            }, "gnome-connections-connection-uuid", uuid);
        }

        public async void delete_auth_credentials () {
            if (uuid == null) {
                return;
            }

            try {
                yield Secret.password_clear (secret_auth_schema, null,
                                             "gnome-connections-connection-uuid", uuid);

                if (auth_notification != null) {
                    auth_notification.dismiss ();
                    auth_notification = null;
                }
            } catch (GLib.Error error) {
                debug ("Failed to delete credentials for connection %s: %s", uuid, error.message);
            }
        }

        protected void on_connection_error_cb (string reason) {
            Application.application.main_window.notifications_bar.display_for_error (reason);
            Application.application.main_window.show_collection_view ();
        }

        protected void auth_failed (string reason) {
            disconnect_it ();

            delete_auth_credentials.begin ();
            username = password = null;

            auth_notification = null;
            var message = _("Authentication failed: %s").printf (reason);
            Application.application.main_window.show_collection_view ();
            Application.application.main_window.notifications_bar.display_for_error (message);
        }

        construct {
            notify.connect (save);
        }

        public void save (GLib.ParamSpec? pspec = null) {
            if (uuid != null && pspec != null) {
                /* Don't save the credentials in plain text */
                if (pspec.name == "username" || pspec.name == "password") {
                  store_auth_credentials ();
                  return;
                }

                Database.get_default ().save_property (this, pspec.name);
            }
        }

        private void store_auth_credentials () {
            if (this.password == "" || this.password == null)
                return;

            var builder = new GLib.VariantBuilder (GLib.VariantType.VARDICT);

            if (this.username != null)
                builder.add ("{sv}", "username", new GLib.Variant ("s", this.username));

            builder.add ("{sv}", "password", new GLib.Variant ("s", this.password));

            var credentials_str = builder.end ().print (true);

            var label = ("GNOME Connections credentials for '%s'").printf (uuid);
            Secret.password_store.begin (secret_auth_schema,
                                         Secret.COLLECTION_DEFAULT,
                                         label,
                                         credentials_str,
                                         null,
                                         (obj, res) => {
                try {
                    Secret.password_store.end (res);
                } catch (GLib.Error error) {
                    warning ("Failed to store password for '%s' in the keyring: %s", uuid, error.message);
                }
            }, "gnome-connections-connection-uuid", uuid);
        }

        public string get_visible_name () {
            if (display_name != null && display_name != "")
                return display_name;

            return uri;
        }

        public abstract void connect_it ();
        public abstract void disconnect_it ();

        public abstract void dispose_display ();
    }
}
