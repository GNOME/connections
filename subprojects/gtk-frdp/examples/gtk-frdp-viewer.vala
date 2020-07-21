/* gtk-frdp-viewer.vala
 *
 * Copyright (C) 2018 Felipe Borges <felipeborges@gnome.org>
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
 */

using Gtk;
using Frdp;

private class GtkRdpViewer.Application: Gtk.Application {
    public const int DEFAULT_RDP_PORT = 3389;

    private Gtk.ApplicationWindow window;
    private Frdp.Display display;

    static string option_connect_address;
    const OptionEntry[] options = {
      { "connect", 0, 0, OptionArg.STRING, ref option_connect_address, "Connect to address", null },
      { null }
    };

    public Application () {
        application_id = "org.gnome.GtkRdpViewer";
        flags |= ApplicationFlags.HANDLES_COMMAND_LINE;
    }

    protected override void activate () {
        if (window != null)
            return;

        window = new Gtk.ApplicationWindow (this);
        display = new Frdp.Display();

        window.add(display);
        window.show_all ();
    }

    protected override int command_line (GLib.ApplicationCommandLine cmdline) {
        option_connect_address = null;

        var opt_context = new OptionContext ("A RDP Viewer");
        opt_context.add_main_entries (options, null);
        opt_context.set_help_enabled (true);

        try {
            string[] args1 = cmdline.get_arguments ();
            unowned string[] args2 = args1;

            opt_context.parse (ref args2);
        } catch (OptionError error) {
            cmdline.printerr ("%s\n", error.message);

            return 1;
        }

        if (option_connect_address != null) {
            connect_to (option_connect_address);
        }

        return 0;
    }

    private void connect_to (string address) {
        activate ();

        display.open_host (address, DEFAULT_RDP_PORT);
    }
}

public int main (string[] args) {
	var app = new GtkRdpViewer.Application ();

    var exit_status = app.run (args);

    return exit_status;
}
