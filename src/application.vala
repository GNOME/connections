/* application.vala
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

using Config;

namespace Connections {
    private class Application : Gtk.Application {
        public static Application application;

        public ListStore model;

        private List<Connections.Window> windows;
        public unowned Window main_window {
            get { return (windows.length () > 0) ? windows.data : null; }
        }

        construct {
            windows = new List<Connections.Window> ();
            model = new GLib.ListStore (typeof (Connections.Connection));
        }

        public Application () {
            application = this;

            application_id = Config.APPLICATION_ID;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE | ApplicationFlags.HANDLES_OPEN;

            var action = new GLib.SimpleAction ("help", null);
            action.activate.connect (show_help);
            add_action (action);

            action = new GLib.SimpleAction ("about", null);
            action.activate.connect (show_about_dialog);
            add_action (action);

            action = new GLib.SimpleAction ("quit", null);
            action.activate.connect (quit_app);
            add_action (action);
        }

        private void show_help () {
            try {
                Gtk.show_uri_on_window (main_window,
                              "help:gnome-connections",
                              Gtk.get_current_event_time ());
            } catch (GLib.Error error) {
                warning ("Failed to display help: %s", error.message);
            }
        }

        private void show_about_dialog () {
            string[] authors = {
                "Felipe Borges <felipeborges@gnome.org>"
            };
            string[] artists = {
                "Jakub Steiner <jsteiner@redhat.com>"
            };

            Gtk.show_about_dialog (main_window,
                                   "artists", artists,
                                   "authors", authors,
                                   "translator-credits", _("translator-credits"),
                                   "comments", _("A remote desktop client for the GNOME desktop environment"),
                                   "copyright", "\xc2\xa9 2020 Red Hat, Inc.",
                                   "license-type", Gtk.License.GPL_3_0,
                                   "program-name", _("Connections"),
                                   "wrap-license", true,
                                   "logo-icon-name", application_id,
                                   "version", Config.VERSION);
        }

        public override void activate () {
            base.activate ();

            if (main_window != null) {
                return;
            }

            add_new_window ();

            load_connections ();
        }

        public Window add_new_window () {
            var window = new Connections.Window (this);

            windows.append (window);
            window.present ();

            return window;
        }

        public void add_connection (string uri) {
            var connection = Database.get_default ().add_connection (uri);
            if (connection == null)
                return;

            model.insert (0, connection);
        }

        public void add_connection_from_file (string file_path) {
            Connection? connection = null;
            var mime_type = GLib.ContentType.guess(file_path, null, null);

            switch (mime_type) {
                case "application/x-vnc":
                    connection = new VncConnection.from_vnc_file (file_path);
                    connection.protocol = Connection.Protocol.VNC;
                    break;
                default:
                    warning ( _ ("Couldn’t open file of unknown mime type %s".printf (mime_type)));
                    break;
            }

            if (connection == null)
                return;

            model.insert (0, connection);
            connection.save ();
        }

        public void remove_connection (Connection connection) {
            Notification.OKFunc undo = () => {
                debug ("Connection deletion cancelled by user. Re-adding to view");
                model.insert (0, connection);
            };

            Notification.DismissFunc really_remove = () => {
                debug ("User did not cancel deletion. Deleting now...");
                Database.get_default ().delete_connection (connection);
            };

            for (int i = 0; i < model.get_n_items (); i++) {
                if ((model.get_item (i) as Connection) == connection) {
                    model.remove (i);

                    break;
                }
            }

            var message = _("Connection to “%s” has been deleted").printf (connection.display_name);
            main_window.notifications_bar.display_for_action (message,
                                                              _("Undo"),
                                                              (owned) undo,
                                                              (owned) really_remove);
        }

        public void load_connections () {
            var db = new Database ();
            foreach (var connection in db.get_connections ()) {
                model.append (connection);
            }
        }

        public void open_connection (Connection connection) {
            main_window.open_connection (connection);
        }

        public override void open(File[] files, string hint)
        {
            activate();

                foreach (var file in files) {
                    add_connection_from_file(file.get_path());
                }
        }

        public override void shutdown () {
            base.shutdown ();

            for (int idx = 0; idx < model.get_n_items (); idx++) {
                var connection = (Connection)model.get_item (idx);

                if (connection.connected)
                    connection.disconnect_it ();
            }
        }

        public void quit_app () {
            foreach (var window in windows)
                window.hide ();

            quit ();
        }

        static string[] opt_uris;
        static string opt_file_import_uri;
        const OptionEntry[] options = {
            { "", 0, 0, GLib.OptionArg.STRING_ARRAY, ref opt_uris, N_ ("URL to connect"), null },
            { "file", 'F', 0, GLib.OptionArg.FILENAME, ref opt_file_import_uri, N_ ("Open .vnc or .rdp file at the given PATH"), "PATH" },
            { null }
        };
        public override int command_line (GLib.ApplicationCommandLine cmdline) {
            opt_uris = null;
            opt_file_import_uri = null;

            var parameter_string = _("A remote desktop client for the GNOME desktop environment");
            var opt_context = new OptionContext ("— " + parameter_string);
            opt_context.add_main_entries (options, null);

            try {
                string[] args1 = cmdline.get_arguments ();
                unowned string[] args2 = args1;
                opt_context.parse (ref args2);
            } catch (GLib.OptionError error) {
                cmdline.printerr ("%s\n", error.message);

                return 1;
            }

            if (opt_uris != null && opt_uris.length > 1) {
                cmdline.printerr (_("Too many command-line arguments specified.\n"));

                return 1;
            }
            activate ();

            if (opt_uris != null) {
                var uri = opt_uris[0];

                (new Connections.Assistant (main_window, uri)).run ();
            }

            if (opt_file_import_uri != null) {
                add_connection_from_file (opt_file_import_uri);
            }

            return 0;
        }
    }
}
