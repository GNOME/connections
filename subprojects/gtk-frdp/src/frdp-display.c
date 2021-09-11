/* frdp-display.c
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

#include "frdp-display.h"

#include "frdp-session.h"

struct _FrdpDisplayPrivate
{
  FrdpSession *session;
};

G_DEFINE_TYPE_WITH_PRIVATE (FrdpDisplay, frdp_display, GTK_TYPE_DRAWING_AREA)

enum
{
  PROP_O = 0,
  PROP_USERNAME,
  PROP_PASSWORD,
  PROP_SCALING
};

enum
{
  RDP_CONNECTED,
  RDP_DISCONNECTED,
  RDP_NEEDS_AUTHENTICATION,
  RDP_AUTH_FAILURE,
  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

static gboolean
frdp_display_is_initialized (FrdpDisplay *self)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);

  return priv->session != NULL && frdp_display_is_open (self);
}

static gboolean
frdp_display_key_press_event (GtkWidget   *widget,
                              GdkEventKey *key)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  guint16 keycode = key->hardware_keycode;

  if (!frdp_display_is_initialized (self))
    return TRUE;

  switch (key->type) {
    case GDK_KEY_PRESS:
      frdp_session_send_key (priv->session, FRDP_KEY_EVENT_PRESS, keycode);
      break;
    case GDK_KEY_RELEASE:
      frdp_session_send_key (priv->session, FRDP_KEY_EVENT_RELEASE, keycode);
      break;
    default:
      g_warn_if_reached ();
      break;
  }

  return TRUE;
}

static gboolean
frdp_display_motion_notify_event (GtkWidget      *widget,
                                  GdkEventMotion *event)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);

  if (!frdp_display_is_initialized (self))
    return TRUE;

  frdp_session_mouse_event (priv->session,
                            FRDP_MOUSE_EVENT_MOVE,
                            event->x,
                            event->y);

  return TRUE;
}

static gboolean
frdp_display_button_press_event (GtkWidget      *widget,
                                 GdkEventButton *event)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  guint16 flags = 0;

  if (!frdp_display_is_initialized (self))
    return TRUE;

  if ((event->button < 1) || (event->button > 3))
    return FALSE;

  if ((event->type != GDK_BUTTON_PRESS) &&
      (event->type != GDK_BUTTON_RELEASE))
    return FALSE;

  if (event->type == GDK_BUTTON_PRESS)
    flags |= FRDP_MOUSE_EVENT_DOWN;
  switch(event->button) {
  case GDK_BUTTON_PRIMARY:
    flags |= FRDP_MOUSE_EVENT_BUTTON1;
    break;
  case GDK_BUTTON_MIDDLE:
    flags |= FRDP_MOUSE_EVENT_BUTTON3;
    break;
  case GDK_BUTTON_SECONDARY:
    flags |= FRDP_MOUSE_EVENT_BUTTON2;
    break;
  case 8:
    flags |= FRDP_MOUSE_EVENT_BUTTON4;
    break;
  case 9:
    flags |= FRDP_MOUSE_EVENT_BUTTON5;
    break;
  default:
    return FALSE;
  }

  frdp_session_mouse_event (priv->session,
                            flags,
                            event->x,
                            event->y);

  return TRUE;
}

static gboolean
frdp_display_scroll_event (GtkWidget      *widget,
                           GdkEventScroll *event)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  guint16 flags = FRDP_MOUSE_EVENT_WHEEL;

  if (!frdp_display_is_initialized (self))
    return TRUE;

  switch (event->direction) {
    case GDK_SCROLL_UP:
      flags = FRDP_MOUSE_EVENT_WHEEL;
      break;
    case GDK_SCROLL_DOWN:
      flags = FRDP_MOUSE_EVENT_WHEEL | FRDP_MOUSE_EVENT_WHEEL_NEGATIVE;
      break;
    case GDK_SCROLL_LEFT:
      flags = FRDP_MOUSE_EVENT_HWHEEL | FRDP_MOUSE_EVENT_WHEEL_NEGATIVE;
      break;
    case GDK_SCROLL_RIGHT:
      flags = FRDP_MOUSE_EVENT_HWHEEL;
      break;
    case GDK_SCROLL_SMOOTH:
    /* Calculate delta and decide which event we have
     * a delta X means horizontal, a delta Y means vertical scroll.
     * Fixes https://bugzilla.gnome.org/show_bug.cgi?id=675959
     */
    if (event->delta_x > 0.5)
      flags = FRDP_MOUSE_EVENT_HWHEEL;
    else if (event->delta_x < -0.5)
      flags = FRDP_MOUSE_EVENT_HWHEEL | FRDP_MOUSE_EVENT_WHEEL_NEGATIVE;
    else if (event->delta_y > 0.5)
      flags = FRDP_MOUSE_EVENT_WHEEL;
    else if (event->delta_y < -0.5)
      flags = FRDP_MOUSE_EVENT_WHEEL | FRDP_MOUSE_EVENT_WHEEL_NEGATIVE;
    else {
      g_debug ("scroll smooth unhandled");
      return FALSE;
    }
    break;
    default:
      return FALSE;
  }

  frdp_session_mouse_event (priv->session,
                            flags,
                            event->x,
                            event->y);

  return TRUE;
}

