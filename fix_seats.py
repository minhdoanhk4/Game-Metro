
import os

files = ["Train.tscn", "TrainFast.tscn", "TrainCatLinh.tscn", "TrainShinkansen.tscn"]

for f in files:
    path = os.path.join("Scenes", f)
    if not os.path.exists(path):
        continue
    
    with open(path, "r", encoding="utf-8") as file:
        lines = file.readlines()
        
    out_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Detect if this is a SeatCut node
        if line.startswith("[node name=\"SeatCut"):
            # Skip this block until the next node or EOF
            i += 1
            while i < len(lines) and not lines[i].startswith("[node"):
                i += 1
            continue
            
        # If it is a Seats node, we insert the cuts AFTER its properties
        out_lines.append(line)
        if line.startswith("[node name=\"Seats"):
            # Parse parent to determine which car it is
            parent = ""
            if "parent=\"" in line:
                parent = line.split("parent=\"")[1].split("\"")[0]
            
            # Find the end of this node properties (before next node)
            i += 1
            while i < len(lines) and not lines[i].startswith("[node"):
                out_lines.append(lines[i])
                i += 1
                
            # Now insert the SeatCuts
            base = parent.split("/")[0] if parent else "Car1"
            seat_name = line.split("name=\"")[1].split("\"")[0]
            
            if base in ["Car1", "Car3", "Car4", "Car5", "Car6"]:
                if base in ["Car3", "Car6"]:
                    cuts = [4.75, -1.75, -8.25]
                else:
                    cuts = [4.75, -1.75, -8.25]
            else:
                # Middle cars like Car2
                cuts = [6.25, -0.25, -6.75]
                
            for idx, cut_z in enumerate(cuts):
                out_lines.append("\n")
                out_lines.append(f"[node name=\"SeatCut{idx+1}\" type=\"CSGBox3D\" parent=\"{parent}/{seat_name}\"]\n")
                out_lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, {cut_z})\n")
                out_lines.append("operation = 2\n")
                out_lines.append("size = Vector3(1.5, 1.5, 2)\n")
            
            continue # Already advanced i to next node, loop handles it
            
        i += 1

    with open(path, "w", encoding="utf-8") as file:
        file.writelines(out_lines)
    print(f"Processed {f}")

