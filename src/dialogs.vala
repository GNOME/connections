/* dialogs.vala
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
 * Author: Marek Kasik <mkasik@redhat.com>
 *
 */

namespace Connections {
    [GtkTemplate (ui = "/org/gnome/Connections/ui/dialog.ui")]
    private class DialogsWindow : Hdy.Window {
        private bool change_verification;
        private string certificate_fingerprint;
        private string connection_name;
        private bool certificate_verification_show_flag;
        private bool certificate_change_verification_show_flag;
        private bool authentication_show_flag;
        private bool need_username;
        private bool need_password;
        private bool need_domain;

        [GtkChild]
        public unowned Gtk.Stack content_stack;

        [GtkChild]
        public unowned Gtk.Stack header_stack;

        [GtkChild]
        private unowned Gtk.Label text_label;

        [GtkChild]
        private unowned Gtk.Label fingerprint_value;

        [GtkChild]
        private unowned Gtk.Label certificate_change_text_label;

        [GtkChild]
        private unowned Gtk.Button connect_button;

        [GtkChild]
        private unowned Gtk.Switch delete_local_certificate_switch;

        [GtkChild]
        private unowned Gtk.Image show_password_icon;

        [GtkChild]
        private unowned Gtk.Entry username_entry;

        [GtkChild]
        private unowned Gtk.Entry password_entry;

        [GtkChild]
        private unowned Gtk.Entry domain_entry;

        [GtkChild]
        private unowned Gtk.Label authentication_text;

        [GtkChild]
        private unowned Hdy.HeaderBar dialog_headerbar;

        [GtkChild]
        private unowned Hdy.ActionRow username_row;

        [GtkChild]
        private unowned Hdy.ActionRow password_row;

        [GtkChild]
        private unowned Hdy.ActionRow domain_row;

        private Mutex mutex;