static gboolean
frdp_enter_notify_event (GtkWidget	       *widget,
                         GdkEventCrossing  *event)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  frdp_session_mouse_pointer(priv->session, TRUE);
  return TRUE;
}

static gboolean
frdp_leave_notify_event (GtkWidget	       *widget,
                         GdkEventCrossing  *event)
{
  FrdpDisplay *self = FRDP_DISPLAY (widget);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  frdp_session_mouse_pointer(priv->session, FALSE);
  return TRUE;
}

static void
frdp_display_auth_failure (GObject     *source_object,
                           const gchar *message,
                           gpointer     user_data)
{
  g_signal_emit (user_data, signals[RDP_AUTH_FAILURE], 0, message);
}

static void
frdp_display_disconnected (GObject  *source_object,
                           gpointer  user_data)
{
  FrdpDisplay *self = FRDP_DISPLAY (user_data);

  g_signal_emit (self, signals[RDP_DISCONNECTED], 0);

  g_debug ("rdp disconnected");
}

static void
frdp_display_open_host_cb (GObject      *source_object,
                           GAsyncResult *result,
                           gpointer      user_data)
{
  FrdpDisplay *self = FRDP_DISPLAY (user_data);
  FrdpSession *session = (FrdpSession*) source_object;
  gboolean success;
  GError  *error = NULL;

  success = frdp_session_connect_finish (session,
                                         result,
                                         &error);

  if (success) {
    g_signal_emit (self, signals[RDP_CONNECTED], 0);

    g_debug ("Connection established");
  } else {
    g_signal_emit (self, signals[RDP_DISCONNECTED], 0);

    g_debug ("Connection failed");
  }
}

