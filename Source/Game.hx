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
import openfl.events.Event;

class Game extends Sprite {
	
	//add an enum for the different states
	public static inline var STATE_FILES:Int = 0;
	public static inline var STATE_LYRICS:Int = 1;

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
	
	var directoryStack:Array<File> = [];
	var currentDirectory:File;
	var currentDirectoryEntries:Array<File> = []; // both files and folders

	public var currentState:Int = 0; //are we looking at root drives, files, or lyrics?

	var FILES_PER_PAGE:Int = 12;
	var filePage:Int = 0;

	
	public function new () {
		
		super ();
		
	}

	public function start(assets:AssetManager):Void
    {

		rootDirs = File.documentsDirectory.getDirectoryListing();

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

				var directory:File = File.documentsDirectory;

				directory.addEventListener(Event.SELECT, directorySelected);
				directory.browseForDirectory("Select Directory");
					
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
    }

	function directorySelected(event:Event):Void
	{
		//Cast the event target to a File object
		var directory:File = cast(event.target, File);
		currentState = STATE_FILES; // Set initial state to files
		refreshCurrentDirectory(directory);
	}


	private function onKeyDown(event:KeyboardEvent):Void
    {
		if(event.keyCode == PREVIOUS_KEY && currentState == STATE_FILES)
		{
			selectedFileIdx--;
			if (selectedFileIdx < 0) {
				selectedFileIdx = currentDirectoryEntries.length - 1;
			}
			refreshFiles();
			return;
		}
		else if(event.keyCode == NEXT_KEY && currentState == STATE_FILES)
		{
			selectedFileIdx++;
			
			if (selectedFileIdx > currentDirectoryEntries.length - 1) {
				selectedFileIdx = 0;
			}

			refreshFiles();
			return;
		}
		else if(event.keyCode == SELECT_KEY && currentState == STATE_FILES)
		{
			var selectedFile = currentDirectoryEntries[selectedFileIdx];

			if (selectedFile.isDirectory) {
				directoryStack.push(currentDirectory);
				currentDirectory = selectedFile;
				refreshCurrentDirectory(currentDirectory);
				selectedFileIdx = 0;
				return;
			}

			// It's a .txt file
			currentState = STATE_LYRICS;
			currentPageIdx = 0;

			var fileStream = new openfl.filesystem.FileStream();
			fileStream.addEventListener(openfl.events.Event.COMPLETE, function(e:openfl.events.Event):Void {
				fileText = fileStream.readUTFBytes(fileStream.bytesAvailable);
				lines = fileText.split("\n");
				refreshLyrics();
			});
			fileStream.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e:openfl.events.IOErrorEvent):Void {
				directoriesTF.text = "Error loading file: " + selectedFile.name;
				directoriesTF.isHtmlText = false;
			});
			fileStream.openAsync(selectedFile, openfl.filesystem.FileMode.READ);
			return;
		}
		else if(event.keyCode == BACK_KEY && currentState == STATE_FILES)
		{
			if (directoryStack.length > 0) {
				currentDirectory = directoryStack.pop();
				refreshCurrentDirectory(currentDirectory);
				selectedFileIdx = 0;
			}
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

	function refreshCurrentDirectory(dir:File):Void {
		currentDirectoryEntries = [];

		var contents = dir.getDirectoryListing();

		for (item in contents) {
			if (item.isDirectory || item.extension == "txt") {
				currentDirectoryEntries.push(item);
			}
		}		

		filePage = 0;
		selectedFileIdx = 0;


		refreshFiles(); // Update your file list display logic here
	}

	private function refreshLyrics():Void
	{
		//var selectedFile = selectedDriveFiles[selectedFileIdx];
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
		var totalPages = Math.ceil(currentDirectoryEntries.length / FILES_PER_PAGE);
		if (filePage >= totalPages) filePage = totalPages - 1;
		if (filePage < 0) filePage = 0;

		var htmlText:String = "<i>Choose a file or folder: </i><br/>";
		var startIdx = filePage * FILES_PER_PAGE;
		var endIdx = startIdx + FILES_PER_PAGE;

		for (i in startIdx...endIdx) {
			if (i >= currentDirectoryEntries.length) break;

			var currentFile = currentDirectoryEntries[i];

			if (i == selectedFileIdx) {
				htmlText += "<b><font color='#2FF0000'>";
			}

			htmlText += currentFile.isDirectory ? "[DIR] " : "";
			htmlText += currentFile.name;

			if (i == selectedFileIdx) {
				htmlText += "</font></b>";
			}

			htmlText += "<br/>";
		}

		htmlText += "<br/>W/S to move, Enter to select, Backspace to go back";

		directoriesTF.text = htmlText;
	}

}