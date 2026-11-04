"""Renders the world dump from buildworld.luau with a small z-buffer rasterizer, so the layout
can be checked without Roblox Studio. Not part of the repo.

Usage: python3 render.py world.json outdir [prefix]
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageFilter

world = json.load(open(sys.argv[1]))
outdir = sys.argv[2]
prefix = sys.argv[3] if len(sys.argv) > 3 else ""
parts = world["parts"]
plots = world["plots"]

BG = np.array([14, 14, 24], dtype=float)
LIGHT = np.array([0.35, 0.85, -0.4])
LIGHT /= np.linalg.norm(LIGHT)


def rot(cf):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return np.array([x, y, z]), np.array([[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]])


QUADS = [((0, 1, 2, 3), (0, 0, -1)), ((5, 4, 7, 6), (0, 0, 1)), ((4, 0, 3, 7), (-1, 0, 0)),
         ((1, 5, 6, 2), (1, 0, 0)), ((3, 2, 6, 7), (0, 1, 0)), ((4, 5, 1, 0), (0, -1, 0))]
SIGNS = np.array([(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], dtype=float)


class Camera:
    def __init__(self, eye, target, width, height, fov=None, scale=None):
        self.eye = np.array(eye, dtype=float)
        forward = np.array(target, dtype=float) - self.eye
        self.forward = forward / np.linalg.norm(forward)
        right = np.cross(self.forward, np.array([0.0, 1.0, 0.0]))
        self.right = right / np.linalg.norm(right)
        self.up = np.cross(self.right, self.forward)
        self.width, self.height, self.fov, self.scale = width, height, fov, scale
        if fov:
            self.focal = (height / 2) / math.tan(math.radians(fov) / 2)

    def view(self, points):
        rel = points - self.eye
        return np.stack([rel @ self.right, rel @ self.up, rel @ self.forward], axis=-1)

    def screen(self, v):
        """View-space points -> (sx, sy, nearness), nearness bigger = closer."""
        if self.fov:
            z = np.maximum(v[..., 2], 1e-3)
            return np.stack([self.width / 2 + v[..., 0] * self.focal / z, self.height / 2 - v[..., 1] * self.focal / z, 1 / z], axis=-1)
        return np.stack([self.width / 2 + v[..., 0] * self.scale, self.height / 2 - v[..., 1] * self.scale, -v[..., 2]], axis=-1)


class Frame:
    def __init__(self, camera):
        self.camera = camera
        self.depth = np.full((camera.height, camera.width), -np.inf)
        self.colour = np.tile(BG, (camera.height, camera.width, 1))
        self.glow = np.zeros((camera.height, camera.width, 3))

    def triangle(self, a, b, c, colour, alpha, neon):
        cam = self.camera
        xs, ys = (a[0], b[0], c[0]), (a[1], b[1], c[1])
        minx, maxx = max(int(math.floor(min(xs))), 0), min(int(math.ceil(max(xs))), cam.width - 1)
        miny, maxy = max(int(math.floor(min(ys))), 0), min(int(math.ceil(max(ys))), cam.height - 1)
        if minx > maxx or miny > maxy:
            return
        denom = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(denom) < 1e-9:
            return
        px, py = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
        w0 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / denom
        w1 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / denom
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        near = w0 * a[2] + w1 * b[2] + w2 * c[2]
        zone = self.depth[miny:maxy + 1, minx:maxx + 1]
        hit = inside & (near > zone)
        if not hit.any():
            return
        rgb = self.colour[miny:maxy + 1, minx:maxx + 1]
        if alpha >= 0.999:
            zone[hit] = near[hit]
            rgb[hit] = colour
        else:
            rgb[hit] = rgb[hit] * (1 - alpha) + np.array(colour) * alpha
        if neon:
            self.glow[miny:maxy + 1, minx:maxx + 1][hit] = colour

    def sphere(self, centre, radius, colour, alpha, neon):
        cam = self.camera
        v = cam.view(centre[None, :])[0]
        if cam.fov and v[2] < radius:
            return
        s = cam.screen(v[None, :])[0]
        pixel_radius = radius * (cam.focal / v[2] if cam.fov else cam.scale)
        minx, maxx = max(int(s[0] - pixel_radius), 0), min(int(s[0] + pixel_radius) + 1, cam.width - 1)
        miny, maxy = max(int(s[1] - pixel_radius), 0), min(int(s[1] + pixel_radius) + 1, cam.height - 1)
        if minx > maxx or miny > maxy:
            return
        px, py = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
        dx, dy = (px - s[0]) / pixel_radius, (py - s[1]) / pixel_radius
        d2 = dx * dx + dy * dy
        inside = d2 <= 1
        dz = np.sqrt(np.clip(1 - d2, 0, 1))
        view_z = v[2] - dz * radius
        near = 1 / np.maximum(view_z, 1e-3) if cam.fov else -view_z
        zone = self.depth[miny:maxy + 1, minx:maxx + 1]
        hit = inside & (near > zone)
        if not hit.any():
            return
        normal = dx[..., None] * cam.right - dy[..., None] * cam.up - dz[..., None] * cam.forward
        lit = 0.42 + 0.58 * np.clip(normal @ LIGHT, 0, 1)
        shaded = np.broadcast_to(np.array(colour)[None, None, :] * (1 if neon else lit[..., None]), lit.shape + (3,))
        rgb = self.colour[miny:maxy + 1, minx:maxx + 1]
        zone[hit] = near[hit]
        rgb[hit] = rgb[hit] * (1 - alpha) + shaded[hit] * alpha
        if neon:
            self.glow[miny:maxy + 1, minx:maxx + 1][hit] = colour

    def light(self, centre, colour, reach):
        cam = self.camera
        v = cam.view(centre[None, :])[0]
        if cam.fov and v[2] < 1:
            return
        s = cam.screen(v[None, :])[0]
        r = reach * 0.45 * (cam.focal / v[2] if cam.fov else cam.scale)
        minx, maxx = max(int(s[0] - r), 0), min(int(s[0] + r) + 1, cam.width - 1)
        miny, maxy = max(int(s[1] - r), 0), min(int(s[1] + r) + 1, cam.height - 1)
        if minx > maxx or miny > maxy or r < 1:
            return
        px, py = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
        fall = np.clip(1 - np.sqrt((px - s[0]) ** 2 + (py - s[1]) ** 2) / r, 0, 1) ** 2
        self.colour[miny:maxy + 1, minx:maxx + 1] += fall[..., None] * np.array(colour) * 0.18

    def save(self, name, exposure=1.0):
        glow = Image.fromarray(np.clip(self.glow, 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(radius=max(3, self.camera.width // 220)))
        result = np.clip((self.colour + np.asarray(glow, dtype=float) * 0.7) * exposure, 0, 255).astype(np.uint8)
        Image.fromarray(result).save(f"{outdir}/{prefix}{name}.png")
        print("wrote", prefix + name)


NEAR = 0.5


def clip_near(polygon, near):
    """Clips a view-space polygon to z >= near (Sutherland-Hodgman on one plane)."""
    result = []
    for i, current in enumerate(polygon):
        previous = polygon[i - 1]
        current_in, previous_in = current[2] >= near, previous[2] >= near
        if current_in != previous_in:
            t = (near - previous[2]) / (current[2] - previous[2])
            result.append(previous + (current - previous) * t)
        if current_in:
            result.append(current)
    return result


def shade(colour, normal, neon):
    c = np.array(colour) * 255
    if neon:
        return np.minimum(c * 1.05 + 25, 255)
    return np.minimum(c * (0.42 + 0.58 * max(0.0, float(normal @ LIGHT))), 255)


def render(camera, name, keep=None, exposure=1.0):
    frame = Frame(camera)
    lights = []
    for part in parts:
        pos, r = rot(part["cf"])
        if keep and not keep(pos):
            continue
        if part.get("light"):
            lights.append(part)
        if part.get("terrain") == "Water":
            # Terrain water: draw its box as a turquoise surface
            part = dict(part, color=[30 / 255, 150 / 255, 165 / 255], transparency=0.25, material="SmoothPlastic")
        alpha = 1 - part["transparency"]
        if alpha <= 0.05:
            continue
        neon = part["material"] == "Neon"
        size = np.array(part["size"], dtype=float)
        if part["shape"] == "Ball":
            frame.sphere(pos, size.min() / 2, np.array(part["color"]) * 255 if not neon else shade(part["color"], None, True), alpha, neon)
            continue
        if part["shape"] == "Cylinder":
            size[1] = size[2] = min(size[1], size[2])
        corners = pos + (SIGNS * size / 2) @ r.T
        view = camera.view(corners)
        for quad, n in QUADS:
            normal = r @ np.array(n, dtype=float)
            to_face = corners[quad[0]] - camera.eye if camera.fov else camera.forward
            if normal @ to_face > 0:
                continue
            polygon = [view[i] for i in quad]
            if camera.fov:
                polygon = clip_near(polygon, NEAR)
                if len(polygon) < 3:
                    continue
            screen = camera.screen(np.array(polygon))
            colour = shade(part["color"], normal, neon)
            for k in range(1, len(screen) - 1):
                frame.triangle(screen[0], screen[k], screen[k + 1], colour, alpha, neon)
    for part in lights:
        pos, _ = rot(part["cf"])
        r, g, b, reach = part["light"]
        frame.light(pos, np.array([r, g, b]) * 255, reach)
    frame.save(name, exposure)


plot_pos, plot_rot = rot(plots[0])
if world.get("space"):
    space_pos, space_rot = rot(world["space"])
else:
    space_pos, space_rot = plot_pos, plot_rot


def space(v):
    return space_pos + space_rot @ np.array(v, dtype=float)


def local(v):
    return plot_pos + plot_rot @ np.array(v, dtype=float)


near_plot = lambda p: np.linalg.norm((p - plot_pos)[[0, 2]]) < 75

views = sys.argv[4].split(",") if len(sys.argv) > 4 else ["room", "road", "overview", "plan"]
if "room" in views:
    render(Camera(local((-15, 25, -34)), local((0, 4, 5)), 1600, 1000, fov=38), "room_iso", keep=near_plot)
if "roomwide" in views:
    render(Camera(local((24, 40, -60)), local((0, 6, 8)), 1600, 1000, fov=40), "room_wide", keep=near_plot)
if "decks" in views:
    render(Camera(local((-1.2, 9.6, 13.0)), local((-0.4, 2.6, -1.5)), 1280, 720, fov=70), "decks_shot", keep=near_plot)
if "road" in views:
    road = plot_pos + plot_rot @ np.array([0, 0, -61.0])
    render(Camera(road + np.array([0, 7, 0]), local((0, 10, 10)), 1600, 900, fov=60), "street_to_plot", exposure=1.8)
if "overview" in views:
    render(Camera((-118, 46, -30), (60, 0, 10), 1600, 900, fov=60), "street_overview", exposure=2.2)
if "plan" in views:
    render(Camera((60, 600, 0.01), (60, 0, 0), 1600, 1000, scale=2.4), "street_plan", exposure=2.5)
# World-space shots: "world=name:ex/ey/ez:tx/ty/tz[:fov]" (nothing filtered out).
for view in views:
    if view.startswith("world="):
        name, eye, target, *rest = view[6:].split(":")
        fov = float(rest[0]) if rest else 60
        e = [float(x) for x in eye.split("/")]
        t = [float(x) for x in target.split("/")]
        render(Camera(np.array(e), np.array(t), 1600, 900, fov=fov), name, exposure=1.8)

# Custom shots: "cam=name:ex,ey,ez:tx,ty,tz[:fov[:radius]]" in plot-local coordinates.
for view in views:
    if view.startswith("cam="):
        name, eye, target, *rest = view[4:].split(":")
        fov = float(rest[0]) if rest else 60
        radius = float(rest[1]) if len(rest) > 1 else 75
        keep = lambda p, radius=radius: np.linalg.norm((p - space_pos)[[0, 2]]) < radius
        e = [float(x) for x in eye.split("/")]
        t = [float(x) for x in target.split("/")]
        render(Camera(space(e), space(t), 1600, 1000, fov=fov), name, keep=keep)
