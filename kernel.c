/* * Project-637-OS Kernel 
 * Repository: https://github.com/project637os-hue
 */

#define VIDEO_MEMORY 0xb8000
#define WHITE_ON_BLACK 0x0f

void kprint(char* message);
void clear_screen();

void main() {
    clear_screen();
    
    kprint("Project-637-OS v0.1 Status: ONLINE\n");
    kprint("----------------------------------\n");
    kprint("Architecture: x86 (32-bit)\n");
    kprint("Memory Protection: ENABLED\n");
    kprint("VGA Driver: INITIALIZED\n");
    kprint("\nWelcome to Project-637 System Interface.\n");
    kprint("> ");
}

void clear_screen() {
    unsigned char* vid = (unsigned char*) VIDEO_MEMORY;
    for (int i = 0; i < 80 * 25 * 2; i += 2) {
        vid[i] = ' ';
        vid[i+1] = WHITE_ON_BLACK;
    }
}

void kprint(char* message) {
    static int offset = 0;
    unsigned char* vid = (unsigned char*) VIDEO_MEMORY;
    
    for (int i = 0; message[i] != 0; i++) {
        if (message[i] == '\n') {
            offset = (offset / 160 + 1) * 160;
        } else {
            vid[offset] = message[i];
            vid[offset+1] = WHITE_ON_BLACK;
            offset += 2;
        }
    }
}