static void
frdp_display_get_property (GObject      *object,
                           guint         property_id,
                           GValue       *value,
                           GParamSpec   *pspec)
{
  FrdpDisplay *self = FRDP_DISPLAY (object);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  FrdpSession *session = priv->session;
  gpointer str_property;

  switch (property_id)
    {
      case PROP_USERNAME:
        g_object_get (session, "username", &str_property, NULL);
        g_value_set_string (value, str_property);
        break;
      case PROP_PASSWORD:
        g_object_get (session, "password", &str_property, NULL);
        g_value_set_string (value, str_property);
        break;
      case PROP_SCALING:
        g_object_get (session, "scaling", &str_property, NULL);
        g_value_set_boolean (value, (gboolean)GPOINTER_TO_INT (str_property));
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
frdp_display_set_property (GObject      *object,
                           guint         property_id,
                           const GValue *value,
                           GParamSpec   *pspec)
{
  FrdpDisplay *self = FRDP_DISPLAY (object);
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);
  FrdpSession *session = priv->session;

  switch (property_id)
    {
      case PROP_USERNAME:
        g_object_set (session, "username", g_value_get_string (value), NULL);
        break;
      case PROP_PASSWORD:
        g_object_set (session, "password", g_value_get_string (value), NULL);
        break;
      case PROP_SCALING:
        frdp_display_set_scaling (self, g_value_get_boolean (value));
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
frdp_display_class_init (FrdpDisplayClass *klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

  gobject_class->get_property = frdp_display_get_property;
  gobject_class->set_property = frdp_display_set_property;

  widget_class->key_press_event = frdp_display_key_press_event;
  widget_class->key_release_event = frdp_display_key_press_event;
  widget_class->motion_notify_event = frdp_display_motion_notify_event;
  widget_class->button_press_event = frdp_display_button_press_event;
  widget_class->button_release_event = frdp_display_button_press_event;
  widget_class->scroll_event = frdp_display_scroll_event;
  widget_class->enter_notify_event = frdp_enter_notify_event;
  widget_class->leave_notify_event = frdp_leave_notify_event;

  g_object_class_install_property (gobject_class,
                                   PROP_USERNAME,
                                   g_param_spec_string ("username",
                                                        "username",
                                                        "username",
                                                        NULL,
                                                        G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_PASSWORD,
                                   g_param_spec_string ("password",
                                                        "password",
                                                        "password",
                                                        NULL,
                                                        G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_SCALING,
                                   g_param_spec_boolean ("scaling",
                                                         "scaling",
                                                         "scaling",
                                                         TRUE,
                                                         G_PARAM_READWRITE));

  signals[RDP_CONNECTED] = g_signal_new ("rdp-connected",
                                         G_TYPE_FROM_CLASS (klass),
                                         G_SIGNAL_RUN_LAST,
                                         0, NULL, NULL, NULL,
                                         G_TYPE_NONE, 0);

  signals[RDP_DISCONNECTED] = g_signal_new ("rdp-disconnected",
                                            G_TYPE_FROM_CLASS (klass),
                                            G_SIGNAL_RUN_LAST,
                                            0, NULL, NULL, NULL,
                                            G_TYPE_NONE, 0);

  signals[RDP_NEEDS_AUTHENTICATION] = g_signal_new ("rdp-needs-authentication",
                                                    G_TYPE_FROM_CLASS (klass),
                                                    G_SIGNAL_RUN_LAST,
                                                    0, NULL, NULL, NULL,
                                                    G_TYPE_NONE, 0);
  signals[RDP_AUTH_FAILURE] = g_signal_new ("rdp-auth-failure",
                                            G_TYPE_FROM_CLASS (klass),
                                            G_SIGNAL_RUN_LAST,
                                            0, NULL, NULL, NULL,
                                            G_TYPE_NONE, 1,
                                            G_TYPE_STRING);
}

static void
frdp_display_init (FrdpDisplay *self)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (self);

  gtk_widget_add_events (GTK_WIDGET (self),
                         GDK_POINTER_MOTION_MASK |
                         GDK_BUTTON_PRESS_MASK |
                         GDK_BUTTON_RELEASE_MASK |
                         GDK_SCROLL_MASK |
                         GDK_SMOOTH_SCROLL_MASK |
                         GDK_KEY_PRESS_MASK |
                         GDK_ENTER_NOTIFY_MASK |
                         GDK_LEAVE_NOTIFY_MASK);

  gtk_widget_set_can_focus (GTK_WIDGET (self), TRUE);

  priv->session = frdp_session_new (self);
}

/**
 * frdp_display_open_host:
 * @display: (transfer none): the RDP display widget
 * @host: (transfer none): the hostname or IP address
 * @port: the service name or port number
 *
 * Opens a TCP connection to the given @host litening on
 * @port.
 */
void
frdp_display_open_host (FrdpDisplay  *display,
                        const gchar  *host,
                        guint         port)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (display);

  g_return_if_fail (host != NULL);

  g_signal_connect (priv->session, "rdp-disconnected",
                    G_CALLBACK (frdp_display_disconnected),
                    display);
  g_signal_connect (priv->session, "rdp-auth-failure",
                    G_CALLBACK (frdp_display_auth_failure),
                    display);

  frdp_session_connect (priv->session,
                        host,
                        port,
                        NULL, // TODO: Cancellable
                        frdp_display_open_host_cb,
                        g_object_ref (display));

  g_debug ("Connecting to %s…", host);
}

/**
 * frdp_display_is_open:
 * @display: (transfer none): the RDP display widget
 *
 * Check if the connection for the display is currently open
 *
 * Returns: TRUE if open, FALSE if closing/closed
 */
gboolean
frdp_display_is_open (FrdpDisplay *display)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (display);

  return frdp_session_is_open (priv->session);
}

/**
 * frdp_display_close:
 * @display: (transfer none): the RDP display widget
 *
 * Request the closing of the RDP session.
 */
void
frdp_display_close (FrdpDisplay *display)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (display);

  frdp_session_close (priv->session);
}

/**
 * frdp_display_set_scaling:
 * @display: (transfer none): the RDP display widget
 * @scaling: TRUE to scale the desktop to fit, FALSE otherwise
 *
 * Set whether the remote desktop contents is automatically
 * scaled to fit the available widget size, or whether it will
 * be rendered at 1:1 size
 */
void
frdp_display_set_scaling (FrdpDisplay *display,
                          gboolean     scaling)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (display);

  g_object_set (priv->session, "scaling", scaling, NULL);

  if (scaling) {
    gtk_widget_set_size_request (GTK_WIDGET (display), -1, -1);

    gtk_widget_set_halign (GTK_WIDGET (display), GTK_ALIGN_FILL);
    gtk_widget_set_valign (GTK_WIDGET (display), GTK_ALIGN_FILL);
  } else {
    gtk_widget_set_halign (GTK_WIDGET (display), GTK_ALIGN_CENTER);
    gtk_widget_set_valign (GTK_WIDGET (display), GTK_ALIGN_CENTER);
  }

  gtk_widget_queue_draw_area (GTK_WIDGET (display), 0, 0,
                              gtk_widget_get_allocated_width (GTK_WIDGET (display)),
                              gtk_widget_get_allocated_height (GTK_WIDGET (display)));
}

