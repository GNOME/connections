/* frdp-session.c
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

#include <errno.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <gdk/gdk.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <math.h>

#include "frdp-session.h"

#define SELECT_TIMEOUT 50

struct frdp_pointer
{
	rdpPointer pointer;
	cairo_surface_t *data;
};
typedef struct frdp_pointer frdpPointer;

struct _FrdpSessionPrivate
{
  freerdp      *freerdp_session;

  GtkWidget    *display;
  cairo_surface_t *surface;
  gboolean scaling;
  double scale;
  double offset_x;
  double offset_y;

  guint update_id;

  gboolean is_connected;

  gchar *hostname;
  gchar *username;
  gchar *password;
  guint  port;

  gboolean show_cursor;
  gboolean cursor_null;
  frdpPointer *cursor;
};

G_DEFINE_TYPE_WITH_PRIVATE (FrdpSession, frdp_session, G_TYPE_OBJECT)

enum
{
  PROP_0 = 0,
  PROP_HOSTNAME,
  PROP_PORT,
  PROP_USERNAME,
  PROP_PASSWORD,
  PROP_DISPLAY,
  PROP_SCALING
};

enum
{
  RDP_CONNECTED,
  RDP_DISCONNECTED,
  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

struct frdp_context
{
  rdpContext context;
  FrdpSession *self;
};
typedef struct frdp_context frdpContext;

static void
frdp_session_update_mouse_pointer (FrdpSession  *self)
{
  FrdpSessionPrivate *priv = self->priv;
  GdkCursor *cursor;
  GdkDisplay *display;
  GdkWindow  *window;

  window = gtk_widget_get_parent_window(priv->display);
  display = gtk_widget_get_display(priv->display);
  if (priv->show_cursor && priv->cursor_null) {
    cairo_surface_t *surface;
    cairo_t *cairo;

    /* Create a 1x1 image with transparent color */
    surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, 1, 1);
    cairo = cairo_create (surface);
    cairo_set_source_rgba (cairo, 0.0, 0.0, 0.0, 0.0);
    cairo_set_line_width(cairo, 1);
    cairo_rectangle(cairo, 0, 0, 1, 1);
    cairo_fill (cairo);

    cursor =  gdk_cursor_new_from_surface (display, surface, 0, 0);
    cairo_surface_destroy (surface);
    cairo_destroy (cairo);
    cairo_surface_destroy (surface);
  } else if (!priv->show_cursor || !priv->cursor)
      /* No cursor set or none to show */
    cursor = gdk_cursor_new_from_name (display, "default");
  else {
    rdpPointer *pointer = &priv->cursor->pointer;
    double scale = self->priv->scale;
    double x = priv->cursor->pointer.xPos * scale;
    double y = priv->cursor->pointer.yPos * scale;
    double w = pointer->width * scale;
    double h = pointer->height * scale;
    cairo_surface_t *surface;
    cairo_t *cairo;

    if (!self->priv->scaling) {
      scale = 1.0;
    }

    /* Scale the source image according to current settings. */
    surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, w, h);
    cairo = cairo_create (surface);

    cairo_scale(cairo, scale, scale);
    cairo_set_source_surface (cairo, priv->cursor->data, 0, 0);
    cairo_paint (cairo);

    cairo_fill (cairo);
    cursor =  gdk_cursor_new_from_surface (display, surface, x, y);
    cairo_surface_destroy (surface);
    cairo_destroy (cairo);
  }

  gdk_window_set_cursor (window, cursor);
}

