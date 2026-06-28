import re

polygons_file = "world_polygons.txt"
tscn_file = "../scenes/WorldMapSelection.tscn"

# 1. Read polygons from world_polygons.txt
polygons = []
with open(polygons_file, "r", encoding="utf-8") as f:
    for line in f:
        # Match lines like: "name": PackedVector2Array([coords]),
        m = re.match(r'^"([^"]+)":\s*PackedVector2Array\(\[(.*)\]\),', line.strip())
        if m:
            name = m.group(1)
            coords = m.group(2)
            polygons.append((name, coords))

print(f"Parsed {len(polygons)} polygons from {polygons_file}")

# 2. Read WorldMapSelection.tscn content
with open(tscn_file, "r", encoding="utf-8") as f:
    content = f.read()

# 3. Create replacement string containing the WorldMap control and all child Polygon2D nodes
replacement = '[node name="WorldMap" type="Control" parent="."]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\n'
for name, coords in polygons:
    replacement += f'\n[node name="{name}" type="Polygon2D" parent="WorldMap"]\npolygon = PackedVector2Array({coords})\n'

# Find and replace the WorldMap or WorldMapTexture block
pattern = r'\[node name="(WorldMap|WorldMapTexture)"[\s\S]+?(?=\[node name="Title")'
new_content = re.sub(pattern, replacement + "\n", content)


# 4. Write back the updated scene file
with open(tscn_file, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Successfully updated WorldMapSelection.tscn with vector world polygons!")
