shader_type spatial;
render_mode cull_front, blend_mix, depth_draw_opaque;

uniform bool has_nose = true;
uniform int num_doors = 3;

instance uniform float door_progress_left = 0.0;
instance uniform float door_progress_right = 0.0;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec3 color = vec3(0.9); // White interior
    float alpha = 1.0;
    
    float L = local_pos.x;
    float H = local_pos.y;
    float W = abs(local_pos.z);
    float center_W = abs(W - 1.5); 
    
    bool is_window = false;

    // --- Door Sliding Logic ---
    bool is_door_hole = false;
    bool is_sliding_door = false;
    float door_center_for_window = 0.0;
    
    float max_slide = 0.75;
    float current_slide = (local_pos.z > -1.5) ? (door_progress_right * max_slide) : (door_progress_left * max_slide);

    if (H > 0.2 && H < 2.5) {
        float d1 = 3.75;
        float d2 = 10.25;
        float d3 = 16.75;
        
        for (int i=0; i<3; i++) {
            if (i >= num_doors) { break; }
            float d_center = (i == 0) ? d1 : ((i == 1) ? d2 : d3);
            
            if (abs(L - d_center) < 0.75) {
                is_door_hole = true;
            }
            
            if (L > d_center - 0.75 - current_slide && L < d_center - current_slide) {
                is_sliding_door = true;
                door_center_for_window = d_center - current_slide;
            }
            if (L > d_center + current_slide && L < d_center + 0.75 + current_slide) {
                is_sliding_door = true;
                door_center_for_window = d_center + current_slide;
            }
        }
    }
    
    // Add logic for 2-door train (Shinkansen)
    // Actually the Interior Shader is shared between Train and Shinkansen
    // We should be careful. Shinkansen interior uses the same interior shader, but Shinkansen only has 2 doors.
    // Wait, the interior shader draws 3 windows per car anyway. If it has 3 holes, the Shinkansen exterior only has 2 holes!
    // Since exterior dictates what is seen from outside, the interior hole might just show white walls from outside if they don't match.
    // It's fine for now, we can check `has_nose` to distinguish? No, `has_nose` is only for Car1. Car2 doesn't have nose.
    // Let's just keep 3 doors for the interior shader to match Train.
    
    if (is_door_hole && !is_sliding_door) {
        discard;
    }

    // --- Side Windows ---
    if (is_sliding_door) {
        color = vec3(0.85); // Silver-ish doors from inside
        if (abs(L - door_center_for_window) < 0.4 && H > 1.5 && H < 2.3) {
            is_window = true;
        }
    } else {
        if (H > 1.4 && H < 2.5 && !is_door_hole) {
            if (mod(L, 3.0) >= 0.2) {
                is_window = true;
            }
        }
    }
    
    // --- Front Window ---
    if (has_nose && L >= 18.5) {
        float f = (L - 18.5) / 1.5; 
        float windshield_width = 1.3 - f * 0.2; 
        
        if (H > 1.5) {
            if (center_W < windshield_width) {
                is_window = true;
            } else {
                is_window = false;
            }
        } 
        else if (H > 0.5 && H <= 1.5) {
            is_window = false;
        }
        else {
            is_window = false;
        }
    }
    
    if (is_window) {
        color = vec3(0.05, 0.05, 0.08); // Dark tinted glass
        alpha = 0.5; // Transparency from inside
        ROUGHNESS = 0.05;
        METALLIC = 0.9;
    } else {
        color = vec3(0.9); // Clean white walls
        alpha = 1.0;
        ROUGHNESS = 0.4;
        METALLIC = 0.2;
    }

    ALBEDO = color;
    ALPHA = alpha;
}
