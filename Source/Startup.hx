package;


import openfl.utils.Timer;
import openfl.system.Capabilities;
import starling.assets.AssetManager;
import openfl.display.Sprite;
import openfl.utils.Assets;
import starling.core.Starling;
import starling.events.Event;
import flash.filesystem.File;

class Startup extends Sprite {
	
	
	private var _starling:Starling;
	private var _assets:AssetManager;
	
	
	public function new () {
		
		super ();
		
		_starling = new Starling (Game, stage);

		_starling.addEventListener(Event.ROOT_CREATED, function():Void
        {
            loadAssets(startGame);
        });

		_starling.start ();
	}

	private function loadAssets(onComplete:Void->Void):Void
    {

		var rootDirs = File.getRootDirectories();

		

        _assets = new AssetManager();

        _assets.verbose = true;
        //_assets.enqueue(["https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/330px-PNG_transparency_demonstration_1.png"]);
        
		_assets.enqueue([
            Assets.getPath ("assets/textures/1x/LoadingScreen.png"),
        ]);
		
		
		_assets.loadQueue(onComplete, function(msg:String):Void
        {
            trace("Error "+ msg);
        });



		
    }

	private function startGame():Void
    {
        var game:Game = cast(_starling.root, Game);
        game.start(_assets);
        //Timer.delay(removeElements, 150); // delay to make 100% sure there's no flickering.
    }
	
	
}