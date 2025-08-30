# FootNote
Haxe application used to load text files containing song lyics and use peripherals such as mouse and keyboard to navigate through lyrics. 

sudo add-apt-repository ppa:haxe/releases -y
sudo apt-get update
sudo apt-get install haxe -y
mkdir ~/haxelib && haxelib setup ~/haxelib
mkdir ~/src 
cd src

git clone https://github.com/Falagard/starling
haxelib dev starling starling 	

git clone --recursive https://github.com/openfl/lime
haxelib dev lime lime

git clone https://github.com/openfl/lime-samples
haxelib dev lime-samples lime-samples

git clone https://github.com/Falagard/openfl
haxelib dev openfl openfl 

haxelib install openfl

git clone https://github.com/Falagard/openfl-samples
haxelib dev openfl-samples openfl-samples

git clone https://github.com/Falagard/FootNote

sudo apt install g++-aarch64-linux-gnu

sudo apt-get install libpng-dev libturbojpeg-dev libvorbis-dev libopenal-dev libsdl2-dev libglu1-mesa-dev libmbedtls-dev libuv1-dev libsqlite3-dev
sudo apt install libgl1-mesa-dev libglu1-mesa-dev g++ libasound2-dev libx11-dev libxext-dev libxi-dev libxrandr-dev libxinerama-dev libpulse-dev libxcursor-dev libdbus-1-dev libdrm-dev libgbm-dev libudev-dev

haxelib run lime rebuild linux -DHXCPP_M64 -64
maybe -DHXCPP_ARM64 

lime build linux 

cd FootNote
lime test linux 