static BOOL
frdp_Pointer_New(rdpContext* context, rdpPointer* pointer)
{
  frdpContext *fcontext = (frdpContext*) context;
  frdpPointer *fpointer = (frdpPointer*) pointer;
  int stride;
	unsigned char *data;
  cairo_surface_t *surface;

	if (!fcontext || !fpointer)
		return FALSE;

  surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, pointer->width,
                                        pointer->height);
  if (!surface) {
    return FALSE;
  }

  { /* FreeRDP BUG https://github.com/FreeRDP/FreeRDP/issues/5061
     * the function freerdp_image_copy_from_pointer_data
     * does not initialize the buffer which results in broken alpha data. */
    cairo_t* cairo = cairo_create (surface);

    cairo_set_source_rgba (cairo, 0.0, 0.0, 0.0, 1.0);
    cairo_fill (cairo);
    cairo_paint (cairo);
    cairo_destroy (cairo);
  }

  data = cairo_image_surface_get_data (surface);
  if (!data) {
    goto fail;
  }

  stride = cairo_format_stride_for_width (CAIRO_FORMAT_ARGB32, pointer->width);
	if (!freerdp_image_copy_from_pointer_data (data, PIXEL_FORMAT_BGRA32,
                                             stride, 0, 0, pointer->width,
                                             pointer->height,
                                             pointer->xorMaskData,
                                             pointer->lengthXorMask,
                                             pointer->andMaskData,
                                             pointer->lengthAndMask,
                                             pointer->xorBpp,
                                             &context->gdi->palette))
    goto fail;

  fpointer->data = surface;
  return TRUE;
fail:
  if (surface)
    cairo_surface_destroy (surface);
	return FALSE;
}

static void
frdp_Pointer_Free (rdpContext* context, rdpPointer* pointer)
{
  frdpContext *fcontext = (frdpContext*) context;
  frdpPointer *fpointer = (frdpPointer*) pointer;

  if (fpointer && fpointer->data) {
    cairo_surface_destroy (fpointer->data);
    fpointer->data = NULL;
  }
}

static BOOL
frdp_Pointer_Set (rdpContext* context,
                  const rdpPointer* pointer)
{
  frdpContext *fcontext = (frdpContext*) context;
  frdpPointer *fpointer = (frdpPointer*) pointer;
  FrdpSessionPrivate *priv = fcontext->self->priv;

  priv->cursor = fpointer;
  priv->cursor_null = FALSE;

  frdp_session_update_mouse_pointer (fcontext->self);
	return TRUE;
}

static BOOL
frdp_Pointer_SetNull (rdpContext* context)
{
  frdpContext *fcontext = (frdpContext*) context;
  FrdpSessionPrivate *priv = fcontext->self->priv;
  unsigned char *data;
  cairo_surface_t *surface;

  priv->cursor = NULL;
  priv->cursor_null = TRUE;

  frdp_session_update_mouse_pointer (fcontext->self);
	return TRUE;
}

static BOOL
frdp_Pointer_SetDefault (rdpContext* context)
{
  frdpContext *fcontext = (frdpContext*) context;
   FrdpSessionPrivate *priv = fcontext->self->priv;

  priv->cursor = NULL;
  priv->cursor_null = FALSE;
  frdp_session_update_mouse_pointer (fcontext->self);
	return TRUE;
}

static BOOL
frdp_Pointer_SetPosition (rdpContext* context, UINT32 x, UINT32 y)
{
  frdpContext *fcontext = (frdpContext*) context;
  /* TODO */
	return TRUE;
}

static void
frdp_register_pointer (rdpGraphics* graphics)
{
	rdpPointer pointer;

	pointer.size = sizeof(frdpPointer);
	pointer.New = frdp_Pointer_New;
	pointer.Free = frdp_Pointer_Free;
	pointer.Set = frdp_Pointer_Set;
	pointer.SetNull = frdp_Pointer_SetNull;
	pointer.SetDefault = frdp_Pointer_SetDefault;
	pointer.SetPosition = frdp_Pointer_SetPosition;
	graphics_register_pointer(graphics, &pointer);
}

static guint32
frdp_session_get_best_color_depth (FrdpSession *self)
{
  GdkScreen *display;
  GdkVisual *visual;

  display = gdk_screen_get_default ();
  visual = gdk_screen_get_rgba_visual (display);

  return gdk_visual_get_depth (visual);
}

static void
frdp_session_configure_event (GtkWidget *widget,
                              GdkEvent  *event,
                              gpointer   user_data)
{
  FrdpSession *self = (FrdpSession*) user_data;
  rdpSettings *settings = self->priv->freerdp_session->settings;
  double width, height;

  if (self->priv->scaling) {
    width = (double)gtk_widget_get_allocated_width (widget);
    height = (double)gtk_widget_get_allocated_height (widget);

    if (width < height)
      self->priv->scale = width / settings->DesktopWidth;
    else
      self->priv->scale = height / settings->DesktopHeight;

    settings->DesktopScaleFactor = self->priv->scale;

    self->priv->offset_x = (width - settings->DesktopWidth * self->priv->scale) / 2.0;
    self->priv->offset_y = (height - settings->DesktopHeight * self->priv->scale) / 2.0;
  }

  frdp_session_update_mouse_pointer (self);
}

