package xing;

import xing.route.RouteMatch;
import xing.route.Router;
import xing.route.RouteMount;
import haxe.Exception;
import haxe.ds.GenericStack;
import sys.FileSystem;
import sys.io.File;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.FixedThreadPool;
import sys.thread.IThreadPool;
import xing.core.PriorityClientSocket;
import xing.core.System;
import xing.request.Request;
import xing.request.RequestParser;
import xing.response.Response;

using StringTools;

/**
	Base framework runner application.

	```haxe
	final x = new Xing();
	x.registerRoute("/", function(req, res) {
		res.setBody("Hello World");
		res.send();
	});
	x.listen("0.0.0.0", [8000]);
	```
**/
class Xing {
	private var cores:Int = 0;
	private var applicationThreads:IThreadPool;
	private var backlog:Array<PriorityClientSocket> = [];

	private final mounts:Array<RouteMount> = [];

	/**
		Constructor
	**/
	public function new() {
		this.cores = System.getProcessorCores();

		if (this.cores <= 0)
			this.cores = 1;
	}

	/**
		Registers a router at a given base path.

		Routers are ordered by longest matching base path.
	**/
	public function registerRoute(base:String, route:Router):Void {
		var normalized = normalizePath(base);

		// Replace an existing mount.
		for (i in 0...mounts.length) {
			if (mounts[i].basePath == normalized) {
				mounts[i] = {
					basePath: normalized,
					router: route
				};

				sortMounts();
				return;
			}
		}

		mounts.push({
			basePath: normalized,
			router: route
		});

		sortMounts();
	}

	/**
		Serves a directory at a given path.

		Example:
		x.serveStatic("/static", "dist");
	**/
	public function serveStatic(path:String, directory:String):Void {
		if (!FileSystem.isDirectory(directory))
			return;

		var laters:GenericStack<String> = new GenericStack<String>();

		var current = FileSystem.readDirectory(directory);

		for (each in current) {
			var currentPath = directory + "/" + each;

			if (FileSystem.isDirectory(currentPath)) {
				laters.add(each);
			} else {
				serveFile(path + "/" + each, currentPath);
			}
		}

		while (!laters.isEmpty()) {
			var currentPath = laters.pop();

			serveStatic(path + "/" + currentPath, directory + "/" + currentPath);
		}
	}

	/**
		Serves a file at a given path.

		Example:
		x.serveFile("/styles.css", "dist/styles.css");
	**/
	public function serveFile(path:String, filePath:String):Void {
		var fileContent:haxe.io.Bytes = null;

		if (FileSystem.exists(filePath))
			fileContent = File.getBytes(filePath);

		var route = getOrCreateRootRoutes();

		route.add(normalizePath(path), (req, res) -> {
			if (fileContent != null) {
				res.setBytes(fileContent);
			} else {
				res.setBody("");
			}

			res.send();
		});
	}

	/**
		Gets the root router or creates one if it doesn't exist.
	**/
	private function getOrCreateRootRoutes():Router {
		for (mount in mounts) {
			if (mount.basePath == "/")
				return mount.router;
		}

		var router = new Router();

		registerRoute("/", router);

		return router;
	}

	/**
		Sorts mounted routers by descending base path length.
	**/
	private function sortMounts():Void {
		mounts.sort((a, b) -> {
			return b.basePath.length - a.basePath.length;
		});
	}

	/**
		Resolves a request path against mounted routers.
	**/
	private function resolveRoute(path:String):Null<RouteMatch> {
		path = normalizePath(path);

		for (mount in mounts) {
			var base = mount.basePath;

			// Check whether the path belongs to this mount.
			if (base != "/") {
				if (path != base && !path.startsWith(base + "/"))
					continue;
			}

			// Strip the mount prefix.
			var remaining = base == "/" ? path : path.substr(base.length);

			if (remaining.length == 0)
				remaining = "/";

			var result = mount.router.resolve(remaining);

			if (result != null)
				return result;
		}

		return null;
	}

	/**
		Normalizes a route path.
	**/
	private static function normalizePath(path:String):String {
		if (path.length == 0)
			return "/";

		if (!path.startsWith("/"))
			path = "/" + path;

		while (path.length > 1 && path.endsWith("/"))
			path = path.substr(0, path.length - 1);

		return path;
	}

	/**
		Starts listening on given host and ports.
	**/
	public function listen(?host:String = "0.0.0.0", ?ports:Array<Int> = null, ?callback:Void->Void):Void {
		if (ports == null)
			ports = [3000];

		var nativeHost:Host = new Host(host);

		if (ports.length == 1) {
			applicationThreadHandler(nativeHost, ports[0], callback)();
		} else {
			this.applicationThreads = new FixedThreadPool(ports.length - 1);

			var lastPort = ports.pop();

			for (port in ports) {
				this.applicationThreads.run(applicationThreadHandler(nativeHost, port, callback));
			}

			applicationThreadHandler(nativeHost, lastPort, callback)();
		}
	}

	private function applicationThreadHandler(host:Host, port:Int, ?callback:Void->Void):Void->Void {
		return function() {
			var workerSocket = new Socket();

			workerSocket.bind(host, port);
			workerSocket.listen(1024);

			if (callback != null)
				callback();

			var workerClientHandlerThread:IThreadPool = new FixedThreadPool(this.cores * 25);

			while (true) {
				var client = workerSocket.accept();

				if (client != null) {
					workerClientHandlerThread.run(clientThreadHandler({
						socket: client,
						priority: 0,
						pending: false,
						done: false
					}));
				}
			}
		}
	}

	private function clientThreadHandler(client:PriorityClientSocket):Void->Void {
		return function() {
			client.pending = true;

			try {
				var req = parseRequest(client.socket.input);
				var match = resolveRoute(req.path);

				if (match != null) {
					var response = Response.fromOutput(client.socket.output);
					// Bind extracted route parameters.
					for (key => value in match.parameters) {
						req.params.set(key, value);
					}
					match.callback(req, response);
				} else {
					Response.notFound(client.socket.output);
				}

				client.socket.shutdown(true, true);
				client.socket.close();

				client.pending = false;
				client.done = true;
			} catch (e:Exception) {
				client.pending = false;
				client.done = true;
			}
		}
	}

	private function parseRequest(input:haxe.io.Input):Request {
		var request = RequestParser.requestFromInput(input);
		return new Request(request);
	}
}
