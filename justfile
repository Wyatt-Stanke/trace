default: convert build-game

run-convert:
    rm -rf converter/data/out
    cd converter; cargo run ./data

convert: run-convert
    @echo "Converting..."
    rm -rf pointplotter/source/drawings
    mkdir pointplotter/source/drawings
    cp converter/data/out/* pointplotter/source/drawings

build-game:
    @echo "Building game..."
    cd pointplotter; pdc source/

run-game: convert build-game
    @echo "Running game..."
    open ~/Developer/PlaydateSDK/bin/Playdate\ Simulator.app/ ./pointplotter/source.pdx