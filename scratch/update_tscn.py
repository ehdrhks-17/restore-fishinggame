import re

polygons_file = "polygons.txt"
tscn_file = "../scenes/MapSelection.tscn"

# 1. Read polygons from polygons.txt
polygons = []
with open(polygons_file, "r", encoding="utf-8") as f:
    for line in f:
        # Match lines like: "gyeonggi": PackedVector2Array([Vector2(x, y), ...]),
        m = re.match(r'^"([^"]+)":\s*PackedVector2Array\(\[(.*)\]\),', line.strip())
        if m:
            name = m.group(1)
            coords = m.group(2)
            polygons.append((name, coords))

print(f"Parsed {len(polygons)} polygons from {polygons_file}")

# 2. Read MapSelection.tscn lines
with open(tscn_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip_mode = False

for line in lines:
    # Check if this line starts a new node
    node_match = re.match(r'^\[node name="([^"]+)" type="([^"]+)"( parent="([^"]+)")?\]', line.strip())
    if node_match:
        name = node_match.group(1)
        ntype = node_match.group(2)
        parent = node_match.group(4)
        
        # If it's a child of KoreaMap, skip it (we will insert new ones)
        if parent == "KoreaMap":
            skip_mode = True
            continue
        else:
            skip_mode = False
            
        # If we just reached the end of the skipped KoreaMap children (e.g., LeftPanel)
        # insert all new polygons before this node!
        if name == "LeftPanel" and parent == ".":
            for p_name, p_coords in polygons:
                new_lines.append(f'\n[node name="{p_name}" type="Polygon2D" parent="KoreaMap"]\n')
                new_lines.append(f'polygon = PackedVector2Array({p_coords})\n')
            new_lines.append('\n')
            
    # If in skip mode, don't write the line
    if skip_mode:
        continue
        
    new_lines.append(line)

# Write the modified content back
with open(tscn_file, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Successfully updated MapSelection.tscn with new polygons!")
