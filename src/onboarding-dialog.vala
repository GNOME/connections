/* onboarding-dialog.vala
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
using Hdy;

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/onboarding-dialog.ui")]
    private class OnboardingDialog : Hdy.Window {
        [GtkChild]
        private unowned Carousel paginator;
        [GtkChild]
        private unowned Button go_back_button;
        [GtkChild]
        private unowned Button go_next_button;
        [GtkChild]
        private unowned Button close_button;

        private GLib.List<unowned OnboardingDialogPage> pages;

        construct {
            pages = new GLib.List<unowned OnboardingDialogPage> ();

            OnboardingDialogPage? onboarding_page = null;
            foreach (var page in paginator.get_children ()) {
                assert (page is OnboardingDialogPage);

                onboarding_page = page as OnboardingDialogPage;
                pages.append (onboarding_page);
            }

            on_position_changed ();
        }

        public OnboardingDialog (Window window) {
            set_transient_for (window);
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.Widget widget, Gdk.EventKey event) {
            if (event.keyval == Gdk.Key.Escape) {
                close ();
                return true;
            }

            return false;
        }

        [GtkCallback]
        private void on_next_button_clicked () {
            var index = (int) Math.round (paginator.position) + 1;
            if (index >= pages.length ())
                return;

            paginator.scroll_to (pages.nth_data (index));
        }

        [GtkCallback]
        private void on_back_button_clicked () {
            var index = (int) Math.round (paginator.position) - 1;
            if (index < 0)
                return;

            paginator.scroll_to (pages.nth_data (index));
        }

        [GtkCallback]
        private void on_position_changed () {
            var position = (int)paginator.position;

            bool is_first_page = (position == 0);
            bool is_last_page = (position == (pages.length () - 1));

            go_back_button.visible = !is_first_page;
            go_next_button.visible = !is_last_page;

            close_button.visible = is_first_page || is_last_page;
            close_button.label = is_first_page ? _("_No Thanks") : _("_Close");
        }
    }
}
