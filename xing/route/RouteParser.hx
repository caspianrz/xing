package xing.route;

import xing.route.RouteSegment;

class RouteParser {
    public static function parse(path:String):Array<RouteSegment> {
        var segments:Array<RouteSegment> = [];

        for (segment in path.split("/")) {
            if (segment.length == 0)
                continue;

            if (segment.charAt(0) == "<" && segment.charAt(segment.length - 1) == ">") {
                var declaration = segment.substring(1, segment.length - 1);
                var parts = declaration.split(":");

                if (parts.length != 2)
                    throw 'Invalid route parameter: $segment';

                var name = parts[0];

                var type = switch (parts[1]) {
                    case "string": RouteParameterType.String;
                    case "int": RouteParameterType.Int;
                    case _:
                        throw 'Unknown route parameter type: ${parts[1]}';
                };

                segments.push(RouteSegment.Parameter(name, type));
            } else {
                segments.push(RouteSegment.Static(segment));
            }
        }

        return segments;
    }
}