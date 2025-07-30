package;

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
import sys.io.File;
import sys.io.FileOutput;
import sys.FileSystem;
import haxe.io.Input;
import haxe.io.Output;
import StringTools;
import haxe.Timer;
import haxe.io.Path;

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
	public var rootDirs:Array<openfl.filesystem.File>;
	public var selectedDriveFiles:Array<openfl.filesystem.File>;
	public var selectedFileIdx:Int = 0;
	public var directoriesTF:TextField;
	public var fileText:String;
	public var currentPageIdx:Int = 0; //for paging through lyrics
	public var lines:Array<String> = [];
	
	var directoryStack:Array<openfl.filesystem.File> = [];
	var currentDirectory:openfl.filesystem.File;
	var currentDirectoryEntries:Array<openfl.filesystem.File> = []; // both files and folders

	public var currentState:Int = 0; //are we looking at root drives, files, or lyrics?

	var FILES_PER_PAGE:Int = 12;
	var filePage:Int = 0;

	var server:Socket = null;

	var handlingClient:Bool = false;
	
	public function new () {
		
		super ();
		
	}

	public function start(assets:AssetManager):Void
    {
		rootDirs = openfl.filesystem.File.documentsDirectory.getDirectoryListing();

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

				//var directory:openfl.filesystem.File = openfl.filesystem.File.documentsDirectory;

				//directory.addEventListener(Event.SELECT, directorySelected);
				//directory.browseForDirectory("Select Directory");
					
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

		server = new Socket();
        server.bind(new Host("0.0.0.0"), 8080);
        server.listen(10);
        trace("Listening on http://localhost:8080");

		server.setBlocking(false);

		refreshCurrentDirectory(openfl.filesystem.File.documentsDirectory);

		Timer.delay(() -> checkClients(), 100);

    }

	function checkClients():Void {
		if (server == null || handlingClient) {

		}
		else
		{
			var client:Socket = null;
			try 
			{
				client = server.accept();
				if (client != null) {
					handlingClient = true;
					handleClient(client);
					handlingClient = false;
				}
			} catch (e:Dynamic) {
				if(client != null) {
					client.close();
				}
				handlingClient = false;
			}
		}

		Timer.delay(() -> checkClients(), 100);
	} 

	static function handleClient(client:Socket):Void {
        final input = client.input;
        final output = client.output;

        var requestLine = input.readLine();
        if (requestLine == null) return;

        var method = requestLine.split(" ")[0];
        var path = requestLine.split(" ")[1];

        var headers:Map<String, String> = new Map();
        var contentLength = 0;
        var boundary = "";
        var line:String;

        while ((line = input.readLine()) != "") {
            var parts = line.split(": ");
            if (parts.length == 2) {
                headers[parts[0].toLowerCase()] = parts[1];
                if (parts[0].toLowerCase() == "content-length")
                    contentLength = Std.parseInt(parts[1]);
                if (parts[0].toLowerCase() == "content-type" && parts[1].indexOf("multipart/form-data") != -1) {
                    var b = parts[1].split("boundary=")[1];
                    if (b != null) boundary = "--" + StringTools.trim(b);
                }
            }
        }

        if (method == "GET") {
            if (StringTools.startsWith(path, "/view?file=")) {
                var filename = path.split("file=")[1];
                serveFileView(output, filename);
            } else if (StringTools.startsWith(path, "/delete?file=")) {
                var filename = path.split("file=")[1];
                handleDelete(output, filename);
            } else {
                sendUploadForm(output);
            }
        } else if (method == "POST") {
            handleUpload(input, output, contentLength, boundary);
        }

        client.close();
    }

	static function sendUploadForm(output:Output):Void {
        var files = FileSystem.readDirectory(openfl.filesystem.File.documentsDirectory.nativePath);
        var fileList = "";
        for (file in files) {
            if (StringTools.endsWith(file, ".txt")) {
                var safe = StringTools.urlEncode(file);
                fileList += '<li>
                    <a href="/view?file=$safe">$file</a>
                    &nbsp; | &nbsp;
                    <a href="/delete?file=$safe" onclick="return confirm(\'Delete $file?\')">Delete</a>
                </li>';
            }
        }

        final html = '
        <html>
            <body>
                <h1>Upload Text Files</h1>
                <form method="POST" enctype="multipart/form-data">
                    <input type="file" name="file" multiple />
                    <input type="submit" value="Upload" />
                </form>
                <h2>Uploaded Files</h2>
                <ul>$fileList</ul>
            </body>
        </html>
        ';
        sendResponse(output, 200, html, "text/html");
    }

	static function serveFileView(output:Output, filename:String):Void {
        try {
            var safeName = sanitizeFilename(filename);
            var contents = File.getContent(openfl.filesystem.File.documentsDirectory + safeName);
            var html = '
                <html>
                    <body>
                        <h1>Viewing: $safeName</h1>
                        <pre>${StringTools.htmlEscape(contents)}</pre>
                        <a href="/">Back</a>
                    </body>
                </html>
            ';
            sendResponse(output, 200, html, "text/html");
        } catch (e) {
            sendResponse(output, 404, "File not found", "text/plain");
        }
    }

	static function handleDelete(output:Output, filename:String):Void {
        try {
            var safeName = sanitizeFilename(filename);
            var directory = openfl.filesystem.File.documentsDirectory.nativePath;
			var path = Path.join([directory, safeName]);

            if (FileSystem.exists(path)) {
                FileSystem.deleteFile(path);
                sendResponse(output, 200, 'Deleted "$safeName".<br><a href="/">Back</a>', "text/html");
            } else {
                sendResponse(output, 404, "File not found", "text/plain");
            }
        } catch (e) {
            sendResponse(output, 500, "Error deleting file", "text/plain");
        }
    }

    static function handleUpload(input:Input, output:Output, contentLength:Int, boundary:String):Void {
        if (boundary == "") {
            sendResponse(output, 400, "Bad Request: Missing multipart boundary", "text/plain");
            return;
        }

        var body = input.read(contentLength).toString();
        var parts = body.split(boundary);
        var savedFiles = [];

        for (part in parts) {
            if (part.indexOf("Content-Disposition") != -1 && part.indexOf("filename=") != -1) {
                var nameStart = part.indexOf('filename="') + 10;
                var nameEnd = part.indexOf('"', nameStart);
                var filename = part.substr(nameStart, nameEnd - nameStart);
                filename = filename.split("\\").pop();
                if (!StringTools.endsWith(filename, ".txt")) continue;

                var contentStart = part.indexOf("\r\n\r\n");
                if (contentStart != -1) {
                    var content = part.substr(contentStart + 4);
                    content = content.split("\r\n")[0];
                    var safeName = sanitizeFilename(filename);
					var directory = openfl.filesystem.File.documentsDirectory.nativePath;
					var fullPath = Path.join([directory, safeName]);
                    File.saveContent(fullPath, content);
                    savedFiles.push(safeName);
                }
            }
        }

        sendResponse(output, 200, "Uploaded: " + savedFiles.join(", ") + "<br><a href='/'>Back</a>", "text/html");
    }

    static function sanitizeFilename(name:String):String {
        var s1 = StringTools.replace(name, "..", "");
		var s2 = StringTools.replace(s1, "/", "_");
		return StringTools.replace(s2, "\\", "_");
    }

    static function sendResponse(output:Output, status:Int, body:String, contentType:String):Void {
        output.writeString('HTTP/1.1 $status OK\r\n');
        output.writeString('Content-Type: $contentType\r\n');
        output.writeString('Content-Length: ${body.length}\r\n');
        output.writeString('Connection: close\r\n\r\n');
        output.writeString(body);
    }


	function directorySelected(event:Event):Void
	{
		//Cast the event target to a File object
		var directory:openfl.filesystem.File = cast(event.target, openfl.filesystem.File);
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

	function refreshCurrentDirectory(dir:openfl.filesystem.File):Void {
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