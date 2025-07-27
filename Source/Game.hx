package;

import starling.events.KeyboardEvent;
import starling.text.TextField;
import openfl.filesystem.File;
import starling.display.Image;
import starling.assets.AssetManager;
import starling.display.Quad;
import starling.display.Sprite;
import starling.utils.Color;
import starling.animation.Tween;
import starling.animation.Transitions;
import starling.animation.Juggler;
import starling.core.Starling;
import starling.events.Touch;
import starling.events.TouchEvent;
import openfl.ui.Keyboard;

class Game extends Sprite {
	
	//add an enum for the different states
	public static inline var STATE_ROOT_DRIVES:Int = 0;
	public static inline var STATE_FILES:Int = 1;
	public static inline var STATE_LYRICS:Int = 2;

	private static var sAssets:AssetManager;
	public var selectedDriveIdx:Int = 0;
	public var rootDirs:Array<File>;
	public var selectedDriveFiles:Array<File>;
	public var selectedFileIdx:Int = 0;
	public var directoriesTF:TextField;

	public var currentState:Int = 0; //are we looking at root drives, files, or lyrics?

	
	public function new () {
		
		super ();
		
		//var quad:Quad = new Quad(200, 200, Color.RED);
        //quad.x = 100;
        //quad.y = 50;
        //addChild(quad);

		
		
		
	}

	public function start(assets:AssetManager):Void
    {
		rootDirs = File.getRootDirectories();

        sAssets = assets;
        var texture = assets.getTexture("LoadingScreen");
        var img = new Image(texture);
		img.alpha = 0.0;

		var stageWidth:Float = Starling.current.stage.stageWidth;
		var scale = stageWidth / img.width;

        img.width = stageWidth;
        img.height = img.height * scale;

		var tween:Tween = new Tween(img, 3.0, Transitions.EASE_IN_OUT);
		tween.animate("alpha", 1.0);
		
		tween.onComplete = function():Void 
			{ 
				//hide img 
				img.alpha = 0.0;
				directoriesTF.alpha = 1.0;

				//show text 
				refreshDirectories();
			};

		Starling.current.juggler.add(tween);

        addChild(img);

		var offset:Int = 10;
        var ttFont:String = "Ubuntu";
        var ttFontSize:Int = 19;
        
        directoriesTF = new TextField(300, 80, 
            "");

		directoriesTF.alpha = 0.0;

		directoriesTF.format.setTo(ttFont, ttFontSize, 0x33399);
        directoriesTF.x = directoriesTF.y = offset;
        directoriesTF.border = true;
		directoriesTF.isHtmlText = true;

		addChild(directoriesTF);
        
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		//stage.addEventListener(MouseEvent.KEY_DOWN, onKeyDown);
    }


	private function onKeyDown(event:KeyboardEvent):Void
    {
		if(event.keyCode == Keyboard.A && currentState == STATE_ROOT_DRIVES)
		{
			selectedDriveIdx--;
			if (selectedDriveIdx < 0) {
				selectedDriveIdx = rootDirs.length - 1;
			}
			refreshDirectories();
			return;
		}
		else if(event.keyCode == Keyboard.D && currentState == STATE_ROOT_DRIVES)
		{
			selectedDriveIdx++;
			
			if (selectedDriveIdx > rootDirs.length - 1) {
				selectedDriveIdx = 0;
			}

			refreshDirectories();
			return;
		}
		else if(event.keyCode == Keyboard.A && currentState == STATE_FILES)
		{
			selectedFileIdx--;
			if (selectedFileIdx < 0) {
				selectedFileIdx = selectedDriveFiles.length - 1;
			}
			refreshFiles();
			return;
		}
		else if(event.keyCode == Keyboard.D && currentState == STATE_FILES)
		{
			selectedFileIdx++;
			
			if (selectedFileIdx > selectedDriveFiles.length - 1) {
				selectedFileIdx = 0;
			}

			refreshFiles();
			return;
		}
		else if(event.keyCode == Keyboard.ENTER && currentState == STATE_ROOT_DRIVES)
		{
			currentState = STATE_FILES;

			selectedDriveFiles = rootDirs[selectedDriveIdx].getDirectoryListing();

			refreshFiles();
			return;
		}
    }

 

	// Use starling 
	
	public function refreshDirectories():Void
	{
		

		var htmlText:String = "<i>Choose a drive: </i><br/>";

		for (i in 0...rootDirs.length) {
			if (i == selectedDriveIdx) {
				htmlText += "<b><font color='#2FF0000'>";
			}

			htmlText += rootDirs[i].nativePath;

			if (i == selectedDriveIdx) {
				htmlText += "</font></b>";
			}

			htmlText += "<br/>";
			
		}

		//add one for the "back" option
		//htmlText += "<br/><i>Press A/D to change drive, Enter to select</i>";

		directoriesTF.text = htmlText;	
	}

	public function refreshFiles():Void
	{
		var htmlText:String = "<i>Choose a file: </i><br/>";

		for (i in 0...selectedDriveFiles.length) {
			if (i == selectedFileIdx) {
				htmlText += "<b><font color='#2FF0000'>";
			}

			htmlText += selectedDriveFiles[i].name;

			if (i == selectedFileIdx) {
				htmlText += "</font></b>";
			}

			htmlText += "<br/>";
			
		}

		//add one for the "back" option
		//htmlText += "<br/><i>Press A/D to change selected file, Enter to select, Backspace to go back</i>";

		directoriesTF.text = htmlText;	
	}
}