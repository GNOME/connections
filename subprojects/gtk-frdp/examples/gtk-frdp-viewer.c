/* gtk-frdp-viewer.c
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

#include <gtk-frdp.h>

static void
on_rdp_auth_failure (GObject     *source_object,
                     const gchar *message,
                     gpointer     user_data)
{
  g_print ("-> %s\n", message);

  g_application_quit (user_data);
}

static void
on_activate (GtkApplication *app)
{
  GtkWindow *window;
  GtkWidget *display;

  g_assert (GTK_IS_APPLICATION (app));

  /* Get the current window or create one if necessary. */
  window = gtk_application_get_active_window (app);
  if (window == NULL)
    window = g_object_new (GTK_TYPE_APPLICATION_WINDOW,
                           "application", app,
                           NULL);

  display = frdp_display_new ();

  g_signal_connect (display,
                    "rdp-auth-failure",
                    G_CALLBACK (on_rdp_auth_failure),
                    app);

  gtk_container_add (GTK_CONTAINER (window), display);
  gtk_widget_show (display);

  frdp_display_open_host (FRDP_DISPLAY (display), "109.168.97.222", 3389);
  g_object_set (display,
                "username", "demo2",
                "password", "D3m02014*Test",
                NULL);


  gtk_window_present (window);
}

int
main (int   argc,
      char *argv[])
{
  g_autoptr(GtkApplication) app = NULL;
  int ret;

  app = gtk_application_new ("org.gnome.GtkFrdpViewer", G_APPLICATION_FLAGS_NONE);

  g_signal_connect (app, "activate", G_CALLBACK (on_activate), NULL);

  ret = g_application_run (G_APPLICATION (app), argc, argv);

  return ret;
}