static void
frdp_session_set_scaling (FrdpSession *self,
                          gboolean     scaling)
{
  self->priv->scaling = scaling;

  frdp_session_configure_event (self->priv->display, NULL, self);
}

static gboolean
frdp_session_draw (GtkWidget *widget,
                   cairo_t   *cr,
                   gpointer   user_data)
{
  FrdpSession *self = (FrdpSession*) user_data;

  if (self->priv->scaling) {
      cairo_translate (cr, self->priv->offset_x, self->priv->offset_y);
      cairo_scale (cr, self->priv->scale, self->priv->scale);
  }
  cairo_set_source_surface (cr, self->priv->surface, 0, 0);
  cairo_paint (cr);

  return TRUE;
}

static guint
frdp_certificate_verify (freerdp     *freerdp_session,
                         const gchar *common_name,
                         const gchar* subject,
                         const gchar* issuer,
                         const gchar* fingerprint,
                         gboolean     host_mismatch)
{
  /* TODO */
  return TRUE;
}

static guint
frdp_changed_certificate_verify (freerdp     *freerdp_session,
                                 const gchar *common_name,
                                 const gchar *subject,
                                 const gchar *issuer,
                                 const gchar *new_fingerprint,
                                 const gchar *old_subject,
                                 const gchar *old_issuer,
                                 const gchar *old_fingerprint)
{
  /* TODO */
  return TRUE;
}

static gboolean
frdp_authenticate (freerdp  *freerdp_session,
                   gchar   **username,
                   gchar   **password,
                   gchar   **domain)
{
  FrdpSession *self = ((frdpContext *) freerdp_session->context)->self;

  return frdp_display_authenticate (FRDP_DISPLAY (self->priv->display),
                                    username,
                                    password,
                                    domain);
}

static gboolean
frdp_pre_connect (freerdp *freerdp_session)
{
  rdpSettings *settings = freerdp_session->settings;

  settings->OrderSupport[NEG_DSTBLT_INDEX] = TRUE;
  settings->OrderSupport[NEG_PATBLT_INDEX] = TRUE;
  settings->OrderSupport[NEG_SCRBLT_INDEX] = TRUE;
  settings->OrderSupport[NEG_OPAQUE_RECT_INDEX] = TRUE;
  settings->OrderSupport[NEG_DRAWNINEGRID_INDEX] = FALSE;
  settings->OrderSupport[NEG_MULTIDSTBLT_INDEX] = FALSE;
  settings->OrderSupport[NEG_MULTIPATBLT_INDEX] = FALSE;
  settings->OrderSupport[NEG_MULTISCRBLT_INDEX] = FALSE;
  settings->OrderSupport[NEG_MULTIOPAQUERECT_INDEX] = TRUE;
  settings->OrderSupport[NEG_MULTI_DRAWNINEGRID_INDEX] = FALSE;
  settings->OrderSupport[NEG_LINETO_INDEX] = TRUE;
  settings->OrderSupport[NEG_POLYLINE_INDEX] = TRUE;
  settings->OrderSupport[NEG_MEMBLT_INDEX] = TRUE;
  settings->OrderSupport[NEG_MEM3BLT_INDEX] = FALSE;
  settings->OrderSupport[NEG_MEMBLT_V2_INDEX] = TRUE;
  settings->OrderSupport[NEG_MEM3BLT_V2_INDEX] = FALSE;
  settings->OrderSupport[NEG_SAVEBITMAP_INDEX] = FALSE;
  settings->OrderSupport[NEG_GLYPH_INDEX_INDEX] = TRUE;
  settings->OrderSupport[NEG_FAST_INDEX_INDEX] = TRUE;
  settings->OrderSupport[NEG_FAST_GLYPH_INDEX] = FALSE;
  settings->OrderSupport[NEG_POLYGON_SC_INDEX] = FALSE;
  settings->OrderSupport[NEG_POLYGON_CB_INDEX] = FALSE;
  settings->OrderSupport[NEG_ELLIPSE_SC_INDEX] = FALSE;
  settings->OrderSupport[NEG_ELLIPSE_CB_INDEX] = FALSE;

  return TRUE;
}

