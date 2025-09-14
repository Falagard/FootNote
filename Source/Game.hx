package;

import openfl.events.KeyboardEvent;
import openfl.events.TouchEvent;
import lime.system.System;
import openfl.geom.Rectangle;
import openfl.filesystem.FileMode;
import openfl.filesystem.FileStream;
import openfl.events.SampleDataEvent;
import openfl.filesystem.File;
import openfl.ui.Keyboard;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;
import openfl.events.Event;
import openfl.display.Sprite;
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

	private var baseWidth:Float = 640;
    private var baseHeight:Float = 480;

	public static var MAX_LINES:Int = 6; //max number of pages to show in lyrics

	//private static var sAssets:AssetManager;
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
	public static inline var SELECT_KEY_TIMEOUT:Float = 750; // timeout for select key long press in seconds

	public var currentState:Int = 0; //are we looking at root drives, files, or lyrics?

	private var selectKeyDownTime:Float = -1; // Track when SELECT_KEY is pressed

	var FILES_PER_PAGE:Int = 6;
	var filePage:Int = 0;

	//var fileServer:FileServer;

	var backgroundQuad:Sprite;

	private var touchStartX:Float = 0;
    private var touchStartY:Float = 0;
    private var isSwiping:Bool = false;
	
	private var alertBackgroundQuad:Sprite; // Add this line

	public function new () {
		
		super ();

		start();
	
	}

	public function start():Void
    {

		//sAssets = assets;
        //var texture = assets.getTexture("LoadingScreen");
        //var img = new Image(texture);
		//img.alpha = 0.0;

		var offset:Int = 10;
        var stageWidth:Float = stage.stageWidth;
        var stageHeight:Float = stage.stageHeight;
        var scale:Float = Math.min(stageWidth / baseWidth, stageHeight / baseHeight);
        var scaledFontSize:Int = Std.int(FONT_SIZE * scale);

		// Content TextField
		contentTF = new TextField();
		contentTF.x = contentTF.y = offset;
		contentTF.width = stageWidth - offset * 2;
		contentTF.height = stageHeight - offset * 2;
		contentTF.border = true;
		contentTF.multiline = true;
		contentTF.wordWrap = true;
		contentTF.selectable = false;
		contentTF.type = TextFieldType.DYNAMIC;
		contentTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);
		contentTF.textColor = 0xFFFFFF;
		contentTF.visible = true;
		addChild(contentTF);

		//var imgScale = stageWidth / img.width;

		//img.width = stageWidth;
        //img.height = img.height * imgScale;

		//var tween:Tween = new Tween(img, 3.0, Transitions.EASE_IN_OUT);
		//tween.animate("alpha", 1.0);
		
		//tween.onComplete = function():Void 
			//{ 
				//hide img 
				//img.alpha = 0.0;
				
				//changeState(STATE_MENU);
					
			//};

		//changeState(STATE_MENU);

		//juggler.add(tween);

		//background quad, black
		backgroundQuad = new Sprite();
        backgroundQuad.graphics.beginFill(BACKGROUND_COLOR); // red
        backgroundQuad.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight); // x, y, width, height
        backgroundQuad.graphics.endFill();
		
		addChild(backgroundQuad);

		//loading screen image
        //addChild(img);	

		

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
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		
		//fileServer = new FileServer();

		stage.addEventListener(Event.RESIZE, onResize);

		// Add menu textfield
		menuTF = new TextField();
		menuTF.x = menuTF.y = offset;
		menuTF.width = stageWidth - offset * 2;
		menuTF.height = stageHeight - offset * 2;
		menuTF.border = true;
		menuTF.multiline = true;
		menuTF.wordWrap = true;
		menuTF.selectable = false;
		menuTF.type = TextFieldType.DYNAMIC;
		menuTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);
		menuTF.textColor = 0xFFFFFF;
		menuTF.visible = false;
		addChild(menuTF);

		alertBackgroundQuad = new Sprite();
        alertBackgroundQuad.graphics.beginFill(0x222222, 0.85); 
        alertBackgroundQuad.graphics.drawRect(0, 0, stageWidth - offset * 2, stageHeight - offset * 2); // x, y, width, height
        alertBackgroundQuad.graphics.endFill();
		alertBackgroundQuad.x = offset;
		alertBackgroundQuad.y = offset;
		alertBackgroundQuad.visible = false;
		addChild(alertBackgroundQuad);

		// Add alert textfield
		alertTF = new TextField();
		alertTF.x = alertTF.y = offset;
		alertTF.width = stageWidth - offset * 2;
		alertTF.height = stageHeight - offset * 2;
		alertTF.border = true;
		alertTF.multiline = true;
		alertTF.wordWrap = true;
		alertTF.selectable = false;
		alertTF.type = TextFieldType.DYNAMIC;
		alertTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);
		alertTF.textColor = 0xFFFFFF;
		alertTF.visible = false;
		addChild(alertTF);

		Gamepad.onConnect.add(gamepad_onConnect);

		for (gamepad in Gamepad.devices)
		{
			gamepad_onConnect(gamepad);
		}

		#if linux
		try {
			// Maximize the window using wmctrl
			var proc = new sys.io.Process("wmctrl", ["-r", ":ACTIVE:", "-b", "add,maximized_vert,maximized_horz"]);
			proc.close();
		} catch (e:Dynamic) {
			trace("wmctrl maximize failed: " + e);
		}
		#end

		changeState(STATE_MENU);
    }

	private function gamepad_onButtonDown(button:GamepadButton):Void
	{
		trace("Gamepad button down: " + button);

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
				navLyricsDown();
				return;
			}
			else if(button == GamepadButton.DPAD_LEFT)
			{
				navLyricsUp();
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

	function onResize(event:openfl.events.Event):Void 
	{
		backgroundQuad.width = stage.stageWidth;
		backgroundQuad.height = stage.stageHeight;

		var offset:Int = 10;
    
    var stageWidth:Float = stage.stageWidth;
    var stageHeight:Float = stage.stageHeight;
    var scale:Float = Math.min(stageWidth / baseWidth, stageHeight / baseHeight);
    var scaledFontSize:Int = Std.int(FONT_SIZE * scale);

    contentTF.width = stageWidth - offset * 2;
    contentTF.height = stageHeight - offset * 2;
    contentTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);

    menuTF.width = stageWidth - offset * 2;
    menuTF.height = stageHeight - offset * 2;
    menuTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);

    alertBackgroundQuad.width = stageWidth - offset * 2;
    alertBackgroundQuad.height = stageHeight - offset * 2;
    alertBackgroundQuad.x = offset;
    alertBackgroundQuad.y = offset;

    alertTF.width = stageWidth - offset * 2;
    alertTF.height = stageHeight - offset * 2;
    alertTF.defaultTextFormat = new TextFormat(FONT_NAME, scaledFontSize, 0xFFFFFF);

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
	private function onTouchBegin(event:TouchEvent):Void
	{
		touchStartX = event.stageX;
		touchStartY = event.stageY;
		isSwiping = true;
	}

	private function onTouchMove(event:TouchEvent):Void
	{
		// Optionally, you can handle move logic here if needed
	}

	private function onTouchEnd(event:TouchEvent):Void
	{
		if (!isSwiping) return;
		isSwiping = false;

		var endX = event.stageX;
		var endY = event.stageY;
		var deltaX = endX - touchStartX;
		var deltaY = endY - touchStartY;

		var swipeThreshold = 50; // pixels
		var verticalLimit = 100; // prevent diagonal swipes being counted

		if (Math.abs(deltaX) > swipeThreshold && Math.abs(deltaY) < verticalLimit) {
			if (deltaX > 0) {
				if (currentState == STATE_LYRICS) {
					navLyricsDown();
				}
			} else {
				if (currentState == STATE_LYRICS) {
					navLyricsUp();
				}
			}
		}
	}

	private function showAlert(message:String):Void
	{
		alertTF.htmlText = message;
		alertTF.visible = true;
		alertBackgroundQuad.visible = true;

		// Hide alert after 3 seconds
		Timer.delay(() -> {
			alertTF.visible = false;
			alertBackgroundQuad.visible = false;
			alertTF.htmlText = "";
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
			// View Lyric Files
			changeState(STATE_FILES);
			
		} else if (selectedMenuIdx == 1) {
			// Scan USB
			detectUSBAndCopyDirectory();
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
		else {
			// No more directories in stack, go back to menu
			changeState(STATE_MENU);
		}
	}

	private function onKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == SELECT_KEY && selectKeyDownTime < 0) {
            selectKeyDownTime = System.getTimer();
        }
	}

	private function onKeyUp(event:KeyboardEvent):Void
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
				// Long press detection: only trigger if held for SELECT_KEY_TIMEOUT or more
				var delta = System.getTimer() - selectKeyDownTime;

				trace("Select key held for: " + delta + " ms");

				if (selectKeyDownTime > 0 && delta >= SELECT_KEY_TIMEOUT) {
					trace("fileNavBack() called due to long press");

					fileNavBack();
				}
				else 
				{
					//short press, select file
					trace("File selected: " + currentDirectoryEntries[selectedFileIdx].name);
					fileNavSelect();
				}
				selectKeyDownTime = -1;
			}
			else if (event.keyCode == BACK_KEY)
			{
				fileNavBack();
				return;
			}
		}
		else if (currentState == STATE_LYRICS)
		{
			if (event.keyCode == BACK_KEY)
			{
				navLyricsBack();
				return;
			}
			else if (event.keyCode == SELECT_KEY)
			{
				// Long press detection: only trigger if held for SELECT_KEY_TIMEOUT or more
				var delta = System.getTimer() - selectKeyDownTime;

				if (selectKeyDownTime > 0 && delta >= SELECT_KEY_TIMEOUT) {
					navLyricsBack();
				}
				selectKeyDownTime = -1;
				return;
			}
			else if (event.keyCode == NEXT_KEY)
			{
				navLyricsDown();
				return;
			}
			else if (event.keyCode == PREVIOUS_KEY)
			{
				navLyricsUp();
				return;
			}
		}
	}

	function navLyricsDown():Void
	{
		//get number of pages
		var totalPages:Int = Math.ceil(lines.length / MAX_LINES);

		if (currentPageIdx + 1 > totalPages - 1) {
			return;
		}

		currentPageIdx++;

		refreshLyrics();
	}

	function navLyricsUp():Void
	{
		currentPageIdx--;

		if (currentPageIdx == -1) {
			currentPageIdx = 0;
		}

		refreshLyrics();
	}

	function navLyricsBack():Void
	{
		changeState(STATE_FILES);
	}

	function changeState(newState:Int):Void
	{
    	currentState = newState;

		selectKeyDownTime = -1; // Reset select key timer

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
			contentTF.htmlText = "";
			lyricsContainer.alpha = 1.0;

			//check if there's an audio file with the same name
			var fileName = currentDirectoryEntries[selectedFileIdx].name;
			var dotIdx = fileName.lastIndexOf(".");
			var baseName = dotIdx != -1 ? fileName.substr(0, dotIdx) : fileName;
			var audioFile:File = currentDirectory.resolvePath(baseName + ".wav");

			if (audioFile.exists) {
				try {
					var fileStream = new FileStream();
					fileStream.open(audioFile, FileMode.READ);
					var bytes = new openfl.utils.ByteArray();
					fileStream.readBytes(bytes, 0, fileStream.bytesAvailable);
					fileStream.close();
					var sound = new openfl.media.Sound();
					bytes.position = 0;
					sound.loadCompressedDataFromByteArray(bytes, bytes.length);
					var channel = sound.play();
				} catch (e:Dynamic) {
					trace("Error playing audio: " + e);
				}
			}

			refreshLyrics();
		}
	}

	// Add this helper to update menu text with selection highlight
	private function updateMenuText():Void 
	{
		var menuOptions = [
			"1. View Lyric Files",
			"2. Copy Files From USB"
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
		menuTF.htmlText = html;
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
		// Remove previous children
		while (lyricsContainer.numChildren > 0) {
			lyricsContainer.removeChildAt(0);
		}

		var startIdx = currentPageIdx * MAX_LINES;
		var endIdx = startIdx + MAX_LINES;

		var baseFontSize = FONT_SIZE;
		var baseLineHeight = baseFontSize + 10;
		var stageWidth = stage.stageWidth;
		var stageHeight = stage.stageHeight;
		var scale:Float = Math.min(stageWidth / baseWidth, stageHeight / baseHeight);
		var fontSize = Std.int(baseFontSize * scale);
		var lineHeight = Std.int(baseLineHeight * scale);
		var fontName = FONT_NAME;

		// Determine how many lines we’ll actually display
		var actualLines = 0;
		for (i in startIdx...endIdx) {
			if (i >= lines.length) break;
			actualLines++;
		}

		var totalHeight = actualLines * lineHeight;
		lyricsContainer.y = Math.floor((stageHeight - totalHeight) / 2);

		var yOffset = 0;

		for (i in startIdx...endIdx) {
			if (i >= lines.length) break;

			var lineText = StringTools.trim(lines[i]);
			var textColor = 0xFFFFFF;

			if (StringTools.startsWith(lineText, "chords=")) {
				lineText = lineText.substr("chords=".length);
				var chords = lineText.split(" ");
				var chordCount = chords.length;
				var spacing = Math.floor((stageWidth - 20) / chordCount);
				var xOffset = 10;
				for (chord in chords) {
					var chordTF = new TextField();
					chordTF.x = xOffset;
					chordTF.y = yOffset;
					chordTF.width = spacing;
					chordTF.height = lineHeight;
					chordTF.selectable = false;
					chordTF.type = TextFieldType.DYNAMIC;
					chordTF.defaultTextFormat = new TextFormat(fontName, fontSize, 0xFFD700, true, false, false, null, null, "center");
					chordTF.text = chord;
					chordTF.border = false;
					chordTF.multiline = false;
					chordTF.wordWrap = false;
					lyricsContainer.addChild(chordTF);
					xOffset += spacing;
				}
			} else {
				var tf = new TextField();
				tf.x = 10;
				tf.y = yOffset;
				tf.width = stageWidth - 20;
				tf.height = lineHeight;
				tf.selectable = false;
				tf.type = TextFieldType.DYNAMIC;
				tf.defaultTextFormat = new TextFormat(fontName, fontSize, textColor, false, false, false, null, null, "left");
				tf.text = lineText;
				tf.border = false;
				tf.multiline = false;
				tf.wordWrap = false;
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

		contentTF.htmlText = htmlText;
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