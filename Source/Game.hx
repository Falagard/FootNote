package;

import starling.events.TouchPhase;
import starling.text.TextFormat;
import openfl.geom.Rectangle;
import starling.events.ResizeEvent;
import openfl.filesystem.FileMode;
import openfl.filesystem.FileStream;
import openfl.events.SampleDataEvent;
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

import sys.net.Socket;
import sys.net.Host;
import sys.io.File as SysFile;
import sys.io.FileOutput;
import sys.FileSystem;
import haxe.io.Input;
import haxe.io.Output;
import StringTools;
import haxe.Timer;
import haxe.io.Path;
import lime.ui.Gamepad;
import lime.ui.GamepadButton;

class Game extends Sprite {
	
	//add an enum for the different states
	public static inline var STATE_FILES:Int = 0;
	public static inline var STATE_LYRICS:Int = 1;
	public static inline var STATE_OPENING_FILE:Int = 2;
	public static inline var STATE_MENU:Int = -1; // Add menu state

	public static inline var PREVIOUS_KEY:UInt = Keyboard.LEFT;
	public static inline var NEXT_KEY:UInt = Keyboard.RIGHT;
	public static inline var SELECT_KEY:UInt = Keyboard.ENTER;
	public static inline var BACK_KEY:UInt = Keyboard.BACKSPACE;

	public static var MAX_LINES:Int = 6; //max number of pages to show in lyrics

	private static var sAssets:AssetManager;
	public var selectedDriveIdx:Int = 0;
	public var selectedDriveFiles:Array<File>;
	public var selectedFileIdx:Int = 0;
	public var contentTF:TextField;
	private var menuTF:TextField; // Menu textfield
	private var alertTF:TextField; // Alert textfield
	private var selectedMenuIdx:Int = 0; // 0 = Scan USB, 1 = View Lyric Files
	var lyricsContainer:Sprite;
	public var fileText:String;
	public var currentPageIdx:Int = 0; //for paging through lyrics
	public var lines:Array<String> = [];
	
	var directoryStack:Array<File> = [];
	var currentDirectory:File;
	var currentDirectoryEntries:Array<File> = []; // both files and folders

	public static inline var SELECTED_FILE_COLOR:String = "#7FB8FF"; // color for selected file in file list
	public static inline var BACKGROUND_COLOR:Int = 0x000000; // background color for the game
	public static inline var FONT_SIZE:Int = 30; // default font size for text fields
	public static inline var FONT_NAME:String = "Ubuntu"; // default font name

	public var currentState:Int = 0; //are we looking at root drives, files, or lyrics?

	var FILES_PER_PAGE:Int = 6;
	var filePage:Int = 0;

	var fileServer:FileServer;

	var backgroundQuad:Quad;

	private var touchStartX:Float = 0;
    private var touchStartY:Float = 0;
    private var isSwiping:Bool = false;
	
	private var alertBackgroundQuad:Quad; // Add this line

	public function new () {
		
		super ();
	
	}

	public function start(assets:AssetManager):Void
    {

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
				
				changeState(STATE_MENU);
					
			};

		Starling.current.juggler.add(tween);

		//background quad, black
		backgroundQuad = new Quad(Starling.current.stage.stageWidth, Starling.current.stage.stageHeight, BACKGROUND_COLOR);
		addChild(backgroundQuad);

		//loading screen image
        addChild(img);	

		var offset:Int = 10;
        var ttFont:String = FONT_NAME;
        var ttFontSize:Int = FONT_SIZE;
        
        contentTF = new TextField(300, 80, 
            "");

		contentTF.alpha = 0.0;

		contentTF.format.setTo(ttFont, ttFontSize, Color.WHITE);
        contentTF.x = contentTF.y = offset;
        contentTF.border = true;
		contentTF.isHtmlText = true;
		contentTF.height = Starling.current.stage.stageHeight - offset * 2;
		contentTF.width = Starling.current.stage.stageWidth - offset * 2;

		addChild(contentTF);

		lyricsContainer = new Sprite();
		lyricsContainer.x = 10;
		lyricsContainer.y = 10;
		addChild(lyricsContainer);

		trace(File.applicationStorageDirectory.nativePath);

		//Make sure there's a lyrics directory 
		var directory:File = File.documentsDirectory;
		directory = directory.resolvePath("FootNote");

		directory.createDirectory();

		currentDirectory = directory;
		refreshCurrentDirectory(directory);
        
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(TouchEvent.TOUCH, onTouch); // Add this line
		fileServer = new FileServer();

