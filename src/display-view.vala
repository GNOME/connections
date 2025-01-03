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
        private unowned EventBox event_box;

        [GtkChild]
        private unowned Stack stack;

        [GtkChild]
        private unowned Label size_label;
        [GtkChild]
        private unowned Button escape_fullscreen_button;

        private Connection? connection;

        private ulong show_display_id;

        construct {
            event_box.set_events (EventMask.POINTER_MOTION_MASK |
                                  EventMask.SCROLL_MASK |
                                  EventMask.SMOOTH_SCROLL_MASK);
        }

        private void remove_display () {
            var widget = event_box.get_child ();
            if (widget != null)
                event_box.remove (widget);

            if (connection == null)
                return;

            connection.dispose_display ();
            connection = null;
        }

        public void replace_display (Connection connection) {
            if (event_box.get_child () == connection.widget)
                return;

            remove_display ();

            this.connection = connection;
            var display = connection.widget;

            display.set_events (display.get_events () & ~EventMask.POINTER_MOTION_MASK);
            event_box.add (display);
            event_box.show_all ();

            ulong draw_id = 0;
            draw_id = display.draw.connect (() => {
                display.disconnect (draw_id);

                /*cursor_id = display.get_window ().notify["cursor"].connect (() => {
                   event_box.get_window ().set_cursor (display.get_window ().cursor);
                });*/

                return false;
            });
        }

        public void connect_to (Connection connection) {
            stack.set_visible_child_name ("loading");
            switch_to (connection);
            connection.connect_it ();
        }

        public void switch_to (Connection connection) {
            if (show_display_id != 0) {
                this.connection.disconnect (show_display_id);
                show_display_id = 0;
            }

            replace_display (connection);

            show_display_id = connection.show.connect (show_display);
        }

        private void show_display () {
            stack.set_visible_child_name ("display");
        }

        [GtkCallback]
        private bool on_event_box_scroll_event (Gdk.EventScroll scroll_event) {
            if (scroll_event.type == EventType.GRAB_BROKEN)
                return false;

            if (event_box.get_child () != null) {
                if ((event_box.get_child ().get_events () & EventMask.SMOOTH_SCROLL_MASK) == 0) {
                    if (scroll_event.delta_x >= 0.5)
                        scroll_event.direction = ScrollDirection.RIGHT;
                    else if (scroll_event.delta_x <= -0.5)
                        scroll_event.direction = ScrollDirection.LEFT;

                    if (scroll_event.delta_y >= 0.5)
                        scroll_event.direction = ScrollDirection.DOWN;
                    else if (scroll_event.delta_y <= -0.5)
                        scroll_event.direction = ScrollDirection.UP;
                }

                event_box.get_child ().event (scroll_event);
            }

            return false;
        }

        [GtkCallback]
        private bool on_event_box_event (Gdk.Event event) {
            if (event.type == EventType.GRAB_BROKEN ||
                event.type == EventType.SCROLL)
                return false;

            if (event_box.get_child () != null)
                event_box.get_child ().event (event);

            return false;
        } 

        private uint size_label_timeout;
        private int width = -1;
        private int height = -1;
        [GtkCallback]
        private void on_size_allocate (Gtk.Allocation allocation) {
            if (width == allocation.width && height == allocation.height) {
                return;
            }

            width = allocation.width;
            height = allocation.height;

            // Translators: Showing size of widget as WIDTH×HEIGHT here.
            size_label.label = _("%d×%d").printf (allocation.width, allocation.height);

            Idle.add (() => {
                size_label.visible = true;

                if (size_label_timeout != 0) {
                    Source.remove (size_label_timeout);
                    size_label_timeout = 0;
                }

                size_label_timeout = Timeout.add_seconds (3, () => {
                    size_label.visible = false;
                    size_label_timeout = 0;

                    return false;
                });

                return false;
            });
        }

        [GtkCallback]
        private void on_escape_fullscreen_button_clicked () {
            Application.application.main_window.fullscreened = false;
            escape_fullscreen_button.visible = false;
        }

        public override bool motion_notify_event (Gdk.EventMotion event) {
            if (!Application.application.main_window.fullscreened)
                return false;

            escape_fullscreen_button.visible = (event.y < 40);

            return base.motion_notify_event (event);
        }
    }
}
