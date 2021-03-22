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

        public bool need_password { get; protected set; }
        public bool need_username { get; protected set; }

        public abstract bool scaling { get; set; }

        protected ConnectionConfig config;

        public bool connected;

        public enum Protocol {
            UNKNOWN,
            VNC,
            RDP;

            public string to_string () {
                switch (this) {
                    case VNC:
                        return "vnc";
                    case RDP:
                        return "rdp";
                    case UNKNOWN:
                        return "unknown";
                    default:
                        assert_not_reached ();
                }
            }

            public Protocol from_string (string protocol) {
                switch (protocol) {
                    case "vnc":
                        return VNC;
                    case "rdp":
                        return RDP;
                    case "unknown":
                    default:
                       return UNKNOWN;
                }
            }

            public int get_default_port () {
                switch (this) {
                    case VNC:
                        return 5900;
                    case RDP:
                        return 3389;
                    case UNKNOWN:
                    default:
                        assert_not_reached ();
                }
            }
        }
        public Protocol protocol;

        public string uri {
            owned get {
                return @"$protocol://$host:$port";
            }

            set {
                var address = Xml.URI.parse (value);

                protocol = protocol.from_string (address.scheme);
                host = address.server;
                port = (address.port != 0) ? address.port : protocol.get_default_port ();
            }
        }

        public string host;
        public int port;

        private string _display_name;
        public string display_name {
            owned get {
                if (_display_name != null)
                    return _display_name;

                return uri;
            }

            set {
                _display_name = value;
            }
        }

        public abstract void send_keys (uint[] keys);

        public Thumbnailer thumbnailer;
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
                    debug ("Opening screenshot file");
                    try {
                        Gtk.show_uri_on_window (Application.application.main_window,
                                      File.new_for_path (path).get_uri () + ".png",
                                      Gdk.CURRENT_TIME);
                    } catch (GLib.Error error) {
                        warning ("Failed to open screenshot: %s", error.message);
                    }
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

            var auth_string = _("“%s” requires authentication").printf (display_name);
            auth_notification =
                Application.application.main_window.notifications_bar.display_for_auth (auth_string,
                                                                                        (owned) auth_func,
                                                                                        (owned) dismiss_func,
                                                                                        need_username);
        }

        public void delete () {
            config.delete ();
        }

        public void save () {
            config.save ();
        }

        construct {
            thumbnailer = new Connections.Thumbnailer (this);

            show.connect (() => { thumbnailer.update_thumbnail (); });

            notify.connect (save);
        }

        public abstract void connect_it ();
        public abstract void disconnect_it ();
    }
}
