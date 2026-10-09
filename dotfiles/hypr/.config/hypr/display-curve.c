// Singularity - Hyprland
// ~/.config/hypr/display-curve.c
//
// Lifts the tone curve of displays that show dark and mid tones darker than
// the others, so the same grey looks the same on every screen. Each
// argument is MODEL=EXPONENT: any output whose description contains MODEL
// gets the ramp out = in^EXPONENT on all three channels (below 1 lifts the
// shadows; 0 and 1 stay put). Monitor settings can't do this -- brightness
// and contrast move the whole range -- and Hyprland's per-monitor icc
// profiles had no effect here.
//
// The ramp goes into the GPU's gamma LUT through wlr-gamma-control, which
// only holds while the client that set it is connected, so this stays
// running for the session (autostart.lua). It follows outputs coming and
// going: a mirrored display isn't a wl_output, so it loses the curve while
// mirrored and gets it back when it's a display of its own again.
// hyprsunset uses the CTM, not the gamma LUT, so Night Light still works.
//
// Built by install.sh:
//   wayland-scanner client-header wlr-gamma-control-unstable-v1.xml ...
//   cc display-curve.c ... -lwayland-client -lm

#define _GNU_SOURCE
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-gamma-control-unstable-v1-client-protocol.h"

struct rule {
    const char *model;
    double exponent;
};

struct output {
    struct wl_output *wl;
    uint32_t id;
    char *description;
    const struct rule *rule;
    struct zwlr_gamma_control_v1 *gamma;
    struct output *next;
};

static struct rule *rules;
static int nrules;
static struct zwlr_gamma_control_manager_v1 *manager;
static struct output *outputs;

static void gamma_size(void *data, struct zwlr_gamma_control_v1 *g, uint32_t size) {
    struct output *o = data;
    size_t bytes = (size_t)size * 3 * sizeof(uint16_t);
    int fd = memfd_create("display-curve", MFD_CLOEXEC);
    if (fd < 0 || size < 2 || ftruncate(fd, bytes) < 0) {
        if (fd >= 0) close(fd);
        return;
    }
    uint16_t *ramp = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (ramp == MAP_FAILED) {
        close(fd);
        return;
    }
    for (uint32_t i = 0; i < size; i++) {
        double v = pow((double)i / (size - 1), o->rule->exponent);
        ramp[i] = ramp[size + i] = ramp[2 * size + i] = (uint16_t)lround(v * 65535);
    }
    munmap(ramp, bytes);
    zwlr_gamma_control_v1_set_gamma(g, fd);
    close(fd);
    fprintf(stderr, "%s: ^%.2f\n", o->description, o->rule->exponent);
}

// Another client holds this output's gamma, or it went away.
static void gamma_failed(void *data, struct zwlr_gamma_control_v1 *g) {
    struct output *o = data;
    fprintf(stderr, "%s: gamma control refused\n", o->description);
    zwlr_gamma_control_v1_destroy(g);
    o->gamma = NULL;
}

static const struct zwlr_gamma_control_v1_listener gamma_listener = {
    .gamma_size = gamma_size,
    .failed = gamma_failed,
};

static void output_description(void *data, struct wl_output *wl, const char *description) {
    struct output *o = data;
    free(o->description);
    o->description = strdup(description);
}

// Everything about the output has arrived: match it against the rules.
static void output_done(void *data, struct wl_output *wl) {
    struct output *o = data;
    if (o->gamma || !o->description || !manager) return;
    for (int i = 0; i < nrules; i++) {
        if (strstr(o->description, rules[i].model)) {
            o->rule = &rules[i];
            o->gamma = zwlr_gamma_control_manager_v1_get_gamma_control(manager, wl);
            zwlr_gamma_control_v1_add_listener(o->gamma, &gamma_listener, o);
            return;
        }
    }
}

static void output_geometry(void *d, struct wl_output *wl, int32_t x, int32_t y, int32_t pw, int32_t ph,
                            int32_t subpixel, const char *make, const char *model, int32_t transform) {}
static void output_mode(void *d, struct wl_output *wl, uint32_t flags, int32_t w, int32_t h, int32_t refresh) {}
static void output_scale(void *d, struct wl_output *wl, int32_t factor) {}
static void output_name(void *d, struct wl_output *wl, const char *name) {}

static const struct wl_output_listener output_listener = {
    .geometry = output_geometry,
    .mode = output_mode,
    .done = output_done,
    .scale = output_scale,
    .name = output_name,
    .description = output_description,
};

static void global_added(void *data, struct wl_registry *registry, uint32_t id, const char *interface,
                         uint32_t version) {
    if (!strcmp(interface, zwlr_gamma_control_manager_v1_interface.name)) {
        manager = wl_registry_bind(registry, id, &zwlr_gamma_control_manager_v1_interface, 1);
    } else if (!strcmp(interface, wl_output_interface.name) && version >= 4) {
        struct output *o = calloc(1, sizeof *o);
        o->id = id;
        o->wl = wl_registry_bind(registry, id, &wl_output_interface, 4);
        wl_output_add_listener(o->wl, &output_listener, o);
        o->next = outputs;
        outputs = o;
    }
}

static void global_removed(void *data, struct wl_registry *registry, uint32_t id) {
    for (struct output **p = &outputs; *p; p = &(*p)->next) {
        struct output *o = *p;
        if (o->id != id) continue;
        if (o->gamma) zwlr_gamma_control_v1_destroy(o->gamma);
        wl_output_release(o->wl);
        free(o->description);
        *p = o->next;
        free(o);
        return;
    }
}

static const struct wl_registry_listener registry_listener = {
    .global = global_added,
    .global_remove = global_removed,
};

int main(int argc, char **argv) {
    rules = calloc(argc, sizeof *rules);
    for (int i = 1; i < argc; i++) {
        char *eq = strrchr(argv[i], '=');
        char *end;
        double e = eq ? strtod(eq + 1, &end) : 0;
        if (!eq || eq == argv[i] || *end || !(e > 0)) {
            fprintf(stderr, "usage: %s MODEL=EXPONENT...\n", argv[0]);
            return 2;
        }
        *eq = '\0';
        rules[nrules++] = (struct rule){ argv[i], e };
    }

    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "no Wayland display\n");
        return 1;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    // Binds everything; the outputs' own events, and so the matching, only
    // come after, when the manager is already there.
    wl_display_roundtrip(display);
    if (!manager) {
        fprintf(stderr, "compositor has no wlr-gamma-control\n");
        return 1;
    }

    while (wl_display_dispatch(display) != -1) {}
    return 0;
}