static gboolean
frdp_begin_paint (rdpContext *context)
{
  rdpGdi *gdi = context->gdi;

  gdi->primary->hdc->hwnd->invalid->null = 1;
  gdi->primary->hdc->hwnd->ninvalid = 0;

  return TRUE;
}

static gboolean
frdp_end_paint (rdpContext *context)
{
  FrdpSessionPrivate *priv;
  FrdpSession *self = ((frdpContext *) context)->self;
  rdpGdi *gdi = context->gdi;
  gint x, y, w, h;
  gint pos_x, pos_y;

  if (gdi->primary->hdc->hwnd->invalid->null)
    return TRUE;

  x = gdi->primary->hdc->hwnd->invalid->x;
  y = gdi->primary->hdc->hwnd->invalid->y;
  w = gdi->primary->hdc->hwnd->invalid->w;
  h = gdi->primary->hdc->hwnd->invalid->h;

  priv = self->priv;

  if (priv->scaling) {
      pos_x = self->priv->offset_x + x * priv->scale;
      pos_y = self->priv->offset_y + y * priv->scale;
      gtk_widget_queue_draw_area (priv->display,
                                  floor (pos_x),
                                  floor (pos_y),
                                  ceil (pos_x + w * priv->scale) - floor (pos_x),
                                  ceil (pos_y + h * priv->scale) - floor (pos_y));
  } else {
    gtk_widget_queue_draw_area (priv->display, x, y, w, h);
  }

  return TRUE;
}

static gboolean
frdp_post_connect (freerdp *freerdp_session)
{
  FrdpSession *self = ((frdpContext *) freerdp_session->context)->self;
  cairo_format_t cairo_format;
  rdpGdi *gdi;
  guint32 color_format;
  gint stride;

  switch (frdp_session_get_best_color_depth (self)) {
    case 32:
      color_format = PIXEL_FORMAT_BGRA32;
      cairo_format = CAIRO_FORMAT_ARGB32;
      break;
    case 24:
      color_format = PIXEL_FORMAT_BGRX32;
      cairo_format = CAIRO_FORMAT_RGB24;
      break;
    case 16:
    case 15:
      color_format = PIXEL_FORMAT_BGR16;
      cairo_format = CAIRO_FORMAT_RGB16_565;
      break;
    default:
      color_format = PIXEL_FORMAT_BGRX32;
      cairo_format = CAIRO_FORMAT_RGB16_565;
      break;
  }

  gdi_init (freerdp_session, color_format);
  gdi = freerdp_session->context->gdi;

  frdp_register_pointer (freerdp_session->context->graphics);
  pointer_cache_register_callbacks(freerdp_session->context->update);
  freerdp_session->update->BeginPaint = frdp_begin_paint;
  freerdp_session->update->EndPaint = frdp_end_paint;

  stride = cairo_format_stride_for_width (cairo_format, gdi->width);
  self->priv->surface =
      cairo_image_surface_create_for_data ((unsigned char*) gdi->primary_buffer,
                                           cairo_format,
                                           gdi->width,
                                           gdi->height,
                                           stride);

  gtk_widget_queue_draw_area (self->priv->display,
                              0,
                              0,
                              gdi->width,
                              gdi->height);

  return TRUE;
}

static gboolean
idle_close (gpointer user_data)
{
  FrdpSession *self = (FrdpSession*) user_data;

  g_signal_emit (self, signals[RDP_DISCONNECTED], 0);

  return FALSE;
}

static gboolean
update (gpointer user_data)
{
  DWORD status;
  HANDLE handles[64];
  DWORD usedHandles;
  FrdpSessionPrivate *priv;
  FrdpSession *self = (FrdpSession*) user_data;

  priv = self->priv;

  usedHandles = freerdp_get_event_handles (priv->freerdp_session->context,
                                           handles, ARRAYSIZE(handles));
  if (usedHandles == 0) {
      g_warning ("Failed to get FreeRDP event handle");
      return FALSE;
  }

  status = WaitForMultipleObjects (usedHandles, handles, FALSE, SELECT_TIMEOUT);
  if (status == WAIT_TIMEOUT)
    return TRUE;
  if (status == WAIT_FAILED)
    return FALSE;

  if (!freerdp_check_event_handles (priv->freerdp_session->context)) {
      g_warning ("Failed to check FreeRDP file descriptor");
      return FALSE;
  }

  if (freerdp_shall_disconnect (priv->freerdp_session)) {
      g_idle_add ((GSourceFunc) idle_close, self);

      return FALSE;
  }

  return TRUE;
}