		stage.addEventListener(Event.RESIZE, onResize);

		// Add menu textfield
		menuTF = new TextField(400, 120, "");
		menuTF.format.setTo(FONT_NAME, FONT_SIZE, Color.WHITE);
		menuTF.x = menuTF.y = offset;
		menuTF.border = true;
		menuTF.isHtmlText = true;
		menuTF.visible = false;
		menuTF.height = Starling.current.stage.stageHeight - offset * 2;
		menuTF.width = Starling.current.stage.stageWidth - offset * 2;
		addChild(menuTF);

		// Add alert background quad (behind alertTF)
		alertBackgroundQuad = new Quad(
			Starling.current.stage.stageWidth - offset * 2,
			Starling.current.stage.stageHeight - offset * 2,
			0x222222
		);
		alertBackgroundQuad.alpha = 0.85;
		alertBackgroundQuad.x = offset;
		alertBackgroundQuad.y = offset;
		alertBackgroundQuad.visible = false;
		addChild(alertBackgroundQuad);

		// Add alert textfield
		alertTF = new TextField(400, 120, "");
		alertTF.format.setTo(FONT_NAME, FONT_SIZE, Color.WHITE);
		alertTF.x = alertTF.y = offset;
		alertTF.border = true;
		alertTF.isHtmlText = true;
		alertTF.visible = false;
		alertTF.height = Starling.current.stage.stageHeight - offset * 2;
		alertTF.width = Starling.current.stage.stageWidth - offset * 2;
		addChild(alertTF);

		Gamepad.onConnect.add(gamepad_onConnect);

