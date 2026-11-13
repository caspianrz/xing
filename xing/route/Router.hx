package xing.route;

typedef RouteEntry = {
	final segments:Array<RouteSegment>;
	final callback:RouteCallback;
}

/**
	Routes is a data structure mapping a route to a callback.
	A route path a simple route like `/questions` or names path like: `/question/<id:int>`.
	We can resolve a callback using `resolve` function which binds named path to the callback.
**/
class Router {
	private final routes:Array<RouteEntry> = [];

	public function new() {}

	public function add(path:String, callback:RouteCallback):Void {
		routes.push({
			segments: RouteParser.parse(path),
			callback: callback
		});
	}

	public function resolve(path:String):Null<RouteMatch> {
		var incoming = path.split("/").filter(s -> s.length > 0);

		for (route in routes) {
			if (route.segments.length != incoming.length)
				continue;

			var parameters:Map<String, Dynamic> = [];
			var matched = true;

			for (i in 0...route.segments.length) {
				var value = incoming[i];

				switch (route.segments[i]) {
					case RouteSegment.Static(expected):
						if (expected != value) {
							matched = false;
							break;
						}

					case RouteSegment.Parameter(name, type):
						switch (type) {
							case String:
								parameters.set(name, value);

							case Int:
								var parsed = Std.parseInt(value);

								if (parsed == null || Std.string(parsed) != value) {
									matched = false;
									break;
								}

								parameters.set(name, parsed);
						}
				}
			}

			if (matched) {
				return {
					callback: route.callback,
					parameters: parameters
				};
			}
		}

		return null;
	}
}