static void
frdp_session_init_freerdp (FrdpSession *self)
{
  FrdpSessionPrivate *priv = self->priv;
  rdpSettings *settings;

  /* Setup FreeRDP session */
  priv->freerdp_session = freerdp_new ();
  priv->freerdp_session->PreConnect = frdp_pre_connect;
  priv->freerdp_session->PostConnect = frdp_post_connect;
  priv->freerdp_session->Authenticate = frdp_authenticate;
  priv->freerdp_session->VerifyCertificate = frdp_certificate_verify;
  priv->freerdp_session->VerifyChangedCertificate = frdp_changed_certificate_verify;

  priv->freerdp_session->ContextSize = sizeof (frdpContext);

  freerdp_context_new (priv->freerdp_session);
  ((frdpContext *) priv->freerdp_session->context)->self = self;

  settings = priv->freerdp_session->settings;

  settings->ServerHostname = g_strdup (priv->hostname);
  settings->ServerPort = priv->port;
  settings->Username = g_strdup (priv->username);
  settings->Password = g_strdup (priv->password);

  settings->AllowFontSmoothing = TRUE;
}

static void
frdp_session_connect_thread (GTask        *task,
                             gpointer      source_object,
                             gpointer      task_data,
                             GCancellable *cancellable)
{
  FrdpSession *self = (FrdpSession*) source_object;
  guint authentication_errors = 0;

  frdp_session_init_freerdp (self);

  do {
    self->priv->is_connected = freerdp_connect (self->priv->freerdp_session);

    if (!self->priv->is_connected) {
      authentication_errors +=
          freerdp_get_last_error (self->priv->freerdp_session->context) == 0x20009 ||
          freerdp_get_last_error (self->priv->freerdp_session->context) == 0x2000c ||
          freerdp_get_last_error (self->priv->freerdp_session->context) == 0x20005;

      freerdp_free (self->priv->freerdp_session);
      frdp_session_init_freerdp (self);
    }
  } while (!self->priv->is_connected && authentication_errors < 3);

  if (self->priv->is_connected) {
    g_signal_connect (self->priv->display, "draw",
                      G_CALLBACK (frdp_session_draw), self);
    g_signal_connect (self->priv->display, "configure-event",
                      G_CALLBACK (frdp_session_configure_event), self);
    frdp_session_set_scaling (self, TRUE);

    self->priv->update_id = g_idle_add ((GSourceFunc) update, self);
  } else {
    g_idle_add ((GSourceFunc) idle_close, self);
  }

  g_task_return_boolean (task, self->priv->is_connected);
}