        construct {
            valign = Gtk.Align.START;
            halign = Gtk.Align.CENTER;

            certificate_verification_show_flag = false;
            certificate_change_verification_show_flag = false;
            authentication_show_flag = false;
            mutex = Mutex ();

            try {
                var style_provider = new Gtk.CssProvider ();
                var css_style = "button#authenticate_button { border-radius: 0px; border-bottom: 0px; border-right: 0px; }
                                 button#cancel_button { border-radius: 0px; border-bottom: 0px; border-left: 0px; border-right: 0px; }";
                style_provider.load_from_data (css_style, css_style.length);
                Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                          style_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (GLib.Error error) {
                warning ("Failed to load CSS: %s", error.message);
            }

            Timeout.add (50, check_show_flags);

            delete_event.connect (hide_when_delete);
        }

        bool check_show_flags () {
            bool scvf, sccvf, saf;

            mutex.lock ();

            scvf = certificate_verification_show_flag;
            if (certificate_verification_show_flag)
                certificate_verification_show_flag = false;

            sccvf = certificate_change_verification_show_flag;
            if (certificate_change_verification_show_flag)
                certificate_change_verification_show_flag = false;

            saf = authentication_show_flag;
            if (authentication_show_flag)
                authentication_show_flag = false;

            mutex.unlock ();

            if (scvf) {
                show_certificate_verification_real ();
            }

            if (sccvf) {
                show_certificate_change_verification_real ();
            }

            if (saf) {
                show_authentication_real ();
            }

            return true;
        }

        string split_fingerprint (string fingerprint) {
            string[] fp = fingerprint.split (":");
            string[] tmpv = {};

            if (fp.length == 32) {
                for (var i = 0 ; i < 4 ; i++) {
                    tmpv += string.joinv (":", fp[i * 8: i * 8 + 4]) + "   " + string.joinv (":", fp[i * 8 + 4: i * 8 + 8]);
                }
                string fp2 = string.joinv ("\n", tmpv).up ();

                return fp2;
            } else {
                return "";
            }
        }

        public delegate void CertificateVerifyFunc (bool verified);
        CertificateVerifyFunc certificate_verify_func;

        private void show_certificate_verification_real () {
            mutex.lock ();

            text_label.label = _("Connecting to “%s” for the first time. To be sure you're connecting to the machine it claims to be, please verify the fingerprints match. This process is only done once.").printf (connection_name);

            fingerprint_value.label = split_fingerprint (certificate_fingerprint);

            mutex.unlock ();

            content_stack.set_visible_child_name ("certificate-verification");
            header_stack.set_visible_child_name ("verify-button-page");
            content_stack.show ();
            header_stack.show ();
            dialog_headerbar.show ();
            present ();
        }

        /* It is safe to call this from other threads as is usually the case. */
        public void show_certificate_verification (string name,
                                                   string fingerprint,
                                                   owned CertificateVerifyFunc? certificate_verify_func_in) {
            mutex.lock ();

            change_verification = false;
            connection_name = name.dup ();
            certificate_fingerprint = fingerprint.dup ();
            certificate_verify_func = certificate_verify_func_in;
            certificate_verification_show_flag = true;

            mutex.unlock ();
        }

        public delegate void CertificateChangeVerifyFunc (bool verified);
        CertificateChangeVerifyFunc certificate_change_verify_func;
        public void show_certificate_change_verification_real () {
            mutex.lock ();

            certificate_change_text_label.label = _("The remote server “%s” certificate doesn't match local copy. It may be someone's pretending to be the server.").printf (connection_name);

            fingerprint_value.label = split_fingerprint (certificate_fingerprint);

            mutex.unlock ();

            content_stack.set_visible_child_name ("certificate-change-verification");
            header_stack.set_visible_child_name ("connect-button-page");
            content_stack.show ();
            header_stack.show ();
            dialog_headerbar.show ();
            present ();
        }

        /* It is safe to call this from other threads as is usually the case. */
        public void show_certificate_change_verification (string name,
                                                          string fingerprint,
                                                          owned CertificateChangeVerifyFunc? certificate_change_verify_func_in) {
            mutex.lock ();

            change_verification = true;
            connection_name = name.dup ();
            certificate_fingerprint = fingerprint.dup ();
            certificate_change_verify_func = certificate_change_verify_func_in;
            certificate_change_verification_show_flag = true;

            mutex.unlock ();
        }

        public delegate void AuthenticationFunc (string username,
                                                 string password,
                                                 string domain);
        AuthenticationFunc authentication_func;
        public void show_authentication_real () {
            mutex.lock ();

            username_row.set_visible (need_username);
            password_row.set_visible (need_password);
            domain_row.set_visible (need_domain);

            authentication_text.label = _("The remote server “%s” requires a username and password to continue to connect.").printf (connection_name);

            mutex.unlock ();

            content_stack.set_visible_child_name ("authentication");
            content_stack.show ();
            dialog_headerbar.hide ();
            present ();
        }

        /* It is safe to call this from other threads as is usually the case. */
        public void show_authentication (string                    name,
                                         bool                      need_username_in,
                                         bool                      need_password_in,
                                         bool                      need_domain_in,
                                         owned AuthenticationFunc? authentication_func_in) {
            mutex.lock ();

            need_username = need_username_in;
            need_password = need_password_in;
            need_domain = need_domain_in;
            connection_name = name.dup ();
            authentication_func = authentication_func_in;
            authentication_show_flag = true;

            mutex.unlock ();
        }

        [GtkCallback]
        private void cancel_connection () {
            mutex.lock ();

            if (change_verification) {
                if (certificate_change_verify_func != null)
                    certificate_change_verify_func (false);
            } else {
                if (certificate_verify_func != null)
                    certificate_verify_func (false);
            }

            mutex.unlock ();

            dismiss ();
        }

        [GtkCallback]
        private void verify_button_clicked_cb () {
            mutex.lock ();

            if (change_verification) {
                if (certificate_change_verify_func != null)
                    certificate_change_verify_func (true);
            } else {
                if (certificate_verify_func != null)
                    certificate_verify_func (true);
            }

            mutex.unlock ();

            dismiss ();
        }

        [GtkCallback]
        private void connect_button_clicked_cb () {
            show_certificate_verification_real ();
        }

        [GtkCallback]
        private void delete_local_certificate_switch_changed () {
            connect_button.sensitive = delete_local_certificate_switch.active;
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.Widget widget, Gdk.EventKey event) {
            if (event.keyval == Gdk.Key.Escape) {
                cancel_connection ();
                return true;
            }

            return false;
        }

        [GtkCallback]
        private void show_password_button_clicked () {
            if (password_entry.visibility) {
                show_password_icon.icon_name = "view-reveal-symbolic";
                password_entry.visibility = false;
            } else {
                show_password_icon.icon_name = "user-not-tracked-symbolic";
                password_entry.visibility = true;
            }
        }

        [GtkCallback]
        private void cancel_authentication_clicked () {
            mutex.lock ();

            hide ();

            if (authentication_func != null) {
                authentication_func ("", "", "");
                authentication_func = null;
            }

            mutex.unlock ();

            dismiss ();
        }

        [GtkCallback]
        private void authenticate_button_clicked () {
            mutex.lock ();

            hide ();

            if (authentication_func != null) {
                authentication_func (username_entry.text, password_entry.text, domain_entry.text);
                authentication_func = null;
            }

            mutex.unlock ();

            dismiss ();
        }

        [GtkCallback]
        private void on_username_entry_activated () {
            authenticate_button_clicked ();
        }

        [GtkCallback]
        private void on_password_entry_activated () {
            authenticate_button_clicked ();
        }

        [GtkCallback]
        private void on_domain_entry_activated () {
            authenticate_button_clicked ();
        }

        private void dismiss () {
            hide ();
            username_entry.text = "";
            password_entry.text = "";
            domain_entry.text = "";
            delete_local_certificate_switch.set_active (false);
        }

        private bool hide_when_delete () {
            cancel_connection ();
            return true;
        }
    }
}