/*
 * frdp_display_new:
 *
 * Create a new widget capable of connecting to a RDP server
 * and displaying its contents
 *
 * The widget will be initially be in a disconnected state
 *
 * Returns: (transfer full): the new RDP display widget
 */
GtkWidget *frdp_display_new (void)
{
  return GTK_WIDGET (g_object_new (FRDP_TYPE_DISPLAY, NULL));
}

gboolean
frdp_display_authenticate (FrdpDisplay *self,
                           gchar **username,
                           gchar **password,
                           gchar **domain)
{
  FrdpDisplayClass *klass =  FRDP_DISPLAY_DISPLAY_GET_CLASS (self);

  g_signal_emit (self, signals[RDP_NEEDS_AUTHENTICATION], 0);

  return klass->authenticate (self, username, password, domain);
}

/**
 * frdp_display_get_pixbuf:
 * @display: (transfer none): the RDP display widget
 *
 * Take a screenshot of the display.
 *
 * Returns: (transfer full): a #GdkPixbuf with the screenshot image buffer
 */
GdkPixbuf *
frdp_display_get_pixbuf (FrdpDisplay *display)
{
  FrdpDisplayPrivate *priv = frdp_display_get_instance_private (display);

  return frdp_session_get_pixbuf (priv->session);
}