static void
frdp_session_get_property (GObject    *object,
                           guint       property_id,
                           GValue     *value,
                           GParamSpec *pspec)
{
  FrdpSession *self = (FrdpSession*) object;
  rdpSettings *settings = self->priv->freerdp_session->settings;

  switch (property_id)
    {
      case PROP_HOSTNAME:
        g_value_set_string (value, settings->ServerHostname);
        break;
      case PROP_PORT:
        g_value_set_uint (value, settings->ServerPort);
        break;
      case PROP_USERNAME:
        g_value_set_string (value, settings->Username);
        break;
      case PROP_PASSWORD:
        g_value_set_string (value, settings->Password);
        break;
      case PROP_DISPLAY:
        g_value_set_object (value, self->priv->display);
        break;
      case PROP_SCALING:
        g_value_set_boolean (value, self->priv->scaling);
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
frdp_session_set_property (GObject      *object,
                           guint         property_id,
                           const GValue *value,
                           GParamSpec   *pspec)
{
  FrdpSession *self = (FrdpSession*) object;

  switch (property_id)
    {
      case PROP_HOSTNAME:
        g_free (self->priv->hostname);
        self->priv->hostname = g_value_dup_string (value);
        break;
      case PROP_PORT:
        self->priv->port = g_value_get_uint (value);
        break;
      case PROP_USERNAME:
        g_free (self->priv->username);
        self->priv->username = g_value_dup_string (value);
        break;
      case PROP_PASSWORD:
        g_free (self->priv->password);
        self->priv->password = g_value_dup_string (value);
        break;
      case PROP_DISPLAY:
        self->priv->display = g_value_get_object (value);
        break;
      case PROP_SCALING:
        frdp_session_set_scaling (self, g_value_get_boolean (value));
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
frdp_session_finalize (GObject *object)
{
  FrdpSession *self = (FrdpSession*) object;
  /* TODO: free the world! */

  if (self->priv->freerdp_session) {
    freerdp_disconnect (self->priv->freerdp_session);
    freerdp_context_free (self->priv->freerdp_session);
    g_clear_pointer (&self->priv->freerdp_session, freerdp_free);
  }

  frdp_session_close (self);

  g_clear_pointer (&self->priv->hostname, g_free);
  g_clear_pointer (&self->priv->username, g_free);
  g_clear_pointer (&self->priv->password, g_free);

  G_OBJECT_CLASS (frdp_session_parent_class)->finalize (object);
}

static void
frdp_session_class_init (FrdpSessionClass *klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);

  gobject_class->finalize = frdp_session_finalize;
  gobject_class->get_property = frdp_session_get_property;
  gobject_class->set_property = frdp_session_set_property;

  g_object_class_install_property (gobject_class,
                                   PROP_HOSTNAME,
                                   g_param_spec_string ("hostname",
                                                        "hostname",
                                                        "hostname",
                                                        NULL,
                                                        G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_PORT,
                                   g_param_spec_uint ("port",
                                                      "port",
                                                      "port",
                                                       0, G_MAXUINT16, 3389,
                                                       G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE));

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
                                   PROP_DISPLAY,
                                   g_param_spec_object ("display",
                                                        "display",
                                                        "display",
                                                        GTK_TYPE_WIDGET,
                                                        G_PARAM_READWRITE));

  g_object_class_install_property (gobject_class,
                                   PROP_SCALING,
                                   g_param_spec_boolean ("scaling",
                                                         "scaling",
                                                         "scaling",
                                                         TRUE,
                                                         G_PARAM_READWRITE));

  signals[RDP_DISCONNECTED] = g_signal_new ("rdp-disconnected",
                                            FRDP_TYPE_SESSION,
                                            G_SIGNAL_RUN_FIRST,
                                            0, NULL, NULL, NULL,
                                            G_TYPE_NONE, 0);
}

static void
frdp_session_init (FrdpSession *self)
{
  self->priv = frdp_session_get_instance_private (self);

  self->priv->is_connected = FALSE;
}

FrdpSession*
frdp_session_new (FrdpDisplay *display)
{
  gtk_widget_show (GTK_WIDGET (display));

  return g_object_new (FRDP_TYPE_SESSION,
                       "display", display,
                       NULL);
}

void
frdp_session_connect (FrdpSession         *self,
                      const gchar         *hostname,
                      guint                port,
                      GCancellable        *cancellable,
                      GAsyncReadyCallback  callback,
                      gpointer             user_data)
{
  GTask *task;

  self->priv->hostname = g_strdup (hostname);
  self->priv->port = port;

  task = g_task_new (self, cancellable, callback, user_data);
  g_task_run_in_thread (task, frdp_session_connect_thread);

  g_object_unref (task);
}

gboolean
frdp_session_connect_finish (FrdpSession   *self,
                             GAsyncResult  *result,
                             GError       **error)
{
  g_return_val_if_fail (g_task_is_valid (result, self), FALSE);

  return g_task_propagate_boolean (G_TASK (result), error);
}

gboolean
frdp_session_is_open (FrdpSession *self)
{
  return self->priv->is_connected;
}

void
frdp_session_close (FrdpSession *self)
{
  if (self->priv->update_id > 0) {
    g_source_remove (self->priv->update_id);
    self->priv->update_id = 0;
  }

  if (self->priv->freerdp_session != NULL) {
    gdi_free (self->priv->freerdp_session);

    self->priv->is_connected = FALSE;

    g_debug ("Closing RDP session");
  }
}

void
frdp_session_mouse_event (FrdpSession          *self,
                          FrdpMouseEvent        event,
                          guint16               x,
                          guint16               y)
{
  FrdpSessionPrivate *priv = self->priv;
  rdpInput *input;
  guint16 flags = 0;
  guint16 xflags = 0;

  g_return_if_fail (priv->freerdp_session != NULL);

  if (event & FRDP_MOUSE_EVENT_MOVE)
    flags |= PTR_FLAGS_MOVE;
  if (event & FRDP_MOUSE_EVENT_DOWN)
    flags |= PTR_FLAGS_DOWN;
  if (event & FRDP_MOUSE_EVENT_WHEEL) {
    flags |= PTR_FLAGS_WHEEL;
    if (event & FRDP_MOUSE_EVENT_WHEEL_NEGATIVE)
      flags |= PTR_FLAGS_WHEEL_NEGATIVE | 0x0088;
    else
      flags |= 0x0078;
  }
  if (event & FRDP_MOUSE_EVENT_HWHEEL) {
    flags |= PTR_FLAGS_HWHEEL;
    if (event & FRDP_MOUSE_EVENT_WHEEL_NEGATIVE)
      flags |= PTR_FLAGS_WHEEL_NEGATIVE | 0x0088;
    else
      flags |= 0x0078;
  }

  if (event & FRDP_MOUSE_EVENT_BUTTON1)
    flags |= PTR_FLAGS_BUTTON1;
  if (event & FRDP_MOUSE_EVENT_BUTTON2)
    flags |= PTR_FLAGS_BUTTON2;
  if (event & FRDP_MOUSE_EVENT_BUTTON3)
    flags |= PTR_FLAGS_BUTTON3;
  if (event & FRDP_MOUSE_EVENT_BUTTON4)
    xflags |=  PTR_XFLAGS_BUTTON1;
  if (event & FRDP_MOUSE_EVENT_BUTTON5)
    xflags |=  PTR_XFLAGS_BUTTON2;

  input = priv->freerdp_session->input;

  if (priv->scaling) {
    x = (x - priv->offset_x) / priv->scale;
    y = (y - priv->offset_y) / priv->scale;
  }

  x = x < 0.0 ? 0.0 : x;
  y = y < 0.0 ? 0.0 : y;
  if (xflags != 0) {
    if (event & FRDP_MOUSE_EVENT_DOWN)
        xflags |=  PTR_XFLAGS_DOWN;
    freerdp_input_send_extended_mouse_event(input, xflags, x, y);
  } else if (flags != 0) {
    freerdp_input_send_mouse_event (input, flags, x, y);
  }
}

void
frdp_session_mouse_pointer  (FrdpSession          *self,
                             gboolean              enter)
{
  FrdpSessionPrivate *priv = self->priv;

  priv->show_cursor = enter;
  frdp_session_update_mouse_pointer (self);
}

static unsigned char keycode_scancodes[] = {
   0,  0,  0,  0,  0,  0,  0, 28,
  29, 53, 55, 56,  0, 71, 72, 73,
  75, 77, 79, 80, 81, 82, 83,  0,
   0,  0,  0,  0,  0,  0, 69,  0,
   0,  0,  0,  0, 91, 92, 93,
};

static guint16
frdp_session_get_scancode_by_keycode (guint16 keycode)
{
  if (keycode < 8)
    return 0;
  else if (keycode < 97)
    return keycode - 8;
  else if (keycode < 97 + sizeof (keycode_scancodes))
    return keycode_scancodes[keycode - 97];
  else
    return 0;
}

void
frdp_session_send_key (FrdpSession  *self,
                       FrdpKeyEvent  event,
                       guint16       keycode)
{
  rdpInput *input = self->priv->freerdp_session->input;
  guint16 flags = 0;
  guint16 scancode =
      frdp_session_get_scancode_by_keycode (keycode);

  if (event == FRDP_KEY_EVENT_PRESS)
    flags |= KBD_FLAGS_DOWN;
  else
    flags |= KBD_FLAGS_RELEASE;

  input->KeyboardEvent (input, flags, scancode);
}

GdkPixbuf *
frdp_session_get_pixbuf (FrdpSession *self)
{
  guint width, height;

  width = gtk_widget_get_allocated_width (self->priv->display);
  height = gtk_widget_get_allocated_height (self->priv->display);

  return gdk_pixbuf_get_from_surface (self->priv->surface,
                                      0, 0,
                                      width, height);
}
