#version 450
 
in vec2 pos;
uniform mat4 MVP;

void main() {
    gl_Position = MVP * vec4(pos.x, pos.y, 0.0, 1.0);
}
 
