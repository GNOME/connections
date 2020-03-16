/* display-view.vala
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

using Gtk;
using Gdk;

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/display-view.ui")]
    private class DisplayView : Gtk.Box {
        [GtkChild]
        private EventBox event_box;

        [GtkChild]
        private Stack stack;

        [GtkChild]
        private Widget loading; 

        [GtkChild]
        private Widget display_widget; 

        private Connections.Display _display;
        private Connections.Display display {
            get { return _display; }
            set {
                if (_display != null) {
                    _display.disconnect (show_display_id);
                    show_display_id = 0;
                }

                _display = value;
                if (_display == null)
                    return;

                show_display_id = _display.show.connect (() => {
                    show_display (); 
                });
            }
        }

        private ulong show_display_id;

        private bool can_grab_mouse {
            get {
                return display != null ? display.can_grab_mouse : false;
            }
        }
        private bool mouse_grabbed {
            get {
                return display != null ? display.mouse_grabbed : false;
            }
        }
        private bool keyboard_grabbed {
            get {
                return display != null ? display.keyboard_grabbed : false;
            }
        }
        private ulong can_grab_mouse_id;
        private ulong mouse_grabbed_id;
        private ulong keyboard_grabbed_id;
        private ulong cursor_id;

        construct {
            event_box.set_events (EventMask.POINTER_MOTION_MASK | EventMask.SCROLL_MASK);
        }

        private void remove_display () {
            if (event_box.get_child () == null)
                return;

            if (mouse_grabbed_id != 0) {
                display.disconnect (mouse_grabbed_id);
                mouse_grabbed_id = 0;
            }

            if (can_grab_mouse_id != 0) {
                display.disconnect (can_grab_mouse_id);
                can_grab_mouse_id = 0;
            }

            if (keyboard_grabbed_id != 0) {
                display.disconnect (keyboard_grabbed_id);
                keyboard_grabbed_id = 0;
            }
            display = null;

            var widget = event_box.get_child ();
            if (cursor_id != 0) {
                widget.get_window ().disconnect (cursor_id);
                cursor_id = 0;
            }

            if (widget != null)
                event_box.remove (widget);
        }

        public void replace_display (Connections.Display display) {
            if (event_box.get_child () != null)
                remove_display ();

            this.display = display;

            var widget = display.get_widget ();
            widget.set_events (widget.get_events () & ~EventMask.POINTER_MOTION_MASK);
            event_box.add (widget);
            event_box.show_all ();

            ulong draw_id = 0;
            draw_id = widget.draw.connect (() => {
                widget.disconnect (draw_id);

                cursor_id = widget.get_window ().notify["cursor"].connect (() => {
                   event_box.get_window ().set_cursor (widget.get_window ().cursor);
                });

                return false;
            });
        }

        public void connect_to (Machine machine) {
            if (machine.uri.contains ("vnc")) {
                replace_display (new VncDisplay ());
                display.connect_to (machine);
            }

            machine.update_thumbnail (display);
        }

        private void show_display () {
            stack.set_visible_child (display_widget);

            display.get_widget ().grab_focus ();
        }

        [GtkCallback]
        private bool on_event_box_event (Gdk.Event event) {
            if (event.type == EventType.GRAB_BROKEN)
                return false;

            if (event_box.get_child () != null)
                event_box.get_child ().event (event);

            return false;
        } 
    }
}
