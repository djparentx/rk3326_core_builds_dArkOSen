#include <stdlib.h>

struct wl_surface;

struct wl_egl_window {
    struct wl_surface *surface;
    int width;
    int height;
    int dx;
    int dy;
    int attached_width;
    int attached_height;
};

struct wl_egl_window *wl_egl_window_create(struct wl_surface *surface, int width, int height)
{
    struct wl_egl_window *win = (struct wl_egl_window *)malloc(sizeof(struct wl_egl_window));
    if (!win)
        return NULL;
    win->surface = surface;
    win->width = width;
    win->height = height;
    win->dx = 0;
    win->dy = 0;
    win->attached_width = width;
    win->attached_height = height;
    return win;
}

void wl_egl_window_destroy(struct wl_egl_window *win)
{
    free(win);
}

void wl_egl_window_resize(struct wl_egl_window *win, int width, int height, int dx, int dy)
{
    if (!win)
        return;
    win->width = width;
    win->height = height;
    win->dx = dx;
    win->dy = dy;
}

void wl_egl_window_get_attached_size(struct wl_egl_window *win, int *width, int *height)
{
    if (!win)
        return;
    if (width)
        *width = win->attached_width;
    if (height)
        *height = win->attached_height;
}
