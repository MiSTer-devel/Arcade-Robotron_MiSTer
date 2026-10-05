#include "Vblaster_sim.h"
#include "Vblaster_sim___024root.h"
#include "verilated.h"
#include "verilated_save.h"
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

static void word(std::ofstream &f, uint32_t v, int bytes) {
    for (int i = 0; i < bytes; ++i) f.put(char(v >> (8 * i)));
}

int main(int argc, char **argv) {
    if (argc < 4) {
        std::cerr << "Usage: Vblaster_sim packet.hex mode output_prefix [frames] [checkpoint]\n";
        return 2;
    }
    const std::string packet = argv[1], prefix = argv[3];
    const int mode = std::stoi(argv[2]);
    const int limit = argc > 4 ? std::stoi(argv[4]) : 2801;
    if ((mode != 8 && mode != 9) || limit < 1) return 2;
    std::ifstream input(packet);
    std::vector<uint8_t> image;
    unsigned value;
    while (input >> std::hex >> value) image.push_back(value);
    if (image.size() != 0x60000) { std::cerr << "Invalid ROM packet\n"; return 2; }
    uint64_t packet_hash = 14695981039346656037ULL;
    for (uint8_t byte : image) packet_hash = (packet_hash ^ byte) * 1099511628211ULL;
    VerilatedContext context;
    Vblaster_sim model(&context);
    model.clock = 0;
    model.reset = 1;
    model.game = mode;
    model.buttons = 0;
    model.fire = 0;
    model.switches = 0;
    model.joy_x = model.joy_y = 7;
    model.dl_wr = 0;
    model.dl_addr = model.dl_data = 0;
    model.eval();
    auto tick = [&]() {
        model.clock = 1; model.eval(); context.timeInc(1);
        model.clock = 0; model.eval(); context.timeInc(1);
    };
    uint32_t frame = 0;
    int capture_frame = 0;
    uint64_t clocks = 0, next_sample = 0;
    if (argc > 5) {
        VerilatedRestore checkpoint;
        checkpoint.open(argv[5]);
        if (!checkpoint.isOpen()) { std::cerr << "Cannot open checkpoint\n"; return 2; }
        uint32_t saved_mode;
        std::string saved_packet;
        uint64_t saved_hash;
        checkpoint >> saved_mode >> saved_packet >> saved_hash >> frame >> clocks >> &context >> model;
        checkpoint.close();
        if (saved_mode != uint32_t(mode) || saved_packet != packet || saved_hash != packet_hash || frame != 1900) {
            std::cerr << "Checkpoint does not match this ROM packet and mode\n";
            return 2;
        }
        std::cout << "Resumed frame " << frame << '\n' << std::flush;
    } else {
        for (unsigned i = 0; i < image.size(); ++i) {
            model.dl_addr = i; model.dl_data = image[i]; model.dl_wr = 1;
            tick();
        }
        model.dl_wr = 0;
        model.reset = 0;
    }
    const auto started = std::chrono::steady_clock::now();
    bool previous_vs = model.vs;
    std::vector<uint8_t> pixels;
    std::vector<int16_t> samples;
    if (frame == 1900 && (clocks % 256) == 0) {
        samples.push_back(int16_t((int(model.audio_l) - 8192)*4));
        samples.push_back(int16_t((int(model.audio_r) - 8192)*4));
    }
    while (frame < limit && !context.gotFinish()) {
        tick(); ++clocks;
        if (clocks > uint64_t(limit + 1) * 400000) {
            std::cerr << "Video frame timeout\n";
            return 1;
        }
        if (previous_vs && !model.vs) {
            ++frame;
            if (frame % 300 == 0) {
                std::cout << "Frame " << frame << " PC " << std::hex
                          << model.rootp->blaster_sim__DOT__soc__DOT__mc6809__DOT__pc
                          << std::dec << " elapsed "
                          << std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count()
                          << " s\n" << std::flush;
            }
            if (frame == 1800) model.switches = 2;
            if (frame == 1802) model.switches = 0;
            if (frame == 1900) {
                VerilatedSave checkpoint;
                checkpoint.open(prefix + "_1900.chk");
                if (!checkpoint.isOpen()) { std::cerr << "Cannot create checkpoint\n"; return 1; }
                checkpoint << uint32_t(mode) << packet << packet_hash << frame << clocks << &context << model;
                checkpoint.close();
                std::cout << "Saved checkpoint at frame 1900\n" << std::flush;
            }
            if (frame == 2000) model.buttons = 2;
            if (frame == 2008) model.buttons = 0;
            if (frame == 2060) model.buttons = 2;
            if (frame == 2068) model.buttons = 0;
            if (frame == 2100) model.buttons = 8;
            if (frame == 2108) model.buttons = 0;
            if (frame == 2180) model.fire = 1;
            if (frame == 2300) { model.fire = 3; model.joy_x = 4; }
            if (frame == 2480) { model.fire = 0; model.joy_x = 7; }
            if (frame == 30 || frame == 900 || frame == 1800 || frame == 1950 ||
                frame == 2200 || frame == 2400 || frame == 2800) {
                capture_frame = frame; pixels.clear(); pixels.reserve(384*260*3);
                next_sample = clocks + 2;
            }
        }
        previous_vs = model.vs;
        if (capture_frame && clocks == next_sample) {
            pixels.push_back(model.red * 255 / 7);
            pixels.push_back(model.green * 255 / 7);
            pixels.push_back(model.blue * 255 / 3);
            next_sample += 2;
            if (pixels.size() == 384*260*3) {
                std::ofstream capture(prefix + "_" + std::to_string(capture_frame) + ".ppm", std::ios::binary);
                if (!capture) { std::cerr << "Cannot create video capture\n"; return 1; }
                capture << "P6\n384 260\n255\n";
                capture.write(reinterpret_cast<char *>(pixels.data()), pixels.size());
                std::cout << "Captured frame " << capture_frame << '\n' << std::flush;
                capture_frame = 0;
            }
        }
        if (frame >= 1900 && frame <= 2800 && (clocks % 256) == 0) {
            samples.push_back(int16_t((int(model.audio_l) - 8192)*4));
            samples.push_back(int16_t((int(model.audio_r) - 8192)*4));
        }
    }
    std::ofstream wav(prefix + ".wav", std::ios::binary);
    if (!wav) { std::cerr << "Cannot create audio capture\n"; return 1; }
    wav << "RIFF"; word(wav, 36 + samples.size()*2, 4); wav << "WAVEfmt ";
    word(wav,16,4); word(wav,1,2); word(wav,2,2); word(wav,46875,4);
    word(wav,46875*4,4); word(wav,4,2); word(wav,16,2); wav << "data";
    word(wav,samples.size()*2,4);
    for (int16_t sample : samples) word(wav,uint16_t(sample),2);
    std::cout << "Simulation complete: " << clocks << " clocks\n";
    model.final();
}
