import urllib.request
import json
import os
import math

url = "https://raw.githubusercontent.com/southkorea/southkorea-maps/master/kostat/2018/json/skorea-provinces-2018-geo.json"
temp_file = "skorea-provinces.json"

if not os.path.exists(temp_file):
    print("Downloading GeoJSON...")
    urllib.request.urlretrieve(url, temp_file)

with open(temp_file, "r", encoding="utf-8") as f:
    data = json.load(f)

# Aspect-ratio preserving projection parameters
# Center of South Korea
LAT_CTR = 36.0
LON_CTR = 127.8

# Scale Y to fit nicely in 580x580 canvas (increased for a larger map)
SCALE_Y = 115.0

SCALE_X = SCALE_Y * math.cos(math.radians(LAT_CTR))

# Canvas center
CX = 290.0
CY = 290.0

def to_screen(lon, lat):
    x = CX + (lon - LON_CTR) * SCALE_X
    y = CY - (lat - LAT_CTR) * SCALE_Y
    return x, y

name_map = {
    "서울특별시": "seoul",
    "경기도": "gyeonggi",
    "인천광역시": "incheon",
    "강원도": "gangwon",
    "충청북도": "chungbuk",
    "충청남도": "chungnam",
    "전라북도": "jeonbuk",
    "전라남도": "jeonnam",
    "경상북도": "gyeongbuk",
    "경상남도": "gyeongnam",
    "제주특별자치도": "jeju",
    "부산광역시": "busan",
    "대구광역시": "daegu",
    "광주광역시": "gwangju",
    "대전광역시": "daejeon",
    "울산광역시": "ulsan",
    "세종특별자치시": "sejong"
}

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

# Check if a polygon contains more than 2 self-intersections
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
    for i in range(n):
        p1 = pts[i]
        q1 = pts[(i + 1) % n]
        for j in range(i + 2, n):
            # Skip adjacent segment
            if (j + 1) % n == i:
                continue
            p2 = pts[j]
            q2 = pts[(j + 1) % n]
            if do_intersect(p1, q1, p2, q2):
                return True
    return False


output_polygons = {}

for feature in data["features"]:
    kor_name = feature["properties"]["name"]
    region_key = name_map.get(kor_name)
    if not region_key:
        continue
        
    geom = feature["geometry"]
    polygons = []
    
    if geom["type"] == "Polygon":
        polygons = [geom["coordinates"][0]]
    elif geom["type"] == "MultiPolygon":
        # Keep major parts with >= 15 vertices
        for poly in geom["coordinates"]:
            if len(poly[0]) >= 15:
                polygons.append(poly[0])
        if not polygons:
            polygons = [max(geom["coordinates"], key=lambda poly: len(poly[0]))[0]]
            
    for i, poly in enumerate(polygons):
        screen_points = [to_screen(lon, lat) for lon, lat in poly]
        
        # Dynamically find the best epsilon from most detailed to most simplified.
        # We require: 1) vertex count <= 200, and 2) exactly 0 self-intersections.
        simplified = None
        chosen_eps = 0.0
        for eps in [0.05, 0.1, 0.2, 0.5, 0.8, 1.2, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0]:
            candidate = rdp(screen_points, eps)
            candidate_rounded = [(round(p[0], 3), round(p[1], 3)) for p in candidate]
            
            # Enforce max vertex limit for safe triangulation
            if len(candidate_rounded) > 200:
                continue
                
            if not has_too_many_self_intersections(candidate_rounded):
                simplified = candidate_rounded
                chosen_eps = eps
                break
        
        # Fallback if no epsilon satisfied both constraints (very rare now with 3.5-5.0 included)
        if simplified is None:
            for fallback_eps in [3.5, 4.0, 5.0]:
                candidate = rdp(screen_points, fallback_eps)
                candidate_rounded = [(round(p[0], 3), round(p[1], 3)) for p in candidate]
                if len(candidate_rounded) <= 200:
                    simplified = candidate_rounded
                    chosen_eps = fallback_eps
                    break
            if simplified is None:
                candidate = rdp(screen_points, 5.0)
                simplified = [(round(p[0], 3), round(p[1], 3)) for p in candidate]
                chosen_eps = 5.0


        
        # Discard duplicate last point for clean Godot rendering
        if len(simplified) > 1 and simplified[0] == simplified[-1]:
            simplified = simplified[:-1]
            
        print(f"Region: {region_key} | part {i+1} | vertices: {len(simplified)} | epsilon: {chosen_eps}")

        
        poly_key = region_key if i == 0 else f"{region_key}_{i+1}"
        output_polygons[poly_key] = simplified




# Write output to file
with open("polygons.txt", "w", encoding="utf-8") as out:

    out.write("--- GENERATED POLYS ---\n")
    for key, pts in sorted(output_polygons.items()):
        pts_str = ", ".join(f"{p[0]}, {p[1]}" for p in pts)
        out.write(f'"{key}": PackedVector2Array([{pts_str}]),\n')
        
print("Successfully generated self-intersection optimized polygons!")
