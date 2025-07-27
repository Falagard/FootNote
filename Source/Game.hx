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

	public static inline var PREVIOUS_KEY:UInt = Keyboard.W;
	public static inline var NEXT_KEY:UInt = Keyboard.S;
	public static inline var SELECT_KEY:UInt = Keyboard.ENTER;
	public static inline var BACK_KEY:UInt = Keyboard.BACKSPACE;

	public static var MAX_LINES:Int = 12; //max number of pages to show in lyrics

	private static var sAssets:AssetManager;
	public var selectedDriveIdx:Int = 0;
	public var rootDirs:Array<File>;
	public var selectedDriveFiles:Array<File>;
	public var selectedFileIdx:Int = 0;
	public var directoriesTF:TextField;
	public var fileText:String;
	public var currentPageIdx:Int = 0; //for paging through lyrics
	public var lines:Array<String> = [];
	

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
		directoriesTF.height = Starling.current.stage.stageHeight - offset * 2;
		directoriesTF.width = Starling.current.stage.stageWidth - offset * 2;
		
		addChild(directoriesTF);
        
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		//stage.addEventListener(MouseEvent.KEY_DOWN, onKeyDown);
    }


	private function onKeyDown(event:KeyboardEvent):Void
    {
		if(event.keyCode == PREVIOUS_KEY && currentState == STATE_ROOT_DRIVES)
		{
			selectedDriveIdx--;
			if (selectedDriveIdx < 0) {
				selectedDriveIdx = rootDirs.length - 1;
			}

			refreshDirectories();
			return;
		}
		else if(event.keyCode == NEXT_KEY && currentState == STATE_ROOT_DRIVES)
		{
			selectedDriveIdx++;
			
			if (selectedDriveIdx > rootDirs.length - 1) {
				selectedDriveIdx = 0;
			}

			refreshDirectories();
			return;
		}
		else if(event.keyCode == PREVIOUS_KEY && currentState == STATE_FILES)
		{
			selectedFileIdx--;
			if (selectedFileIdx < 0) {
				selectedFileIdx = selectedDriveFiles.length - 1;
			}
			refreshFiles();
			return;
		}
		else if(event.keyCode == NEXT_KEY && currentState == STATE_FILES)
		{
			selectedFileIdx++;
			
			if (selectedFileIdx > selectedDriveFiles.length - 1) {
				selectedFileIdx = 0;
			}

			refreshFiles();
			return;
		}
		else if(event.keyCode == SELECT_KEY && currentState == STATE_ROOT_DRIVES)
		{
			currentState = STATE_FILES;

			selectedFileIdx = 0; //reset file index

			selectedDriveFiles = [];

			var originalDriveFiles = rootDirs[selectedDriveIdx].getDirectoryListing();

			for (i in 0...originalDriveFiles.length) {
				var file = originalDriveFiles[i];

				if( file.isDirectory) {
					continue; //skip directories, currently only allowing files in root directories
				}
				if( file.extension != "txt") {
					continue; //skip non-text files	
				}

				selectedDriveFiles.push(file);
			}

			
			refreshFiles();
			return;
		}
		else if(event.keyCode == SELECT_KEY && currentState == STATE_FILES)
		{
			currentState = STATE_LYRICS;

			currentPageIdx = 0; //reset page index

			var selectedFile = selectedDriveFiles[selectedFileIdx];

			//try loading the file as a text file
			var fileStream = new openfl.filesystem.FileStream();
			fileStream.addEventListener(openfl.events.Event.COMPLETE, function(e:openfl.events.Event):Void
			{
				fileText = fileStream.readUTFBytes(fileStream.bytesAvailable);

				lines = fileText.split("\n");

				refreshLyrics();
				
			});
			fileStream.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e:openfl.events.IOErrorEvent):Void
			{
				directoriesTF.text = "Error loading file: " + selectedFile.name;
				directoriesTF.isHtmlText = false;
				//directoriesTF.alpha = 1.0;
			});

			fileStream.openAsync(selectedFile, openfl.filesystem.FileMode.READ);

			//fileStream.close();

			
			return;
		}
		else if(event.keyCode == BACK_KEY && currentState == STATE_FILES)
		{
			currentState = STATE_ROOT_DRIVES;

			refreshDirectories();

			return;
		}
		else if(event.keyCode == BACK_KEY && currentState == STATE_LYRICS)
		{
			currentState = STATE_FILES;

			refreshFiles();
			
			return;
		}
		else if(event.keyCode == NEXT_KEY && currentState == STATE_LYRICS)
		{
	
			//get number of pages
			var totalPages:Int = Math.ceil(lines.length / MAX_LINES);

			if (currentPageIdx + 1 > totalPages - 1) {
				return;
			}

			currentPageIdx++;

			refreshLyrics();
			
			return;
		}
		else if(event.keyCode == PREVIOUS_KEY && currentState == STATE_LYRICS)
		{

			currentPageIdx--;

			if (currentPageIdx == -1) {
				currentPageIdx = 0;
			}

			refreshLyrics();
			
			return;
		}
    }

	private function refreshLyrics():Void
	{
		var selectedFile = selectedDriveFiles[selectedFileIdx];
		//var htmlText:String = "<i>" + selectedFile.name + "</i><br/>";
		var htmlText:String = "";

		//we can only show MAX_LINES lines at a time
		var startIdx = currentPageIdx * MAX_LINES;
		var endIdx = startIdx + MAX_LINES;

		//for each line in fileText, add it to htmlText	
		if (fileText != null) {
	
			var currIdx:Int = 0;
			
			for (line in lines) {
				if(currIdx < startIdx) {
					currIdx++;
					continue;
				}
				if(currIdx > endIdx) {
					break;
				}
				htmlText += line + "<br/>";
				currIdx++;
			}
		}

		directoriesTF.text = htmlText;
		directoriesTF.isHtmlText = true;
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

		htmlText += "Press A or D to change drive, Enter to select";

		directoriesTF.text = htmlText;	
	}

	public function refreshFiles():Void
	{
		var htmlText:String = "<i>Choose a file: </i><br/>";

		for (i in 0...selectedDriveFiles.length) {

			var currentFile = selectedDriveFiles[i];
			
			if (i == selectedFileIdx) {
				htmlText += "<b><font color='#2FF0000'>";
			}

			htmlText += selectedDriveFiles[i].name;

			if (i == selectedFileIdx) {
				htmlText += "</font></b>";
			}

			htmlText += "<br/>";
			
		}

		directoriesTF.text = htmlText;	
	}
}