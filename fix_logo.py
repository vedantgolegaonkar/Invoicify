from PIL import Image
import math

img = Image.open('assets/logo.png').convert('RGBA')
pixels = img.load()
width, height = img.size

bg_color = (78, 52, 46, 255)
fg_color = (14, 38, 84, 255)
target_bg = (255, 255, 255, 255)
target_fg = (78, 52, 46, 255)

for y in range(height):
    for x in range(width):
        r, g, b, a = pixels[x, y]
        
        # Calculate distance to bg and fg
        dist_bg = math.sqrt((r - bg_color[0])**2 + (g - bg_color[1])**2 + (b - bg_color[2])**2)
        dist_fg = math.sqrt((r - fg_color[0])**2 + (g - fg_color[1])**2 + (b - fg_color[2])**2)
        
        total_dist = dist_bg + dist_fg
        if total_dist == 0:
            w_fg = 0
        else:
            w_fg = dist_bg / total_dist
            
        new_r = int(w_fg * target_fg[0] + (1 - w_fg) * target_bg[0])
        new_g = int(w_fg * target_fg[1] + (1 - w_fg) * target_bg[1])
        new_b = int(w_fg * target_fg[2] + (1 - w_fg) * target_bg[2])
        new_a = a
        
        pixels[x, y] = (new_r, new_g, new_b, new_a)

img.save('assets/logo_fixed.png')
print("Saved assets/logo_fixed.png")