		for (gamepad in Gamepad.devices)
		{
			gamepad_onConnect(gamepad);
		}

		
    }

	private function gamepad_onButtonDown(button:GamepadButton):Void
	{
		if(currentState == STATE_MENU)
		{
			if (button == GamepadButton.DPAD_UP) {
				menuNavUp();
				return;
			}
			else if (button == GamepadButton.DPAD_DOWN) {
				menuNavDown();
				return;
			}
			else if (button == GamepadButton.A) {
				menuNavSelect();
				return;
			}
			return;
		}
		else if (currentState == STATE_FILES)
		{
			if(button == GamepadButton.DPAD_UP)
			{
				fileNavUp();
				return;
			}
			else if(button == GamepadButton.DPAD_DOWN)
			{
				fileNavDown();
				return;
			}
			else if(button == GamepadButton.A)
			{
				fileNavSelect();
				return;
			}
			else if(button == GamepadButton.B)
			{
				fileNavBack();
				return;
			}
		}
		else if(currentState == STATE_LYRICS)
		{
			if(button == GamepadButton.B || button == GamepadButton.A)
			{
				changeState(STATE_FILES);
				return;
			}
			else if(button == GamepadButton.DPAD_RIGHT)
			{
				nextLyricsPage();
				return;
			}
			else if(button == GamepadButton.DPAD_LEFT)
			{
				previousLyricsPage();
				return;
			}
		}
	}

	private function gamepad_onButtonUp(button:GamepadButton):Void
	{
		
	}

	private function gamepad_onConnect(gamepad:Gamepad):Void
	{
		gamepad.onButtonDown.add(gamepad_onButtonDown);
		gamepad.onButtonUp.add(gamepad_onButtonUp);
	}

	function onResize(e:ResizeEvent):Void 
	{
		// set rectangle dimensions for viewPort:
		var viewPortRectangle:Rectangle = new Rectangle();
		viewPortRectangle.width = e.width; viewPortRectangle.height = e.height;

		// resize the viewport:
		Starling.current.viewPort = viewPortRectangle;

		// assign the new stage width and height:
		stage.stageWidth = e.width;
		stage.stageHeight = e.height;

		backgroundQuad.width = Starling.current.stage.stageWidth;
		backgroundQuad.height = Starling.current.stage.stageHeight;

		contentTF.width = Starling.current.stage.stageWidth - 20;
		contentTF.height = Starling.current.stage.stageHeight - 20;

		if(currentState == STATE_LYRICS)
		{
			refreshLyrics();
		}
		else if(currentState == STATE_FILES)
		{
			refreshFiles();
		}
	}

	function getLyricsDirectory():File
	{
		var directory:File = File.documentsDirectory;
		directory = directory.resolvePath("FootNote");

		return directory;
	}

	function directorySelected(event:Event):Void
	{
		//Cast the event target to a File object
		var directory:File = cast(event.target, File);
		currentState = STATE_FILES; // Set initial state to files
		refreshCurrentDirectory(directory);
	}

	// Handle swiping right and left to navigate lyrics 
	private function onTouch(event:TouchEvent):Void
	{
		var touchBegan = event.getTouch(this, TouchPhase.BEGAN);
        var touchMoved = event.getTouch(this, TouchPhase.MOVED);
        var touchEnded = event.getTouch(this, TouchPhase.ENDED);

        if (touchBegan != null) {
            var pos = touchBegan.getLocation(this);
            touchStartX = pos.x;
            touchStartY = pos.y;
            isSwiping = true;
        }

        if (touchEnded != null && isSwiping) {
            isSwiping = false;
            var endPos = touchEnded.getLocation(this);
            var deltaX = endPos.x - touchStartX;
            var deltaY = endPos.y - touchStartY;

            // Set a minimum distance threshold to count as a swipe
            var swipeThreshold = 50; // pixels
            var verticalLimit = 100; // prevent diagonal swipes being counted

            if (Math.abs(deltaX) > swipeThreshold && Math.abs(deltaY) < verticalLimit) {
                if (deltaX > 0) {
                    if (currentState == STATE_LYRICS)
					{
						nextLyricsPage();
					}
                } else {
                    if (currentState == STATE_LYRICS)
					{
						previousLyricsPage();
					}
                }
            }
        }
	}

	private function showAlert(message:String):Void
	{
		alertTF.text = message;
		alertTF.visible = true;
		alertBackgroundQuad.visible = true;

		// Hide alert after 3 seconds
		Timer.delay(() -> {
			alertTF.visible = false;
			alertBackgroundQuad.visible = false;
			alertTF.text = "";
		}, 3000);
	}

	private function menuNavDown():Void
	{
		selectedMenuIdx++;
		if (selectedMenuIdx > 1) selectedMenuIdx = 0;
		updateMenuText();
	}

	private function menuNavUp():Void
	{
		selectedMenuIdx--;
		if (selectedMenuIdx < 0) selectedMenuIdx = 1;
		updateMenuText();
	}

	private function menuNavSelect():Void
	{
		if (selectedMenuIdx == 0) {
			// Scan USB
			detectUSBAndCopyDirectory();

		} else if (selectedMenuIdx == 1) {
			// View Lyric Files
			changeState(STATE_FILES);
		}
	}

	private function fileNavUp():Void
	{
		selectedFileIdx--;
		if (selectedFileIdx < 0) {
			selectedFileIdx = currentDirectoryEntries.length - 1;
		}
		refreshFiles();
	}

	private function fileNavDown():Void
	{
		selectedFileIdx++;
		if (selectedFileIdx > currentDirectoryEntries.length - 1) {
			selectedFileIdx = 0;
		}
		refreshFiles();
	}

	private function fileNavSelect():Void
	{
		var selectedFile = currentDirectoryEntries[selectedFileIdx];

		if (selectedFile.isDirectory) {
			if(currentDirectory != null)
			{
				directoryStack.push(currentDirectory);
			}
			
			currentDirectory = selectedFile;
			refreshCurrentDirectory(currentDirectory);
			selectedFileIdx = 0;
			return;
		}

		// It's a .txt file
		changeState(STATE_OPENING_FILE);

		currentPageIdx = 0;

		var fileStream = new FileStream();
		fileStream.addEventListener(openfl.events.Event.COMPLETE, function(e:openfl.events.Event):Void {
			fileText = fileStream.readUTFBytes(fileStream.bytesAvailable);
			lines = fileText.split("\n");	
			
			changeState(STATE_LYRICS);
		});
		fileStream.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e:openfl.events.IOErrorEvent):Void {
			contentTF.text = "Error loading file: " + selectedFile.name;
			contentTF.isHtmlText = false;
		});

		fileStream.openAsync(selectedFile, FileMode.READ);
	}	

	private function fileNavBack():Void
	{
		var directoryStackLength = directoryStack.length;
		if (directoryStackLength > 0) {
			currentDirectory = directoryStack.pop();
			refreshCurrentDirectory(currentDirectory);
			selectedFileIdx = 0;
		}
	}

	private function onKeyDown(event:KeyboardEvent):Void
    {
    	if (currentState == STATE_MENU) 
		{
			if (event.keyCode == NEXT_KEY) {
				menuNavDown();
				return;
			}
			else if (event.keyCode == PREVIOUS_KEY) {
				menuNavUp();
				return;
			}
			else if (event.keyCode == SELECT_KEY) {
				menuNavSelect();
				return;
			}
			return;
		}
		else if (currentState == STATE_FILES)
		{
			if (event.keyCode == PREVIOUS_KEY)
			{
				fileNavUp();
				return;
			}
			else if (event.keyCode == NEXT_KEY)
			{
				fileNavDown();
				return;
			}
			else if (event.keyCode == SELECT_KEY)
			{
				fileNavSelect();
				return;
			}
			else if (event.keyCode == BACK_KEY)
			{
				fileNavBack();
				return;
			}
		}
		else if (currentState == STATE_LYRICS)
		{
			if (event.keyCode == BACK_KEY || event.keyCode == SELECT_KEY)
			{
				changeState(STATE_FILES);
				return;
			}
			else if (event.keyCode == NEXT_KEY)
			{
				nextLyricsPage();
				return;
			}
			else if (event.keyCode == PREVIOUS_KEY)
			{
				previousLyricsPage();
				return;
			}
		}
	}

	function nextLyricsPage():Void
	{
		//get number of pages
		var totalPages:Int = Math.ceil(lines.length / MAX_LINES);

		if (currentPageIdx + 1 > totalPages - 1) {
			return;
		}

		currentPageIdx++;

		refreshLyrics();
	}

	function previousLyricsPage():Void
	{
		currentPageIdx--;

		if (currentPageIdx == -1) {
			currentPageIdx = 0;
		}

		refreshLyrics();
	}

	function changeState(newState:Int):Void
	{
    	currentState = newState;

    	if (currentState == STATE_MENU) 
		{
			selectedMenuIdx = 0; // Reset menu selection
			menuTF.visible = true;
			contentTF.visible = false;
			lyricsContainer.visible = false;
			updateMenuText();
    	} 	
		else 
		{
			menuTF.visible = false;
			contentTF.visible = true;
			lyricsContainer.visible = true;
		}

    	if (currentState == STATE_FILES) {
			contentTF.alpha = 1.0;
			lyricsContainer.alpha = 0.0;
			refreshFiles();
		} else if (currentState == STATE_LYRICS) {
			contentTF.text = "";
			lyricsContainer.alpha = 1.0;
			refreshLyrics();
		}
	}

	// Add this helper to update menu text with selection highlight
	private function updateMenuText():Void 
	{
		var menuOptions = [
			"1. Copy Files From USB",
			"2. View Lyric Files"
		];
		var html = "<b>Menu</b><br/><br/>";
		for (i in 0...menuOptions.length) {
			if (i == selectedMenuIdx) {
				html += "<font color='#7FB8FF'><b>" + menuOptions[i] + "</b></font><br/>";
			} else {
				html += menuOptions[i] + "<br/>";
			}
		}
		html += "<br/><i>Use ←/→ to select, Enter to confirm</i>";
		menuTF.text = html;
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
		// Clear previous line text fields
		while (lyricsContainer.numChildren > 0) {
			lyricsContainer.removeChildAt(0, true); // dispose=true
		}

		var startIdx = currentPageIdx * MAX_LINES;
		var endIdx = startIdx + MAX_LINES;

		var fontSize = FONT_SIZE;
		var lineHeight = fontSize + 10;
		var fontName = FONT_NAME;

		// Determine how many lines we’ll actually display
		var actualLines = 0;
		for (i in startIdx...endIdx) {
			if (i >= lines.length) break;
			actualLines++;
		}

		var totalHeight = actualLines * lineHeight;

		// Vertically center the container
		var stageHeight = Starling.current.stage.stageHeight;
		lyricsContainer.y = Math.floor((stageHeight - totalHeight) / 2);

		var yOffset = 0;

		for (i in startIdx...endIdx) {
			if (i >= lines.length) break;

			var lineText = StringTools.trim(lines[i]);			

			// If lineText starts with "chords=", change color and remove "chords="
			var textColor = Color.WHITE;
			if (StringTools.startsWith(lineText, "chords=")) {
				lineText = lineText.substr("chords=".length);

				// Parse chords separated by spaces
				var chords = lineText.split(" ");
				var chordCount = chords.length;
				var stageWidth = Starling.current.stage.stageWidth - 20;
				var spacing = Math.floor(stageWidth / chordCount);

				var xOffset = 10;
				for (chord in chords) {
					var chordTF = new TextField(spacing, lineHeight, chord);
					chordTF.format.setTo(fontName, fontSize, 0xFFD700); // Gold color for chords
					chordTF.x = xOffset;
					chordTF.y = yOffset;
					chordTF.border = false;
					chordTF.autoScale = true;
					chordTF.isHtmlText = false;
					chordTF.format.horizontalAlign = starling.utils.Align.CENTER;
					lyricsContainer.addChild(chordTF);
					xOffset += spacing;
				}
			} else {
				var tf = new TextField(Starling.current.stage.stageWidth - 20, lineHeight, lineText);
				tf.format.setTo(fontName, fontSize, textColor);
				tf.x = 10;
				tf.y = yOffset;
				tf.border = false;
				tf.autoScale = true;
				tf.isHtmlText = true;
				tf.format.horizontalAlign = starling.utils.Align.LEFT;
				lyricsContainer.addChild(tf);
			}
			yOffset += lineHeight;
		}
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
				htmlText += "<b><font color='" + SELECTED_FILE_COLOR + "'>";
			}

			htmlText += currentFile.isDirectory ? "[DIR] " : "";
			htmlText += currentFile.name;

			if (i == selectedFileIdx) {
				htmlText += "</font></b>";
			}

			htmlText += "<br/>";
		}

		contentTF.text = htmlText;
	}

    private function detectUSBAndCopyDirectory():Void 
    {
        var usbRoot:File = detectUSBDrive();

        if (usbRoot == null || !usbRoot.exists) {
            trace("No USB drive found.");

			showAlert("No USB drive found. Please connect a USB drive and try again.");

            return;
        }

        trace("USB drive found at: " + usbRoot.nativePath);

        var documentsDir:File = getLyricsDirectory();
        copyDirectoryOptimized(usbRoot, documentsDir);

        trace("Copy complete!");

		showAlert("Copy complete! Files from USB have been copied to FootNote directory.");

		// Refresh the current directory to show the newly copied files
		refreshCurrentDirectory(documentsDir);
    }

    private function detectUSBDrive():File
    {
        #if windows
        for (letter in "DEFGHIJKLMNOPQRSTUVWXYZ".split("")) {
            var path = letter + ":/";
            if (FileSystem.exists(path)) {
                try {
                    var contents = FileSystem.readDirectory(path);
                    if (contents.length > 0) {
                        return new File(path);
                    }
                } catch (e:Dynamic) {}
            }
        }
        #elseif mac
        var volDir = "/Volumes";
        if (FileSystem.exists(volDir)) {
            for (name in FileSystem.readDirectory(volDir)) {
                if (name != "Macintosh HD" && !name.startsWith(".")) {
                    var fullPath = volDir + "/" + name;
                    return new File(fullPath);
                }
            }
        }
        #elseif linux
        var username = Sys.getEnv("USER");
        var mediaDir = "/media/" + username;
        if (FileSystem.exists(mediaDir)) {
            for (name in FileSystem.readDirectory(mediaDir)) {
                var fullPath = mediaDir + "/" + name;
                return new File(fullPath);
            }
        }
        #end
        return null;
    }

    private function copyDirectoryOptimized(source:File, destination:File):Void 
    {
        if (!source.exists) return;

        var files:Array<File> = source.getDirectoryListing();
        for (file in files) 
        {
            var destFile:File = destination.resolvePath(file.name);

            if (file.isDirectory) 
            {
                if (!destFile.exists) {
                    destFile.createDirectory();
                }
                copyDirectoryOptimized(file, destFile);
            } 
            else 
            {
                if (shouldCopyFile(file, destFile)) {
                    copyFile(file, destFile);
                } else {
                    trace("Skipped (unchanged): " + file.nativePath);
                }
            }
        }
    }

    private function shouldCopyFile(source:File, destination:File):Bool
    {
        if (!destination.exists) return true;

        var srcStat = FileSystem.stat(source.nativePath);
        var dstStat = FileSystem.stat(destination.nativePath);

        // Copy if file sizes differ or source is newer
        if (srcStat.size != dstStat.size) return true;
        if (srcStat.mtime.getTime() > dstStat.mtime.getTime()) return true;

        return false;
    }

    private function copyFile(source:File, destination:File):Void 
    {
		source.copyTo(destination, true);

        trace("Copied: " + source.nativePath + " → " + destination.nativePath);
    }


}