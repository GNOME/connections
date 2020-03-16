/* machine.vala
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
    private class Machine : Object {
        private MachineConfig config;

        public enum Protocol {
            UNKNOWN,
            VNC,
            SPICE,
            RDP,
            SSH;

            public string to_string () {
                switch (this) {
                    case VNC:
                        return "vnc";
                    case SPICE:
                        return "spice";
                    case RDP:
                        return "rdp";
                    case SSH:
                        return "ssh";
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
                    case "spice":
                        return SPICE;
                    case "rdp":
                        return RDP;  
                    case "ssh":
                       return SSH;
                    case "unknown":
                    default:
                       return UNKNOWN;
                }
            }
        }

        public string uri {
            owned get {
                return @"$protocol://$host:$port";
            }

            set {
                var address = Xml.URI.parse (value);

                protocol = protocol.from_string (address.scheme);
                host = address.server;
                port = address.port <= 0 ? 5900 : address.port;
            }
        }

        public string host;
        public int port;
        public Protocol protocol;

        public string display_name;

        public bool deleted { get; private set; }

        public Thumbnailer thumbnailer;
        public Gdk.Pixbuf? thumbnail { set; get; }

        construct {
            config = new MachineConfig (this);
        }

        public Machine.from_uri (string uri) {
            this.uri = uri;

            thumbnailer = new Connections.Thumbnailer (this);
        }

        public void delete () {
            config.delete ();

            Application.application.remove_machine (this);
        }

        public void save () {
            config.save ();
        }

        public void update_thumbnail (Display display) {
            thumbnailer.update_thumbnail (display);
        }
    }
}
