package xing.route;

enum RouteParameterType {
    String;
    Int;
}

enum RouteSegment {
    Static(value:String);
    Parameter(name:String, type:RouteParameterType);
}