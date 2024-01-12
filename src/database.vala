/* database.vala
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
    private class Database : Object {
        private static Database database;
        public static Database get_default () {
            if (database == null)
                database = new Database ();

            return database;
        }

        protected KeyFile keyfile = new KeyFile ();
        protected string? filename = Path.build_filename (Environment.get_user_config_dir (),
                                                          "connections.db");

        private void load_keyfile () {
            try {
                File file = File.new_for_path (filename);
                file.create (FileCreateFlags.PRIVATE);
            } catch (GLib.IOError.EXISTS error) {
                // This means that the database exists. Let's use it!
            } catch (GLib.Error error) {
                warning ("Failed to load database file: %s", error.message);

                return;
            }

            try {
                keyfile.load_from_file (filename,
                                        KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS);
            } catch (GLib.Error error) {
                warning ("Failed to load database: %s", error.message);
            }
        }

        private bool save_keyfile () {
            try {
                return FileUtils.set_contents (filename, keyfile.to_data (null));
            } catch (GLib.Error error) {
                warning ("Failed to save database: %s", error.message);

                return false;
            }
        }

        private bool get_boolean (string group, string key) {
            try {
                return keyfile.get_boolean (group, key);
            } catch (GLib.KeyFileError error) {
                debug ("Key %s not found in group %s: %s", key, group, error.message);

                return false; // DEFAULT_VALUE
            }
        }

        private string get_string (string group, string key) {
            try {
                return keyfile.get_string (group, key);
            } catch (GLib.KeyFileError error) {
                debug ("Key %s not found in group %s: %s", key, group, error.message);

                return ""; // DEFAULT_VALUE
            }
        }

        private void load_properties (Connection connection) {
            try {
                foreach (var property_name in keyfile.get_keys (connection.uuid))
                    load_property (connection, property_name);
            } catch (GLib.Error error) {
                warning ("Failed to load connection properties: %s".printf (error.message));
            }
        }

        private void load_property (Connection connection, string property_name) {
            var property = connection.get_class ().find_property (property_name);
            if (property == null)
                return;

            var value = GLib.Value (property.value_type);
            try {
                if (value.type () == typeof (string))
                    value = get_string (connection.uuid, property_name);
                if (value.type () == typeof (bool))
                    value = get_boolean (connection.uuid, property_name);
                if (value.type () == typeof (int))
                    value = keyfile.get_integer (connection.uuid, property_name);
                if (value.type () == typeof (uint64))
                    value = keyfile.get_uint64 (connection.uuid, property_name);
                if (value.type () == typeof (int64))
                    value = keyfile.get_int64 (connection.uuid, property_name);
            } catch (GLib.Error error) {
            }

            connection.set_property (property_name, value);
        }

        public void save_property (Connection connection, string property_name) {
            load_keyfile ();

            var value = GLib.Value (connection.get_class ().find_property (property_name).value_type);

            connection.get_property (property_name, ref value);

            if (value.type () == typeof (string)) {
                var vstring = (value.get_string () == null ? "" : value.get_string ());
                keyfile.set_string (connection.uuid, property_name, vstring);
            } else if (value.type () == typeof (bool))
                keyfile.set_boolean (connection.uuid, property_name, value.get_boolean ());
            else if (value.type () == typeof (int))
                keyfile.set_integer (connection.uuid, property_name, value.get_int ());
            else if (value.type () == typeof (uint64))
                keyfile.set_uint64 (connection.uuid, property_name, value.get_uint64 ());
            else if (value.type () == typeof (int64))
                keyfile.set_int64 (connection.uuid, property_name, value.get_int64 ());
            else
                warning ("Unhadled property %s type, value: %s".printf (property_name,
                                                                        value.strdup_contents ()));

            save_keyfile ();
        }

        public List<Connections.Connection> get_connections () {
            load_keyfile ();

            List<Connections.Connection >? connections = new List<Connections.Connection> ();
            foreach (var uuid in keyfile.get_groups ()) {
                var connection = get_connection (uuid);
                if (connection != null)
                    connections.append (connection);
            }

            return connections;
        }

        public Connection? get_connection (string uuid) {
            load_keyfile ();

            if (!keyfile.has_group (uuid))
                return null;

            Connection? connection = null;
            var protocol = get_string (uuid, "protocol");
            switch (protocol) {
/*
                case "vnc":
                    connection = new VncConnection (uuid);
                    break;
*/
                case "rdp":
                    connection = new RdpConnection (uuid);
                    break;
                default:
                    debug ("Unknown protocol defined for %s", uuid);
                    break;
            }


            if (connection == null)
                return null;

            load_properties (connection);

            return connection;
        }

        public Connection add_connection (string _uri) {
            Connection? connection = null;

            var uri = Xml.URI.parse (_uri);
            switch (uri.scheme) {
/*
                case "vnc":
                    connection = new VncConnection.from_uri (_uri);
                    break;
*/
                case "rdp":
                    connection = new RdpConnection.from_uri (_uri);
                    break;
                default:
                    debug ("Failed to add '%s': unknown protocol", _uri);
                    break;
            }

            connection.save ();

            return connection;
        }

        public void delete_connection (Connection connection) {
            load_keyfile ();
            try {
                keyfile.remove_group (connection.uuid);
            } catch (GLib.Error error) {
                warning ("Failed to delete '%s': %s", connection.uuid, error.message);
            }

            save_keyfile ();
        }
    }
}
