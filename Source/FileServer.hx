package;

import sys.net.Socket;
import sys.net.Host;
import sys.io.File as SysFile;
import sys.io.FileOutput;
import sys.FileSystem;
import haxe.io.Input;
import haxe.io.Output;
import haxe.io.Path;
import haxe.Timer;
import StringTools;
import openfl.filesystem.File;

class FileServer {
    var server:Socket;
    var handlingClient:Bool = false;

    public function new() {
        server = new Socket();
        server.bind(new Host("0.0.0.0"), 8080);
        server.listen(10);
        server.setBlocking(false);
        trace("Listening on http://localhost:8080");

        Timer.delay(() -> checkClients(), 100);
    }

    // Add trace to checkClients
    function checkClients():Void {
        if (handlingClient) return;

        var client:Socket = null;
        try {
            client = server.accept();
            if (client != null) {
                trace("Client connected: " + client.peer());
                handlingClient = true;
                handleClient(client);
                handlingClient = false;
            }
        } catch (e:Dynamic) {
            //trace("Error accepting client: " + e);
            if (client != null) client.close();
            handlingClient = false;
        }

        Timer.delay(() -> checkClients(), 100);
    }

    function handleClient(client:Socket):Void {
        final input = client.input;
        final output = client.output;

        var requestLine = input.readLine();
        trace("Request line: " + requestLine);
        if (requestLine == null) return;

        var method = requestLine.split(" ")[0];
        var path = requestLine.split(" ")[1];
        trace("Method: " + method + ", Path: " + path);

        var headers:Map<String, String> = new Map();
        var contentLength = 0;
        var boundary = "";
        var line:String;

        while ((line = input.readLine()) != "") {
            trace("Header: " + line);
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
                trace("Serving file view: " + filename);
                serveFileView(output, filename);
            } else if (StringTools.startsWith(path, "/delete?file=")) {
                var filename = path.split("file=")[1];
                trace("Deleting file: " + filename);
                handleDelete(output, filename);
            } else {
                trace("Sending upload form");
                sendUploadForm(output);
            }
        } else if (method == "POST") {
            trace("Handling upload, contentLength=" + contentLength + ", boundary=" + boundary);
            handleUpload(input, output, contentLength, boundary);
        }

        trace("Closing client connection");
        client.close();
    }

    function sendUploadForm(output:Output):Void {
        trace("Building upload form");
        
        var directory:File = getDocumentsDirectory();

        var files = FileSystem.readDirectory(directory.nativePath);

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

    function serveFileView(output:Output, filename:String):Void {
        try {
            // urlDecode the filename
            var decodedName = StringTools.urlDecode(filename);
            var safeName = sanitizeFilename(decodedName);
            trace("Opening file for view: " + safeName);
            var directory = getDocumentsDirectory();
            var filePath = Path.join([directory.nativePath, safeName]);
            var contents = SysFile.getContent(filePath);
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
            trace("Error viewing file: " + e);
            sendResponse(output, 404, "File not found", "text/plain");
        }
    }

    function handleDelete(output:Output, filename:String):Void {
        try {
            var decodedName = StringTools.urlDecode(filename);
            var safeName = sanitizeFilename(decodedName);
            var directory = getDocumentsDirectory();
            var path = Path.join([directory.nativePath, safeName]);
            trace("Attempting to delete: " + path);

            if (FileSystem.exists(path)) {
                FileSystem.deleteFile(path);
                trace("Deleted file: " + path);
                sendResponse(output, 200, 'Deleted "$safeName".<br><a href="/">Back</a>', "text/html");
            } else {
                trace("File not found for delete: " + path);
                sendResponse(output, 404, "File not found", "text/plain");
            }
        } catch (e) {
            trace("Error deleting file: " + e);
            sendResponse(output, 500, "Error deleting file", "text/plain");
        }
    }

    function getDocumentsDirectory():File {
        var directory:File = File.documentsDirectory;
        directory = directory.resolvePath("FootNote");
        if (!directory.exists) {
            directory.createDirectory();
        }
        return directory;
    }

    function handleUpload(input:Input, output:Output, contentLength:Int, boundary:String):Void {
        if (boundary == "") {
            trace("Upload failed: missing boundary");
            sendResponse(output, 400, "Bad Request: Missing multipart boundary", "text/plain");
            return;
        }

        var body = input.read(contentLength).toString();
        trace("Upload body length: " + body.length);
        var parts = body.split(boundary);
        var savedFiles = [];

        for (part in parts) {
            if (part.indexOf("Content-Disposition") != -1 && part.indexOf("filename=") != -1) {
                var nameStart = part.indexOf('filename="') + 10;
                var nameEnd = part.indexOf('"', nameStart);
                var filename = part.substr(nameStart, nameEnd - nameStart);
                filename = filename.split("\\").pop();
                trace("Found upload filename: " + filename);
                if (!StringTools.endsWith(filename, ".txt")) {
                    trace("Skipping non-txt file: " + filename);
                    continue;
                }

                var contentStart = part.indexOf("\r\n\r\n");
                if (contentStart != -1) {
                    var content = part.substr(contentStart + 4).split("\r\n")[0];
                    var safeName = sanitizeFilename(filename);

                    var directory = getDocumentsDirectory();

                    var fullPath = Path.join([directory.nativePath, safeName]);
                    trace("Saving file to: " + fullPath);
                    SysFile.saveContent(fullPath, content);
                    savedFiles.push(safeName);
                }
            }
        }

        trace("Upload complete, files: " + savedFiles.join(", "));
        sendResponse(output, 200, "Uploaded: " + savedFiles.join(", ") + "<br><a href='/'>Back</a>", "text/html");
    }

    function sanitizeFilename(name:String):String {
        var s1 = StringTools.replace(name, "..", "");
        var s2 = StringTools.replace(s1, "/", "_");
        var result = StringTools.replace(s2, "\\", "_");
        trace("Sanitized filename: " + result);
        return result;
    }

    function sendResponse(output:Output, status:Int, body:String, contentType:String):Void {
        trace('Sending response: $status, Content-Type: $contentType, Length: ${body.length}');
        output.writeString('HTTP/1.1 $status OK\r\n');
        output.writeString('Content-Type: $contentType\r\n');
        output.writeString('Content-Length: ${body.length}\r\n');
        output.writeString('Connection: close\r\n\r\n');
        output.writeString(body);
    }
}
