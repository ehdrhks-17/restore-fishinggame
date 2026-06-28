import urllib.request
import json
import os
import math

url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
temp_file = "world-countries.json"

if not os.path.exists(temp_file):
    print("Downloading World GeoJSON...")
    urllib.request.urlretrieve(url, temp_file)

with open(temp_file, "r", encoding="utf-8") as f:
    data = json.load(f)

# Mercator projection parameters centered on screen
CX = 780.0
CY = 450.0
SCALE_X = 2.4
SCALE_Y_MERCATOR = 135.0



def to_screen(lon, lat):
    x = CX + lon * SCALE_X
    
    lat_rad = math.radians(lat)
    # Clamp latitude to avoid pole singularities
    lat_rad = max(-math.radians(82), min(math.radians(84), lat_rad))
    y = CY - math.log(math.tan(math.pi / 4.0 + lat_rad / 2.0)) * SCALE_Y_MERCATOR
    return x, y

# Ramer-Douglas-Peucker (RDP) algorithm
def distance(p, p1, p2):
    x, y = p
    x1, y1 = p1
    x2, y2 = p2
    dx = x2 - x1
    dy = y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x - x1, y - y1)
    t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
    t = max(0, min(1, t))
    tx = x1 + t * dx
    ty = y1 + t * dy
    return math.hypot(x - tx, y - ty)

def rdp(points, epsilon):
    if len(points) < 3:
        return points
    dmax = 0.0
    index = 0
    end = len(points) - 1
    for i in range(1, end):
        d = distance(points[i], points[0], points[end])
        if d > dmax:
            index = i
            dmax = d
    if dmax > epsilon:
        rec1 = rdp(points[:index+1], epsilon)
        rec2 = rdp(points[index:], epsilon)
        return rec1[:-1] + rec2
    else:
        return [points[0], points[end]]

# Check self-intersections
def has_too_many_self_intersections(pts):
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
        
    def on_segment(p, q, r):
        return (q[0] <= max(p[0], r[0]) and q[0] >= min(p[0], r[0]) and
                q[1] <= max(p[1], r[1]) and q[1] >= min(p[1], r[1]))

    def orientation(p, q, r):
        val = (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (r[1] - q[1])
        if val == 0: return 0
        return 1 if val > 0 else 2

    def do_intersect(p1, q1, p2, q2):
        o1 = orientation(p1, q1, p2)
        o2 = orientation(p1, q1, q2)
        o3 = orientation(p2, q2, p1)
        o4 = orientation(p2, q2, q1)
        
        if o1 != o2 and o3 != o4:
            return True
            
        if o1 == 0 and on_segment(p1, p2, q1): return True
        if o2 == 0 and on_segment(p1, q2, q1): return True
        if o3 == 0 and on_segment(p2, p1, q2): return True
        if o4 == 0 and on_segment(p2, q1, q2): return True
        return False

    n = len(pts)
    count = 0
    for i in range(n):
        p1 = pts[i]
        q1 = pts[(i + 1) % n]
        for j in range(i + 2, n):
            if (j + 1) % n == i:
                continue
            p2 = pts[j]
            q2 = pts[(j + 1) % n]
            if do_intersect(p1, q1, p2, q2):
                count += 1
                if count > 2:
                    return True
    return False

output_polygons = {}
total_verts = 0

for feature in data["features"]:
    props = feature["properties"]
    iso_a3 = props.get("ISO_A3", "")
    if not iso_a3 or iso_a3 == "-99":
        iso_a3 = props.get("ADM0_A3", "")
    
    country_name = props.get("NAME", "").replace(" ", "_").replace("'", "").replace("-", "_")
    if not country_name:
        continue
        
    key_base = country_name.lower()
    if iso_a3 == "KOR":
        key_base = "korea"
    elif iso_a3 == "PRK":
        key_base = "korea_prk"
    elif "korea" in key_base:
        if "dem" in key_base or "north" in key_base:
            key_base = "korea_prk"
        else:
            key_base = "korea"

    elif iso_a3 == "JPN":
        key_base = "japan"
    elif iso_a3 == "CHN":
        key_base = "china"
    elif iso_a3 == "USA":
        key_base = "usa"
        
    if key_base == "antarctica":
        continue
        
    geom = feature["geometry"]
    polygons = []
    
    if geom["type"] == "Polygon":
        polygons = [geom["coordinates"][0]]
    elif geom["type"] == "MultiPolygon":
        # Keep major parts (we lowered to 8 to preserve islands like Alaska/Hawaii/St. Lawrence)
        for poly in geom["coordinates"]:
            if len(poly[0]) >= 8:
                polygons.append(poly[0])
        if not polygons:
            polygons = [max(geom["coordinates"], key=lambda poly: len(poly[0]))[0]]
            
    for i, poly in enumerate(polygons):
        # Continuous Date Line wrapping
        adjusted_poly = []
        last_lon = None
        for lon, lat in poly:
            if last_lon is not None:
                if lon - last_lon > 180:
                    lon -= 360
                elif lon - last_lon < -180:
                    lon += 360
            adjusted_poly.append((lon, lat))
            last_lon = lon
            
        screen_points = [to_screen(lon, lat) for lon, lat in adjusted_poly]
        
        simplified = None
        chosen_eps = 0.0
        # Try different epsilon values
        for eps in [1.5, 1.2, 0.8, 0.5, 0.2, 0.1]:
            candidate = rdp(screen_points, eps)
            candidate_rounded = [(round(p[0], 1), round(p[1], 1)) for p in candidate]
            if not has_too_many_self_intersections(candidate_rounded):
                simplified = candidate_rounded
                chosen_eps = eps
                break
        
        if simplified is None:
            candidate = rdp(screen_points, 0.2)
            simplified = [(round(p[0], 1), round(p[1], 1)) for p in candidate]
            
        if len(simplified) > 1 and simplified[0] == simplified[-1]:
            simplified = simplified[:-1]
            
        if len(simplified) < 3:
            continue
            
        poly_key = key_base if i == 0 else f"{key_base}_{i+1}"
        output_polygons[poly_key] = simplified
        total_verts += len(simplified)

print(f"Generated {len(output_polygons)} world polygons, total vertices: {total_verts}")

with open("world_polygons.txt", "w", encoding="utf-8") as out:
    for key, pts in sorted(output_polygons.items()):
        pts_str = ", ".join(f"{p[0]}, {p[1]}" for p in pts)
        out.write(f'"{key}": PackedVector2Array([{pts_str}]),\n')

print("Successfully written world_polygons.txt")
